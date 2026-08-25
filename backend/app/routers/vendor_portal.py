"""Vendor back-office: store profile, status, delivery settings, operating
hours, categories, menu CRUD, and analytics — all scoped to the signed-in
vendor's own store (role=vendor, matched via Vendor.owner_id)."""
import uuid
from datetime import date, datetime, time, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.db import get_db
from app.core.deps import require_vendor
from app.models.enums import OrderStatus
from app.models.food import FoodCategory, FoodItem, FoodImage, FoodOption, FoodOptionChoice
from app.models.order import Order
from app.models.user import User
from app.models.vendor import Vendor, VendorCategory, VendorDeliverySettings, VendorOperatingHours
from app.schemas.vendor_portal import (
    AnalyticsOut,
    CategoriesUpdate,
    DayRevenue,
    DeliverySettingsUpdate,
    FoodItemCreate,
    FoodItemUpdate,
    HoursUpdate,
    StoreStatusUpdate,
    VendorMeUpdate,
)

router = APIRouter(prefix="/vendor/me", tags=["Vendor Portal"])


async def _get_vendor(user: User, db: AsyncSession) -> Vendor:
    result = await db.execute(
        select(Vendor)
        .options(
            selectinload(Vendor.delivery_settings),
            selectinload(Vendor.categories),
            selectinload(Vendor.operating_hours),
            selectinload(Vendor.food_items),
        )
        .where(Vendor.owner_id == user.id)
    )
    vendor = result.scalar_one_or_none()
    if not vendor:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Vendor profile not found")
    return vendor


def _parse_hhmm(value: str) -> time:
    parts = value.split(":")
    return time(int(parts[0]), int(parts[1]))


def _format_time(value: time) -> str:
    return f"{value.hour:02d}:{value.minute:02d}"


# ---------------------------------------------------------------------------
# Store profile / status
# ---------------------------------------------------------------------------

@router.get("")
async def get_me(user: User = Depends(require_vendor), db: AsyncSession = Depends(get_db)):
    vendor = await _get_vendor(user, db)
    return _vendor_payload(vendor, owner_name=user.full_name, owner_email=user.email)


@router.put("")
async def update_me(
    payload: VendorMeUpdate,
    user: User = Depends(require_vendor),
    db: AsyncSession = Depends(get_db),
):
    vendor = await _get_vendor(user, db)
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(vendor, field, value)
    await db.commit()
    return _vendor_payload(vendor, owner_name=user.full_name, owner_email=user.email)


@router.patch("/status")
async def update_status(
    payload: StoreStatusUpdate,
    user: User = Depends(require_vendor),
    db: AsyncSession = Depends(get_db),
):
    vendor = await _get_vendor(user, db)
    if payload.is_open is not None:
        vendor.is_open = payload.is_open
    if payload.is_paused is not None:
        vendor.is_paused = payload.is_paused
    await db.commit()
    return _vendor_payload(vendor, owner_name=user.full_name, owner_email=user.email)


# ---------------------------------------------------------------------------
# Delivery settings / hours / categories
# ---------------------------------------------------------------------------

@router.put("/delivery-settings")
async def update_delivery_settings(
    payload: DeliverySettingsUpdate,
    user: User = Depends(require_vendor),
    db: AsyncSession = Depends(get_db),
):
    vendor = await _get_vendor(user, db)
    settings_ = vendor.delivery_settings
    if not settings_:
        settings_ = VendorDeliverySettings(vendor_id=vendor.id)
        db.add(settings_)
        await db.flush()
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(settings_, field, value)
    await db.commit()
    return _vendor_payload(vendor, owner_name=user.full_name, owner_email=user.email)


@router.put("/hours")
async def update_hours(
    payload: HoursUpdate,
    user: User = Depends(require_vendor),
    db: AsyncSession = Depends(get_db),
):
    vendor = await _get_vendor(user, db)
    await db.execute(
        delete(VendorOperatingHours).where(VendorOperatingHours.vendor_id == vendor.id)
    )
    for row in payload.hours:
        db.add(
            VendorOperatingHours(
                vendor_id=vendor.id,
                day_of_week=row.day_of_week,
                open_time=_parse_hhmm(row.open_time),
                close_time=_parse_hhmm(row.close_time),
                is_closed_all_day=row.is_closed_all_day,
            )
        )
    await db.commit()
    return _vendor_payload(vendor, owner_name=user.full_name, owner_email=user.email)


@router.put("/categories")
async def update_categories(
    payload: CategoriesUpdate,
    user: User = Depends(require_vendor),
    db: AsyncSession = Depends(get_db),
):
    vendor = await _get_vendor(user, db)
    await db.execute(delete(VendorCategory).where(VendorCategory.vendor_id == vendor.id))
    for name in dict.fromkeys(payload.categories):  # dedupe, keep order
        db.add(VendorCategory(vendor_id=vendor.id, name=name.strip()))
    await db.commit()
    return _vendor_payload(vendor, owner_name=user.full_name, owner_email=user.email)


# ---------------------------------------------------------------------------
# Menu CRUD
# ---------------------------------------------------------------------------

async def _get_or_create_category(db: AsyncSession, name: str | None) -> FoodCategory | None:
    if not name or not name.strip():
        return None
    name = name.strip()
    result = await db.execute(select(FoodCategory).where(FoodCategory.name == name))
    existing = result.scalar_one_or_none()
    if existing:
        return existing
    category = FoodCategory(name=name)
    db.add(category)
    await db.flush()
    return category


async def _replace_food_extras(
    db: AsyncSession,
    food: FoodItem,
    images: list[str],
    options: list,
) -> None:
    """Replace the item's images and option groups wholesale."""
    await db.execute(delete(FoodImage).where(FoodImage.food_item_id == food.id))
    for index, url in enumerate(dict.fromkeys(images)):
        db.add(FoodImage(food_item_id=food.id, image_url=url, is_primary=index == 0))

    await db.execute(delete(FoodOption).where(FoodOption.food_item_id == food.id))
    for group in options:
        option = FoodOption(
            food_item_id=food.id,
            group_name=group.group_name,
            is_required=group.is_required,
            allow_multiple=group.allow_multiple,
        )
        db.add(option)
        await db.flush()
        for choice in group.choices:
            db.add(
                FoodOptionChoice(
                    option_id=option.id,
                    label=choice.label,
                    extra_price=choice.extra_price,
                )
            )


@router.get("/menu")
async def list_menu(user: User = Depends(require_vendor), db: AsyncSession = Depends(get_db)):
    vendor = await _get_vendor(user, db)
    result = await db.execute(
        select(FoodItem)
        .options(
            selectinload(FoodItem.category),
            selectinload(FoodItem.images),
            selectinload(FoodItem.options).selectinload(FoodOption.choices),
        )
        .where(FoodItem.vendor_id == vendor.id)
    )
    return [_food_payload(f) for f in result.scalars().unique().all()]


@router.post("/menu", status_code=status.HTTP_201_CREATED)
async def create_menu_item(
    payload: FoodItemCreate,
    user: User = Depends(require_vendor),
    db: AsyncSession = Depends(get_db),
):
    vendor = await _get_vendor(user, db)
    category = await _get_or_create_category(db, payload.category)
    food = FoodItem(
        vendor_id=vendor.id,
        category_id=category.id if category else None,
        name=payload.name,
        description=payload.description,
        price=payload.price,
        is_available=payload.is_available,
        is_featured=payload.is_featured,
    )
    db.add(food)
    await db.flush()
    await _replace_food_extras(db, food, payload.images, payload.options)
    await db.commit()
    result = await db.execute(
        select(FoodItem)
        .options(
            selectinload(FoodItem.category),
            selectinload(FoodItem.images),
            selectinload(FoodItem.options).selectinload(FoodOption.choices),
        )
        .where(FoodItem.id == food.id)
    )
    return _food_payload(result.scalar_one())


@router.patch("/menu/{food_id}")
async def update_menu_item(
    food_id: uuid.UUID,
    payload: FoodItemUpdate,
    user: User = Depends(require_vendor),
    db: AsyncSession = Depends(get_db),
):
    vendor = await _get_vendor(user, db)
    result = await db.execute(
        select(FoodItem)
        .options(selectinload(FoodItem.images), selectinload(FoodItem.options).selectinload(FoodOption.choices))
        .where(FoodItem.id == food_id, FoodItem.vendor_id == vendor.id)
    )
    food = result.scalar_one_or_none()
    if not food:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Menu item not found")

    data = payload.model_dump(exclude_unset=True)
    if "category" in data:
        category = await _get_or_create_category(db, data.pop("category"))
        food.category_id = category.id if category else None
    for field, value in data.items():
        setattr(food, field, value)

    if payload.images is not None or payload.options is not None:
        await _replace_food_extras(
            db, food,
            payload.images if payload.images is not None else [i.image_url for i in food.images],
            payload.options if payload.options is not None else food.options,
        )
    await db.commit()
    result = await db.execute(
        select(FoodItem)
        .options(
            selectinload(FoodItem.category),
            selectinload(FoodItem.images),
            selectinload(FoodItem.options).selectinload(FoodOption.choices),
        )
        .where(FoodItem.id == food.id)
    )
    return _food_payload(result.scalar_one())


@router.delete("/menu/{food_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_menu_item(
    food_id: uuid.UUID,
    user: User = Depends(require_vendor),
    db: AsyncSession = Depends(get_db),
):
    vendor = await _get_vendor(user, db)
    result = await db.execute(
        select(FoodItem).where(FoodItem.id == food_id, FoodItem.vendor_id == vendor.id)
    )
    food = result.scalar_one_or_none()
    if not food:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Menu item not found")
    await db.delete(food)
    await db.commit()


# ---------------------------------------------------------------------------
# Analytics (dashboard + fl_chart)
# ---------------------------------------------------------------------------

@router.get("/analytics", response_model=AnalyticsOut)
async def analytics(user: User = Depends(require_vendor), db: AsyncSession = Depends(get_db)):
    vendor = await _get_vendor(user, db)
    today = datetime.now(timezone.utc).date()
    week_start = today - timedelta(days=6)

    result = await db.execute(
        select(Order)
        .where(Order.vendor_id == vendor.id, func.date(Order.created_at) >= week_start)
    )
    orders = result.scalars().all()

    today_orders = [o for o in orders if o.created_at.date() == today]
    non_cancelled_today = [o for o in today_orders if o.status != OrderStatus.cancelled]
    active_statuses = {
        OrderStatus.accepted,
        OrderStatus.preparing,
        OrderStatus.ready,
        OrderStatus.out_for_delivery,
    }

    week: list[DayRevenue] = []
    for offset in range(7):
        day = week_start + timedelta(days=offset)
        day_orders = [o for o in orders if o.created_at.date() == day]
        week.append(
            DayRevenue(
                date=day.isoformat(),
                revenue=sum(float(o.total) for o in day_orders if o.status != OrderStatus.cancelled),
                orders=len(day_orders),
            )
        )

    return AnalyticsOut(
        today_revenue=sum(float(o.total) for o in non_cancelled_today),
        today_orders=len(today_orders),
        pending_orders=sum(1 for o in today_orders if o.status == OrderStatus.pending),
        active_orders=sum(1 for o in orders if o.status in active_statuses),
        completed_today=sum(1 for o in today_orders if o.status in {OrderStatus.delivered, OrderStatus.completed}),
        cancelled_today=sum(1 for o in today_orders if o.status == OrderStatus.cancelled),
        week=week,
    )


# ---------------------------------------------------------------------------
# Payload builders
# ---------------------------------------------------------------------------

def _vendor_payload(vendor: Vendor, owner_name: str, owner_email: str) -> dict:
    settings_ = vendor.delivery_settings
    return {
        "id": str(vendor.id),
        "owner_name": owner_name,
        "owner_email": owner_email,
        "store_name": vendor.store_name,
        "description": vendor.description,
        "address": vendor.address,
        "latitude": vendor.latitude,
        "longitude": vendor.longitude,
        "contact_number": vendor.contact_number,
        "logo_url": vendor.logo_url,
        "banner_url": vendor.banner_url,
        "is_verified": vendor.is_verified,
        "is_open": vendor.is_open,
        "is_paused": vendor.is_paused,
        "average_rating": float(vendor.average_rating),
        "total_reviews": vendor.total_reviews,
        "categories": [c.name for c in vendor.categories],
        "delivery": {
            "delivery_enabled": settings_.delivery_enabled if settings_ else False,
            "pickup_enabled": settings_.pickup_enabled if settings_ else False,
            "scheduled_delivery_enabled": settings_.scheduled_delivery_enabled if settings_ else False,
            "delivery_radius_km": float(settings_.delivery_radius_km) if settings_ else 5,
            "base_delivery_fee": float(settings_.base_delivery_fee) if settings_ else 0,
            "fee_per_km": float(settings_.fee_per_km) if settings_ else 0,
            "estimated_prep_minutes": settings_.estimated_prep_minutes if settings_ else 20,
            "delivery_barangays": (settings_.delivery_barangays if settings_ else []) or [],
        },
        "hours": [
            {
                "day_of_week": h.day_of_week,
                "open_time": _format_time(h.open_time),
                "close_time": _format_time(h.close_time),
                "is_closed_all_day": h.is_closed_all_day,
            }
            for h in sorted(vendor.operating_hours, key=lambda h: h.day_of_week)
        ],
    }


def _food_payload(food: FoodItem) -> dict:
    return {
        "id": str(food.id),
        "name": food.name,
        "description": food.description,
        "price": float(food.price),
        "category": food.category.name if food.category else None,
        "is_available": food.is_available,
        "is_featured": food.is_featured,
        "images": [img.image_url for img in food.images],
        "options": [
            {
                "id": str(o.id),
                "group_name": o.group_name,
                "is_required": o.is_required,
                "allow_multiple": o.allow_multiple,
                "choices": [
                    {"id": str(c.id), "label": c.label, "extra_price": float(c.extra_price)}
                    for c in o.choices
                ],
            }
            for o in food.options
        ],
    }
