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
from app.models.enums import DeliveryMethod, OrderStatus, UserRole
from app.models.food import FoodItem
from app.models.order import Order
from app.models.user import User
from app.models.vendor import Vendor

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
    week_ago = datetime.now(timezone.utc) - timedelta(days=7)

    vendors = (await db.execute(select(Vendor))).scalars().all()
    customers_total = await db.scalar(
        select(func.count()).select_from(User).where(User.role == UserRole.customer)
    )
    orders_week = (
        await db.execute(select(Order).where(Order.created_at >= week_ago))
    ).scalars().all()
    active_orders = await db.scalar(
        select(func.count()).select_from(Order).where(Order.status.in_(_ACTIVE_STATUSES))
    )

    revenue_today = sum(
        float(o.total)
        for o in orders_week
        if o.status != OrderStatus.cancelled and o.created_at.date() == datetime.now(timezone.utc).date()
    )
    revenue_week = sum(float(o.total) for o in orders_week if o.status != OrderStatus.cancelled)

    # 7-day revenue series for the dashboard chart.
    week_series = []
    for offset in range(6, -1, -1):
        day = (datetime.now(timezone.utc) - timedelta(days=offset)).date()
        day_orders = [o for o in orders_week if o.created_at.date() == day]
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
        "orders_today": sum(
            1 for o in orders_week
            if o.created_at.date() == datetime.now(timezone.utc).date()
        ),
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
