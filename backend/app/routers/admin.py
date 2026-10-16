"""Admin console endpoints: platform-wide overview, vendor management,
customer list, and order oversight. All require role=admin."""
import uuid
from datetime import datetime, timedelta, timezone
from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.db import get_db
from app.core.deps import require_admin
from app.core.manila_time import manila_date, manila_days_back
from app.models.enums import DeliveryMethod, OrderStatus, UserRole
from app.models.food import FoodCategory, FoodItem
from app.models.order import Order, OrderStatusHistory
from app.models.social import Rating, Review
from app.models.user import User
from app.models.vendor import Vendor, VendorCategory

router = APIRouter(prefix="/admin", tags=["Admin"])

_ACTIVE_STATUSES = {
    OrderStatus.accepted,
    OrderStatus.preparing,
    OrderStatus.ready,
    OrderStatus.out_for_delivery,
}


# ---- Schemas ----

class VendorAdminOut(BaseModel):
    id: uuid.UUID
    store_name: str
    address: str
    logo_url: str | None
    is_open: bool
    is_paused: bool
    is_verified: bool
    average_rating: float
    total_reviews: int
    owner_name: str | None = None
    owner_email: str | None = None
    owner_mobile: str | None = None
    menu_count: int = 0
    created_at: datetime | None = None


class VendorPatch(BaseModel):
    is_verified: bool | None = None
    is_paused: bool | None = None
    is_open: bool | None = None


class CustomerOut(BaseModel):
    id: uuid.UUID
    full_name: str
    email: str
    mobile_number: str
    is_active: bool
    created_at: datetime
    order_count: int = 0


class OrderAdminItem(BaseModel):
    item_name: str
    quantity: int
    unit_price: float


class OrderAdminOut(BaseModel):
    id: uuid.UUID
    order_number: str
    vendor_id: uuid.UUID | None = None
    status: OrderStatus
    delivery_method: DeliveryMethod
    payment_method: str
    subtotal: float
    delivery_fee: float
    total: float
    created_at: datetime
    customer_name: str | None = None
    vendor_name: str | None = None
    items: list[OrderAdminItem] = []


# ---- Overview ----

@router.get("/overview")
async def overview(user: User = Depends(require_admin), db: AsyncSession = Depends(get_db)):
    # Pull a window that safely covers the last 7 MANILA days: Manila runs
    # 8 hours ahead of UTC, so 00:00 PHT of 6 days ago can be as early as
    # 6 days + 8 hours before now in UTC.
    week_start, window_start, _now_utc = manila_days_back(7)

    vendors = (await db.execute(select(Vendor))).scalars().all()
    customers_total = await db.scalar(
        select(func.count()).select_from(User).where(User.role == UserRole.customer)
    )
    orders_week = (
        await db.execute(select(Order).where(Order.created_at >= window_start))
    ).scalars().all()
    active_orders = await db.scalar(
        select(func.count()).select_from(Order).where(Order.status.in_(_ACTIVE_STATUSES))
    )

    today = week_start + timedelta(days=6)
    revenue_today = sum(
        float(o.total)
        for o in orders_week
        if o.status != OrderStatus.cancelled and manila_date(o.created_at) == today
    )
    revenue_week = sum(float(o.total) for o in orders_week if o.status != OrderStatus.cancelled)

    # 7-day revenue series for the dashboard chart, bucketed by Manila date.
    week_series = []
    for offset in range(7):
        day = week_start + timedelta(days=offset)
        day_orders = [o for o in orders_week if manila_date(o.created_at) == day]
        week_series.append({
            "date": day.isoformat(),
            "revenue": sum(float(o.total) for o in day_orders if o.status != OrderStatus.cancelled),
            "orders": len(day_orders),
        })

    return {
        "vendors_total": len(vendors),
        "vendors_open": sum(1 for v in vendors if v.is_open and not v.is_paused),
        "vendors_verified": sum(1 for v in vendors if v.is_verified),
        "customers_total": customers_total or 0,
        "orders_today": sum(1 for o in orders_week if manila_date(o.created_at) == today),
        "orders_this_week": len(orders_week),
        "orders_active": active_orders or 0,
        "revenue_today": revenue_today,
        "revenue_week": revenue_week,
        "week": week_series,
    }


# ---- Vendors ----

@router.get("/vendors", response_model=list[VendorAdminOut])
async def list_vendors(user: User = Depends(require_admin), db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(Vendor)
        .options(selectinload(Vendor.owner), selectinload(Vendor.food_items))
    )
    vendors = result.scalars().unique().all()

    out = []
    for v in vendors:
        menu_count = await db.scalar(
            select(func.count()).select_from(FoodItem).where(FoodItem.vendor_id == v.id)
        )
        out.append(
            VendorAdminOut(
                id=v.id,
                store_name=v.store_name,
                address=v.address,
                logo_url=v.logo_url,
                is_open=v.is_open,
                is_paused=v.is_paused,
                is_verified=v.is_verified,
                average_rating=float(v.average_rating),
                total_reviews=v.total_reviews,
                owner_name=v.owner.full_name if v.owner else None,
                owner_email=v.owner.email if v.owner else None,
                owner_mobile=v.owner.mobile_number if v.owner else None,
                menu_count=menu_count or 0,
                created_at=v.created_at,
            )
        )
    return out


@router.patch("/vendors/{vendor_id}", response_model=VendorAdminOut)
async def patch_vendor(
    vendor_id: uuid.UUID,
    payload: VendorPatch,
    user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Vendor).options(selectinload(Vendor.owner)).where(Vendor.id == vendor_id)
    )
    vendor = result.scalar_one_or_none()
    if not vendor:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Vendor not found")

    if payload.is_verified is not None:
        vendor.is_verified = payload.is_verified
    if payload.is_paused is not None:
        vendor.is_paused = payload.is_paused
    if payload.is_open is not None:
        vendor.is_open = payload.is_open
    await db.commit()

    menu_count = await db.scalar(
        select(func.count()).select_from(FoodItem).where(FoodItem.vendor_id == vendor.id)
    )
    return VendorAdminOut(
        id=vendor.id,
        store_name=vendor.store_name,
        address=vendor.address,
        logo_url=vendor.logo_url,
        is_open=vendor.is_open,
        is_paused=vendor.is_paused,
        is_verified=vendor.is_verified,
        average_rating=float(vendor.average_rating),
        total_reviews=vendor.total_reviews,
        owner_name=vendor.owner.full_name if vendor.owner else None,
        owner_email=vendor.owner.email if vendor.owner else None,
        owner_mobile=vendor.owner.mobile_number if vendor.owner else None,
        menu_count=menu_count or 0,
        created_at=vendor.created_at,
    )


# ---- Customers ----

@router.get("/customers", response_model=list[CustomerOut])
async def list_customers(user: User = Depends(require_admin), db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(User, func.count(Order.id).label("order_count"))
        .outerjoin(Order, Order.customer_id == User.id)
        .where(User.role == UserRole.customer)
        .group_by(User)
        .order_by(User.created_at.desc())
    )
    return [
        CustomerOut(
            id=u.id,
            full_name=u.full_name,
            email=u.email,
            mobile_number=u.mobile_number,
            is_active=u.is_active,
            created_at=u.created_at,
            order_count=count or 0,
        )
        for u, count in result.all()
    ]


# ---- Orders ----

@router.get("/orders", response_model=list[OrderAdminOut])
async def list_orders(
    order_status: OrderStatus | None = None,
    vendor_id: uuid.UUID | None = None,
    limit: int = 100,
    user: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    stmt = (
        select(Order)
        .options(selectinload(Order.items))
        .order_by(Order.created_at.desc())
        .limit(min(limit, 500))
    )
    if order_status:
        stmt = stmt.where(Order.status == order_status)
    if vendor_id:
        stmt = stmt.where(Order.vendor_id == vendor_id)

    orders = (await db.execute(stmt)).scalars().unique().all()

    # Batch-resolve names.
    customer_ids = {o.customer_id for o in orders}
    vendor_ids = {o.vendor_id for o in orders}
    customers: dict = {}
    vendors: dict = {}
    if customer_ids:
        rows = await db.execute(select(User).where(User.id.in_(customer_ids)))
        customers = {c.id: c for c in rows.scalars().all()}
    if vendor_ids:
        rows = await db.execute(select(Vendor).where(Vendor.id.in_(vendor_ids)))
        vendors = {v.id: v for v in rows.scalars().all()}

    def _pay(o: Order) -> str:
        # Keep the raw wire key (cash_on_delivery, gcash, ...); the UI formats.
        return o.payment_method.value if hasattr(o.payment_method, "value") else str(o.payment_method)

    return [
        OrderAdminOut(
            id=o.id,
            order_number=o.order_number,
            vendor_id=o.vendor_id,
            status=o.status,
            delivery_method=o.delivery_method,
            payment_method=_pay(o),
            subtotal=float(o.subtotal),
            delivery_fee=float(o.delivery_fee),
            total=float(o.total),
            created_at=o.created_at,
            customer_name=customers[o.customer_id].full_name if o.customer_id in customers else None,
            vendor_name=vendors[o.vendor_id].store_name if o.vendor_id in vendors else None,
            items=[
                OrderAdminItem(
                    item_name=i.item_name,
                    quantity=i.quantity,
                    unit_price=float(i.unit_price),
                )
                for i in o.items
            ],
        )
        for o in orders
    ]


# ---- Reviews ----

class ReviewAdminOut(BaseModel):
    id: uuid.UUID
    vendor_id: uuid.UUID
    vendor_name: str | None = None
    customer_name: str | None = None
    stars: int
    comment: str | None = None
    vendor_response: str | None = None
    vendor_responded: bool = False
    created_at: datetime


@router.get("/reviews", response_model=list[ReviewAdminOut])
async def list_reviews(user: User = Depends(require_admin), db: AsyncSession = Depends(get_db)):
    rows = (
        await db.execute(
            select(Review, Rating, Vendor, User)
            .join(Rating, Review.rating_id == Rating.id)
            .join(Vendor, Rating.vendor_id == Vendor.id, isouter=True)
            .join(User, Rating.customer_id == User.id, isouter=True)
            .order_by(Review.created_at.desc())
            .limit(200)
        )
    ).all()
    return [
        ReviewAdminOut(
            id=r.id,
            vendor_id=rating.vendor_id,
            vendor_name=vendor.store_name if vendor else None,
            customer_name=customer.full_name if customer else None,
            stars=rating.stars,
            comment=r.comment,
            vendor_response=r.vendor_response,
            vendor_responded=r.vendor_response is not None,
            created_at=r.created_at,
        )
        for r, rating, vendor, customer in rows
    ]


# ---- Categories ----

class CategoryAdminOut(BaseModel):
    name: str
    vendor_count: int
    product_count: int = 0


@router.get("/categories", response_model=list[CategoryAdminOut])
async def list_categories(user: User = Depends(require_admin), db: AsyncSession = Depends(get_db)):
    # Group the vendor-side tags.
    vendor_rows = (
        await db.execute(
            select(VendorCategory.name, func.count(func.distinct(VendorCategory.vendor_id)))
            .group_by(VendorCategory.name)
        )
    ).all()

    # Count food items per global FoodCategory name.
    product_rows = (
        await db.execute(
            select(FoodCategory.name, func.count(FoodItem.id))
            .select_from(FoodItem)
            .join(FoodCategory, FoodItem.category_id == FoodCategory.id)
            .group_by(FoodCategory.name)
        )
    ).all()
    products = dict(product_rows)

    merged: dict[str, CategoryAdminOut] = {}
    for name, vendor_count in vendor_rows:
        merged[name] = CategoryAdminOut(
            name=name, vendor_count=vendor_count, product_count=products.get(name, 0)
        )
    for name, product_count in product_rows:
        if name not in merged:
            merged[name] = CategoryAdminOut(name=name, vendor_count=0, product_count=product_count)
    return sorted(merged.values(), key=lambda c: c.name.lower())


# ---- Staff ----

class StaffAdminOut(BaseModel):
    id: uuid.UUID
    full_name: str
    email: str
    mobile_number: str
    is_active: bool
    created_at: datetime


@router.get("/staff", response_model=list[StaffAdminOut])
async def list_staff(user: User = Depends(require_admin), db: AsyncSession = Depends(get_db)):
    rows = (
        await db.execute(
            select(User).where(User.role == UserRole.admin).order_by(User.created_at.desc())
        )
    ).scalars().all()
    return [
        StaffAdminOut(
            id=u.id,
            full_name=u.full_name,
            email=u.email,
            mobile_number=u.mobile_number,
            is_active=u.is_active,
            created_at=u.created_at,
        )
        for u in rows
    ]


# ---- Subscriptions ----

class SubscriptionAdminOut(BaseModel):
    id: uuid.UUID
    store_name: str
    is_verified: bool
    is_paused: bool
    is_open: bool
    created_at: datetime
    menu_count: int = 0
    plan: str = "free"
    sub_state: str = "active"
    renewalDate: datetime | None = None


@router.get("/subscriptions", response_model=list[SubscriptionAdminOut])
async def list_subscriptions(user: User = Depends(require_admin), db: AsyncSession = Depends(get_db)):
    """Derived "subscription" view. No billing/subscription table exists yet,
    so every vendor reports the free plan and its state is inferred from the
    live/paused flags (active when open, paused when paused, suspended when
    closed). renewalDate is null until a billing schema lands."""
    vendors = (await db.execute(select(Vendor).order_by(Vendor.created_at.desc()))).scalars().all()
    out = []
    for v in vendors:
        menu_count = await db.scalar(
            select(func.count()).select_from(FoodItem).where(FoodItem.vendor_id == v.id)
        )
        if v.is_paused:
            sub_state = "paused"
        elif v.is_open:
            sub_state = "active"
        else:
            sub_state = "suspended"
        out.append(
            SubscriptionAdminOut(
                id=v.id,
                store_name=v.store_name,
                is_verified=v.is_verified,
                is_paused=v.is_paused,
                is_open=v.is_open,
                created_at=v.created_at,
                menu_count=menu_count or 0,
                sub_state=sub_state,
            )
        )
    return out


# ---- Activity ----

class ActivityOut(BaseModel):
    id: uuid.UUID
    at: datetime
    actor: str
    action: str
    target: str
    detail: str | None = None


@router.get("/activity", response_model=list[ActivityOut])
async def list_activity(user: User = Depends(require_admin), db: AsyncSession = Depends(get_db)):
    """Derived activity feed built from order status transitions (no audit
    table exists yet). Falls back to recent orders when history is empty."""
    rows = (
        await db.execute(
            select(OrderStatusHistory, Order, Vendor)
            .join(Order, OrderStatusHistory.order_id == Order.id)
            .join(Vendor, Order.vendor_id == Vendor.id, isouter=True)
            .order_by(OrderStatusHistory.changed_at.desc())
            .limit(200)
        )
    ).all()

    if rows:
        return [
            ActivityOut(
                id=h.id,
                at=h.changed_at,
                actor="system",
                action=f"order {o.order_number} -> {h.status.value}",
                target=v.store_name if v else o.order_number,
                detail=h.note,
            )
            for h, o, v in rows
        ]

    orders = (
        await db.execute(select(Order).order_by(Order.created_at.desc()).limit(200))
    ).scalars().all()
    vendor_ids = {o.vendor_id for o in orders}
    customer_ids = {o.customer_id for o in orders}
    vendors = {}
    customers = {}
    if vendor_ids:
        vendors = {v.id: v for v in (await db.execute(select(Vendor).where(Vendor.id.in_(vendor_ids)))).scalars().all()}
    if customer_ids:
        customers = {c.id: c for c in (await db.execute(select(User).where(User.id.in_(customer_ids)))).scalars().all()}
    return [
        ActivityOut(
            id=o.id,
            at=o.created_at,
            actor=customers[o.customer_id].full_name if o.customer_id in customers else "customer",
            action="placed order",
            target=o.order_number,
            detail=vendors[o.vendor_id].store_name if o.vendor_id in vendors else None,
        )
        for o in orders
    ]
