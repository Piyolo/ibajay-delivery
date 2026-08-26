import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.db import get_db
from app.models.food import FoodItem, FoodOption
from app.models.social import Promotion
from app.models.vendor import Vendor, VendorCategory, VendorDeliverySettings
from app.schemas.vendor import FoodItemOut, VendorCardOut, VendorProfileOut
from app.services.geo import haversine_km

router = APIRouter(prefix="/vendors", tags=["Vendors"])


@router.get("/nearby", response_model=list[VendorCardOut])
async def list_nearby_vendors(
    lat: float = Query(..., description="Customer latitude"),
    lng: float = Query(..., description="Customer longitude"),
    search: str | None = Query(None, description="Search by store name or food name"),
    category: str | None = Query(None),
    open_now: bool = Query(False),
    delivery_available: bool = Query(False),
    pickup_available: bool = Query(False),
    scheduled_available: bool = Query(False),
    db: AsyncSession = Depends(get_db),
):
    """
    Core discovery endpoint for the customer home screen: nearby vendors,
    filterable by open/closed, delivery/pickup/scheduled availability, and
    free-text search on store or food name.
    """
    stmt = (
        select(Vendor)
        .options(selectinload(Vendor.delivery_settings), selectinload(Vendor.food_items))
        .where(Vendor.is_paused == False)  # noqa: E712
    )

    if open_now:
        stmt = stmt.where(Vendor.is_open == True)  # noqa: E712

    if search:
        pattern = f"%{search}%"
        stmt = stmt.where(
            or_(
                Vendor.store_name.ilike(pattern),
                Vendor.id.in_(select(FoodItem.vendor_id).where(FoodItem.name.ilike(pattern))),
            )
        )

    if category:
        stmt = stmt.where(Vendor.id.in_(select(VendorCategory.vendor_id).where(VendorCategory.name.ilike(category))))

    result = await db.execute(stmt)
    vendors = result.scalars().unique().all()

    cards: list[VendorCardOut] = []
    for v in vendors:
        settings_ = v.delivery_settings
        if not settings_:
            continue
        if delivery_available and not settings_.delivery_enabled:
            continue
        if pickup_available and not settings_.pickup_enabled:
            continue
        if scheduled_available and not settings_.scheduled_delivery_enabled:
            continue

        distance = haversine_km(lat, lng, v.latitude, v.longitude)
        if distance > float(settings_.delivery_radius_km):
            continue  # outside this vendor's serviceable radius

        cards.append(
            VendorCardOut(
                id=v.id,
                store_name=v.store_name,
                logo_url=v.logo_url,
                average_rating=float(v.average_rating),
                is_open=v.is_open,
                delivery_enabled=settings_.delivery_enabled,
                pickup_enabled=settings_.pickup_enabled,
                estimated_prep_minutes=settings_.estimated_prep_minutes,
                distance_km=round(distance, 2),
            )
        )

    cards.sort(key=lambda c: c.distance_km or 0)
    return cards


@router.get("/{vendor_id}", response_model=VendorProfileOut)
async def get_vendor_profile(vendor_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    stmt = (
        select(Vendor)
        .options(
            selectinload(Vendor.delivery_settings),
            selectinload(Vendor.categories),
            selectinload(Vendor.food_items).selectinload(FoodItem.images),
            selectinload(Vendor.food_items).selectinload(FoodItem.category),
            selectinload(Vendor.food_items)
            .selectinload(FoodItem.options)
            .selectinload(FoodOption.choices),
        )
        .where(Vendor.id == vendor_id)
    )
    result = await db.execute(stmt)
    vendor = result.scalar_one_or_none()
    if not vendor:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Vendor not found")

    settings_ = vendor.delivery_settings

    # Active, currently-visible promotions for the storefront banner.
    now = datetime.now(timezone.utc)
    promo_result = await db.execute(
        select(Promotion)
        .where(
            Promotion.vendor_id == vendor.id,
            Promotion.is_active == True,  # noqa: E712
        )
        .order_by(Promotion.created_at.desc())
    )
    active_promos = [
        p
        for p in promo_result.scalars().all()
        if (p.starts_at is None or p.starts_at <= now) and (p.ends_at is None or p.ends_at >= now)
    ]

    return VendorProfileOut(
        id=vendor.id,
        store_name=vendor.store_name,
        description=vendor.description,
        logo_url=vendor.logo_url,
        banner_url=vendor.banner_url,
        address=vendor.address,
        latitude=vendor.latitude,
        longitude=vendor.longitude,
        average_rating=float(vendor.average_rating),
        total_reviews=vendor.total_reviews,
        is_open=vendor.is_open,
        is_verified=vendor.is_verified,
        delivery_enabled=settings_.delivery_enabled if settings_ else False,
        pickup_enabled=settings_.pickup_enabled if settings_ else False,
        scheduled_delivery_enabled=settings_.scheduled_delivery_enabled if settings_ else False,
        delivery_radius_km=float(settings_.delivery_radius_km) if settings_ else 5,
        base_delivery_fee=float(settings_.base_delivery_fee) if settings_ else 0,
        fee_per_km=float(settings_.fee_per_km) if settings_ else 0,
        estimated_prep_minutes=settings_.estimated_prep_minutes if settings_ else 20,
        delivery_barangays=(settings_.delivery_barangays if settings_ else []) or [],
        categories=[c.name for c in vendor.categories],
        promotions=active_promos,
        food_items=[
            FoodItemOut(
                id=f.id,
                name=f.name,
                description=f.description,
                price=float(f.price),
                is_available=f.is_available,
                is_featured=f.is_featured,
                category=f.category.name if f.category else None,
                images=[img.image_url for img in f.images],
                options=f.options,
            )
            for f in vendor.food_items
        ],
    )
