import uuid
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, Header, HTTPException, Query, status
from sqlalchemy import delete, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.db import get_db
from app.core.deps import get_current_user, require_customer, require_vendor
from app.models.enums import DeliveryMethod, OrderStatus
from app.models.food import FoodItem, FoodOption, FoodOptionChoice
from app.models.order import CheckoutIdempotencyKey, Order, OrderItem, OrderStatusHistory
from app.models.social import Promotion
from app.models.user import Address, User
from app.models.vendor import Vendor
from app.schemas.order import (
    CheckoutRequest,
    OrderOut,
    PromoValidateOut,
    PromoValidateRequest,
    UpdateOrderStatus,
)
from app.services.geo import calculate_delivery_fee, haversine_km
from app.services.realtime import connection_manager
from app.services.notifications import notify_order_event

router = APIRouter(prefix="/orders", tags=["Orders"])

# Valid forward transitions a vendor can make. Cancellations are NOT part of
# this map on purpose: they go through /cancel so a reason is always recorded
# (the beta bug: PATCH /status let an order disappear with no reason data).
NEXT_STATUS = {
    OrderStatus.pending: {OrderStatus.accepted},
    OrderStatus.accepted: {OrderStatus.preparing},
    OrderStatus.preparing: {OrderStatus.ready},
    OrderStatus.ready: {OrderStatus.out_for_delivery, OrderStatus.completed},  # completed covers pickup collection
    OrderStatus.out_for_delivery: {OrderStatus.delivered},
    OrderStatus.delivered: {OrderStatus.completed},
}

# Documented beta cancellation policy (Master Business Plan §21): customers
# may back out while the order is still undecided or just accepted; once the
# kitchen starts preparing it, cancellation is restricted to the vendor (who
# records the reason and covers hand-offs like rider issues mid-delivery).
CUSTOMER_CANCELLABLE = {OrderStatus.pending, OrderStatus.accepted}
VENDOR_CANCELLABLE = {
    OrderStatus.pending,
    OrderStatus.accepted,
    OrderStatus.preparing,
    OrderStatus.ready,
    OrderStatus.out_for_delivery,
}


def can_cancel_order(status: OrderStatus, *, is_customer: bool) -> bool:
    """Single source of truth for the cancellation rule (also unit-tested)."""
    allowed = CUSTOMER_CANCELLABLE if is_customer else VENDOR_CANCELLABLE
    return status in allowed


# A (user, idempotency-key) pair stops being replayable after this long;
# retries happen within seconds/minutes of the first attempt.
IDEMPOTENCY_KEY_TTL = timedelta(hours=24)


def _generate_order_number() -> str:
    return f"ORD-{datetime.now(timezone.utc).strftime('%Y%m%d')}-{uuid.uuid4().hex[:6].upper()}"


async def _find_promo(db: AsyncSession, vendor_id: uuid.UUID, code: str) -> Promotion | None:
    normalized = (code or "").strip().upper()
    if not normalized:
        return None
    result = await db.execute(
        select(Promotion).where(
            Promotion.vendor_id == vendor_id,
            Promotion.code == normalized,
            Promotion.is_active == True,  # noqa: E712
        )
    )
    return result.scalar_one_or_none()


def _promo_is_live(promo: Promotion, now: datetime) -> bool:
    if promo.starts_at and now < promo.starts_at:
        return False
    if promo.ends_at and now > promo.ends_at:
        return False
    return True


def _promo_discount(promo: Promotion, subtotal: float) -> float:
    raw = subtotal * (float(promo.discount_value) / 100.0) if promo.discount_type == "percent" \
        else float(promo.discount_value)
    return round(min(raw, subtotal), 2)


async def _validate_promotion(
    db: AsyncSession, vendor_id: uuid.UUID, code: str, subtotal: float
) -> tuple[Promotion | None, str | None]:
    promo = await _find_promo(db, vendor_id, code)
    now = datetime.now(timezone.utc)
    if not promo:
        return None, "Invalid promo code"
    if not _promo_is_live(promo, now):
        return None, "This promotion has expired"
    if subtotal < float(promo.min_subtotal):
        return None, f"Minimum spend of ₱{float(promo.min_subtotal):.0f} required"
    return promo, None


async def _selected_options_price(
    db: AsyncSession, food_item_id: uuid.UUID, selected_options: dict[str, list[str]]
) -> float:
    """Sums the server-stored `extra_price` of every selected choice for one
    cart line (the add-on bug: these were previously skipped entirely).

    Prices come only from this food item's `food_option_choices` rows —
    client payloads carry labels, never prices, so unknown labels simply
    contribute 0. Lookup is by (group_name, label); a label-only fallback
    covers clients that send a different group key.
    """
    if not selected_options:
        return 0.0

    rows = (
        await db.execute(
            select(FoodOption.group_name, FoodOptionChoice.label, FoodOptionChoice.extra_price)
            .join(FoodOptionChoice, FoodOptionChoice.option_id == FoodOption.id)
            .where(FoodOption.food_item_id == food_item_id)
        )
    ).all()
    by_group_label = {(group, label): float(price) for group, label, price in rows}
    by_label = {label: float(price) for _, label, price in rows}

    total = 0.0
    for group, labels in selected_options.items():
        for label in labels or []:
            if (group, label) in by_group_label:
                total += by_group_label[(group, label)]
            else:
                total += by_label.get(label, 0.0)
    return round(total, 2)


@router.post("/checkout", response_model=OrderOut, status_code=status.HTTP_201_CREATED)
async def checkout(
    payload: CheckoutRequest,
    idempotency_key: str | None = Header(default=None, alias="Idempotency-Key", max_length=72),
    user: User = Depends(require_customer),
    db: AsyncSession = Depends(get_db),
):
    # Duplicate-submission protection: the client generates one UUID per
    # checkout session and sends it on every attempt (first call + retries
    # after a timeout). The first attempt stores the key alongside the order
    # in one transaction; a retry finds it and replays the SAME order, so a
    # double-tap or a 25s-timeout retry can never create a second paid order.
    key = (idempotency_key or "").strip() or None

    vendor_result = await db.execute(
        select(Vendor).options(selectinload(Vendor.delivery_settings)).where(Vendor.id == payload.vendor_id)
    )
    vendor = vendor_result.scalar_one_or_none()
    if not vendor:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Vendor not found")
    if vendor.is_paused or not vendor.is_open:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Store is currently closed")

    if key:
        # Purge this user's long-spent keys, then short-circuit when the key
        # already produced an order for this user (regular replay path).
        cutoff = datetime.now(timezone.utc) - IDEMPOTENCY_KEY_TTL
        await db.execute(
            delete(CheckoutIdempotencyKey).where(
                CheckoutIdempotencyKey.user_id == user.id,
                CheckoutIdempotencyKey.created_at < cutoff,
            )
        )
        row = (
            await db.execute(
                select(CheckoutIdempotencyKey).where(
                    CheckoutIdempotencyKey.user_id == user.id,
                    CheckoutIdempotencyKey.key == key,
                )
            )
        ).scalar_one_or_none()
        if row:
            prior = (
                await db.execute(
                    select(Order).options(selectinload(Order.items)).where(Order.id == row.order_id)
                )
            ).scalar_one_or_none()
            if prior:
                return prior

    settings_ = vendor.delivery_settings
    if payload.delivery_method == DeliveryMethod.delivery and not settings_.delivery_enabled:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "This vendor does not offer delivery")
    if payload.delivery_method == DeliveryMethod.pickup and not settings_.pickup_enabled:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "This vendor does not offer pickup")
    if payload.delivery_method == DeliveryMethod.scheduled_delivery and not settings_.scheduled_delivery_enabled:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "This vendor does not offer scheduled delivery")

    # Resolve delivery address (skip for pickup)
    address = None
    delivery_fee = 0.0
    if payload.delivery_method != DeliveryMethod.pickup:
        addr_result = await db.execute(
            select(Address).where(Address.id == payload.address_id, Address.user_id == user.id)
        )
        address = addr_result.scalar_one_or_none()
        if not address:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Address not found")

        distance_km = haversine_km(address.latitude, address.longitude, vendor.latitude, vendor.longitude)
        if distance_km > float(settings_.delivery_radius_km):
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "Address is outside this vendor's delivery radius")
        delivery_fee = calculate_delivery_fee(distance_km, float(settings_.base_delivery_fee), float(settings_.fee_per_km))

        # Barangay-scoped delivery: a vendor with an explicit area list only
        # delivers inside it (pickup stays available regardless).
        barangays = settings_.delivery_barangays or []
        if barangays and address.barangay and address.barangay not in barangays:
            raise HTTPException(
                status.HTTP_400_BAD_REQUEST,
                "This store doesn't deliver to your barangay — pickup may still be available",
            )

    if not payload.items:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Cart cannot be empty")

    # Build order items from live food-item data (never trust client-side prices)
    order_items: list[OrderItem] = []
    subtotal = 0.0
    for cart_item in payload.items:
        food_result = await db.execute(
            select(FoodItem).where(FoodItem.id == cart_item.food_item_id, FoodItem.vendor_id == vendor.id)
        )
        food_item = food_result.scalar_one_or_none()
        if not food_item or not food_item.is_available:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, f"Item unavailable: {cart_item.food_item_id}")

        # Add-on prices: look up each selected choice's extra_price from
        # FoodOptionChoice (server-side only — never trust client prices)
        # and fold it into the per-unit cost, so unit_price * quantity ==
        # line_total on every consumer (customer app, vendor app, admin).
        addons = await _selected_options_price(db, food_item.id, cart_item.selected_options)
        unit_price = round(float(food_item.price) + addons, 2)
        line_total = round(unit_price * cart_item.quantity, 2)
        subtotal = round(subtotal + line_total, 2)

        order_items.append(
            OrderItem(
                food_item_id=food_item.id,
                item_name=food_item.name,
                unit_price=unit_price,
                quantity=cart_item.quantity,
                selected_options=cart_item.selected_options,
                line_total=line_total,
                special_instructions=cart_item.special_instructions,
            )
        )

    # Promotion (optional): validated server-side, never trust client math.
    discount = 0.0
    promotion = None
    if payload.promo_code:
        promotion, error = await _validate_promotion(db, vendor.id, payload.promo_code, subtotal)
        if promotion is None:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, error or "Invalid promo code")
        discount = _promo_discount(promotion, subtotal)

    total = round(max(0.0, subtotal + delivery_fee - discount), 2)
    order = Order(
        order_number=_generate_order_number(),
        customer_id=user.id,
        vendor_id=vendor.id,
        delivery_method=payload.delivery_method,
        payment_method=payload.payment_method,
        status=OrderStatus.pending,
        delivery_address=address.full_address if address else None,
        delivery_latitude=address.latitude if address else None,
        delivery_longitude=address.longitude if address else None,
        scheduled_for=payload.scheduled_for,
        subtotal=subtotal,
        delivery_fee=delivery_fee,
        discount=discount,
        promotion_id=promotion.id if promotion else None,
        total=total,
        special_instructions=payload.special_instructions,
        items=order_items,
    )
    db.add(order)
    await db.flush()
    db.add(OrderStatusHistory(order_id=order.id, status=OrderStatus.pending, note="Order placed"))
    if promotion:
        promotion.times_used += 1

    if key:
        # The key row commits in the SAME transaction as the order: either
        # both exist or neither does. A concurrent duplicate request that
        # raced us to the unique (user, key) constraint rolls its whole
        # order back below, then replays the winner — the race can never
        # produce two orders for one key.
        db.add(CheckoutIdempotencyKey(user_id=user.id, key=key, order_id=order.id))
    try:
        await db.commit()
    except IntegrityError as exc:
        # Distinguish a key race from an unrelated failure (rare order-number
        # collision): the key race hits OUR unique constraint, so replay the
        # winner. Anything else keeps the loud 500 it deserves.
        if key and "uq_checkout_key_user_id_key" in str(exc.orig):
            await db.rollback()
            row = (
                await db.execute(
                    select(CheckoutIdempotencyKey).where(
                        CheckoutIdempotencyKey.user_id == user.id,
                        CheckoutIdempotencyKey.key == key,
                    )
                )
            ).scalar_one_or_none()
            if row:
                prior = (
                    await db.execute(
                        select(Order).options(selectinload(Order.items)).where(Order.id == row.order_id)
                    )
                ).scalar_one_or_none()
                if prior:
                    return prior
            raise HTTPException(
                status.HTTP_409_CONFLICT,
                "This order was just processed. Refresh and try again.",
            ) from exc
        raise
    await db.refresh(order, attribute_names=["items"])

    await notify_order_event(db, vendor.owner_id, order, event="new_order")
    return order


@router.post("/validate-promo", response_model=PromoValidateOut)
async def validate_promo(
    payload: PromoValidateRequest,
    user: User = Depends(require_customer),
    db: AsyncSession = Depends(get_db),
):
    """Pre-checks a promo code at checkout so the customer sees the
    discount before placing the order."""
    promo, error = await _validate_promotion(db, payload.vendor_id, payload.code, payload.subtotal)
    if promo is None:
        return PromoValidateOut(valid=False, message=error)
    return PromoValidateOut(
        valid=True,
        title=promo.title,
        discount=_promo_discount(promo, payload.subtotal),
    )


@router.get("/my-orders", response_model=list[OrderOut])
async def my_orders(
    limit: int = Query(default=100, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
    status_filter: OrderStatus | None = Query(default=None, alias="status"),
    user: User = Depends(require_customer),
    db: AsyncSession = Depends(get_db),
):
    """Paginated order history.

    Backwards-compatible: beta clients read the full list, and default 100
    covers any realistic beta history while making later "load more" paging
    possible (offset param). Ordered desc, so the first page carries the
    recent orders clients show first."""
    stmt = (
        select(Order)
        .options(selectinload(Order.items))
        .where(Order.customer_id == user.id)
        .order_by(Order.created_at.desc())
    )
    if status_filter:
        stmt = stmt.where(Order.status == status_filter)
    result = await db.execute(stmt.offset(offset).limit(limit))
    return result.scalars().unique().all()


@router.get("/vendor/inbox", response_model=list[OrderOut])
async def vendor_inbox(
    order_status: OrderStatus | None = None,
    limit: int = Query(default=100, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
    user: User = Depends(require_vendor),
    db: AsyncSession = Depends(get_db),
):
    """Vendor's order management dashboard: filter by status (New/Preparing/Out for Delivery/Completed).

    Paginated like /my-orders: the vendor app's poll re-downloads this
    repeatedly, so an unbounded history would slowly grow every 25 s request."""
    vendor_result = await db.execute(select(Vendor).where(Vendor.owner_id == user.id))
    vendor = vendor_result.scalar_one_or_none()
    if not vendor:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Vendor profile not found")

    stmt = select(Order).options(selectinload(Order.items)).where(Order.vendor_id == vendor.id)
    if order_status:
        stmt = stmt.where(Order.status == order_status)
    stmt = stmt.order_by(Order.created_at.desc()).offset(offset).limit(limit)

    orders = (await db.execute(stmt)).scalars().unique().all()

    # Batch-resolve customer profiles for the inbox display.
    customer_ids = {o.customer_id for o in orders}
    customers: dict = {}
    if customer_ids:
        c_result = await db.execute(select(User).where(User.id.in_(customer_ids)))
        customers = {c.id: c for c in c_result.scalars().all()}

    return [
        OrderOut(
            id=o.id,
            order_number=o.order_number,
            vendor_id=o.vendor_id,
            status=o.status,
            delivery_method=o.delivery_method,
            payment_method=o.payment_method,
            subtotal=float(o.subtotal),
            delivery_fee=float(o.delivery_fee),
            discount=float(o.discount or 0),
            total=float(o.total),
            scheduled_for=o.scheduled_for,
            created_at=o.created_at,
            items=o.items,
            customer_name=customers[o.customer_id].full_name if o.customer_id in customers else None,
            customer_mobile=customers[o.customer_id].mobile_number if o.customer_id in customers else None,
            delivery_address=o.delivery_address,
            delivery_latitude=o.delivery_latitude,
            delivery_longitude=o.delivery_longitude,
            special_instructions=o.special_instructions,
            cancellation_reason=o.cancellation_reason,
        )
        for o in orders
    ]


@router.get("/{order_id}", response_model=OrderOut)
async def get_order(order_id: uuid.UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Order).options(selectinload(Order.items)).where(Order.id == order_id))
    order = result.scalar_one_or_none()
    if not order:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Order not found")

    vendor_result = await db.execute(select(Vendor).where(Vendor.id == order.vendor_id))
    vendor = vendor_result.scalar_one_or_none()
    if order.customer_id != user.id and (not vendor or vendor.owner_id != user.id) and user.role.value != "admin":
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Not authorized to view this order")
    return order


@router.patch("/{order_id}/status", response_model=OrderOut)
async def update_order_status(
    order_id: uuid.UUID,
    payload: UpdateOrderStatus,
    user: User = Depends(require_vendor),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Order).options(selectinload(Order.items)).where(Order.id == order_id))
    order = result.scalar_one_or_none()
    if not order:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Order not found")

    vendor_result = await db.execute(select(Vendor).where(Vendor.id == order.vendor_id))
    vendor = vendor_result.scalar_one_or_none()
    if not vendor or vendor.owner_id != user.id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Not your store's order")

    allowed = NEXT_STATUS.get(order.status, set())
    if payload.status not in allowed:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            f"Cannot move order from {order.status.value} to {payload.status.value}",
        )

    order.status = payload.status
    db.add(OrderStatusHistory(order_id=order.id, status=payload.status, note=payload.note))
    await db.commit()
    await db.refresh(order, attribute_names=["items"])

    # Customer-facing statuses are persisted by notify_order_event; events
    # without a mapping (ready/completed) are intentionally left silent.
    await notify_order_event(db, order.customer_id, order, event=payload.status.value)

    # Push the status change to anyone subscribed to this order's tracking channel
    await connection_manager.broadcast_to_order(
        order.id, {"type": "status_update", "order_id": str(order.id), "status": payload.status.value}
    )
    return order


@router.post("/{order_id}/cancel", response_model=OrderOut)
async def cancel_order(
    order_id: uuid.UUID,
    reason: str,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Order).options(selectinload(Order.items)).where(Order.id == order_id))
    order = result.scalar_one_or_none()
    if not order:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Order not found")

    vendor_result = await db.execute(select(Vendor).where(Vendor.id == order.vendor_id))
    vendor = vendor_result.scalar_one_or_none()
    is_owner_customer = order.customer_id == user.id
    is_owner_vendor = vendor and vendor.owner_id == user.id
    if not (is_owner_customer or is_owner_vendor):
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Not authorized")

    if order.status in {OrderStatus.delivered, OrderStatus.completed, OrderStatus.cancelled}:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Order can no longer be cancelled")

    # Per-party policy (Master Business Plan §21): customers may cancel only
    # while the order is undecided or freshly accepted — after that the food
    # is being made and the store loses revenue; the store itself may cancel
    # any pre-delivery order (out of stock, no rider, missed the window...).
    is_customer = bool(is_owner_customer)
    if not can_cancel_order(order.status, is_customer=is_customer):
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            "This order can no longer be cancelled — it is already being prepared. "
            "You can message the store about it instead.",
        )

    reason = (reason or "").strip()
    if not reason:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "A cancellation reason is required")
    if len(reason) > 500:
        reason = reason[:500]

    order.status = OrderStatus.cancelled
    order.cancellation_reason = reason
    db.add(OrderStatusHistory(order_id=order.id, status=OrderStatus.cancelled, note=reason))
    await db.commit()
    await db.refresh(order, attribute_names=["items"])

    await connection_manager.broadcast_to_order(
        order.id, {"type": "status_update", "order_id": str(order.id), "status": "cancelled"}
    )

    # Tell whichever party didn't cancel: vendor cancels -> customer hears
    # about it, customer cancels -> the vendor's inbox needs the update.
    recipient = order.customer_id if is_owner_vendor else vendor.owner_id
    await notify_order_event(db, recipient, order, event="cancelled")
    return order
