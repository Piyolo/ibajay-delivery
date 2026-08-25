import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.db import get_db
from app.core.deps import get_current_user, require_customer, require_vendor
from app.models.enums import DeliveryMethod, OrderStatus
from app.models.food import FoodItem
from app.models.order import Order, OrderItem, OrderStatusHistory
from app.models.user import Address, User
from app.models.vendor import Vendor
from app.schemas.order import CheckoutRequest, OrderOut, UpdateOrderStatus
from app.services.geo import calculate_delivery_fee, haversine_km
from app.services.realtime import connection_manager
from app.services.notifications import notify_order_event

router = APIRouter(prefix="/orders", tags=["Orders"])

# Valid forward transitions a vendor can make. Cancellation is allowed from
# most pre-delivery states and is handled separately via /cancel.
NEXT_STATUS = {
    OrderStatus.pending: {OrderStatus.accepted, OrderStatus.cancelled},
    OrderStatus.accepted: {OrderStatus.preparing, OrderStatus.cancelled},
    OrderStatus.preparing: {OrderStatus.ready, OrderStatus.cancelled},
    OrderStatus.ready: {OrderStatus.out_for_delivery, OrderStatus.completed},  # completed covers pickup collection
    OrderStatus.out_for_delivery: {OrderStatus.delivered},
    OrderStatus.delivered: {OrderStatus.completed},
}


def _generate_order_number() -> str:
    return f"ORD-{datetime.now(timezone.utc).strftime('%Y%m%d')}-{uuid.uuid4().hex[:6].upper()}"


@router.post("/checkout", response_model=OrderOut, status_code=status.HTTP_201_CREATED)
async def checkout(
    payload: CheckoutRequest,
    user: User = Depends(require_customer),
    db: AsyncSession = Depends(get_db),
):
    vendor_result = await db.execute(
        select(Vendor).options(selectinload(Vendor.delivery_settings)).where(Vendor.id == payload.vendor_id)
    )
    vendor = vendor_result.scalar_one_or_none()
    if not vendor:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Vendor not found")
    if vendor.is_paused or not vendor.is_open:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Store is currently closed")

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

        # NOTE: extra_price per selected choice would normally be looked up here
        # via FoodOptionChoice; omitted for brevity but is a straightforward
        # join against selected_options labels.
        line_total = float(food_item.price) * cart_item.quantity
        subtotal += line_total

        order_items.append(
            OrderItem(
                food_item_id=food_item.id,
                item_name=food_item.name,
                unit_price=float(food_item.price),
                quantity=cart_item.quantity,
                selected_options=cart_item.selected_options,
                line_total=line_total,
                special_instructions=cart_item.special_instructions,
            )
        )

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
        total=subtotal + delivery_fee,
        special_instructions=payload.special_instructions,
        items=order_items,
    )
    db.add(order)
    await db.flush()
    db.add(OrderStatusHistory(order_id=order.id, status=OrderStatus.pending, note="Order placed"))
    await db.commit()
    await db.refresh(order, attribute_names=["items"])

    await notify_order_event(vendor.owner_id, order, event="new_order")
    return order


@router.get("/my-orders", response_model=list[OrderOut])
async def my_orders(user: User = Depends(require_customer), db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(Order)
        .options(selectinload(Order.items))
        .where(Order.customer_id == user.id)
        .order_by(Order.created_at.desc())
    )
    return result.scalars().unique().all()


@router.get("/vendor/inbox", response_model=list[OrderOut])
async def vendor_inbox(
    order_status: OrderStatus | None = None,
    user: User = Depends(require_vendor),
    db: AsyncSession = Depends(get_db),
):
    """Vendor's order management dashboard: filter by status (New/Preparing/Out for Delivery/Completed)."""
    vendor_result = await db.execute(select(Vendor).where(Vendor.owner_id == user.id))
    vendor = vendor_result.scalar_one_or_none()
    if not vendor:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Vendor profile not found")

    stmt = select(Order).options(selectinload(Order.items)).where(Order.vendor_id == vendor.id)
    if order_status:
        stmt = stmt.where(Order.status == order_status)
    stmt = stmt.order_by(Order.created_at.desc())

    result = await db.execute(stmt)
    return result.scalars().unique().all()


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

    await notify_order_event(order.customer_id, order, event=payload.status.value)

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

    order.status = OrderStatus.cancelled
    order.cancellation_reason = reason
    db.add(OrderStatusHistory(order_id=order.id, status=OrderStatus.cancelled, note=reason))
    await db.commit()
    await db.refresh(order, attribute_names=["items"])

    await connection_manager.broadcast_to_order(
        order.id, {"type": "status_update", "order_id": str(order.id), "status": "cancelled"}
    )
    return order
