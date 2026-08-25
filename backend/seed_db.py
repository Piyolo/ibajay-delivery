"""
Seeds the database from the customer app's mock data (vendors.json).

Creates, for each store in the JSON:
  - a vendor owner user (role=vendor, password "vendor123" — dev only)
  - the Vendor + delivery settings + category tags + operating hours
  - menu items with their option groups/choices (incl. is_featured)

Idempotent: stores whose name already exists are skipped, so it's safe
to run repeatedly. Run after create_tables.py:

    python seed_db.py
"""
import asyncio
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

from sqlalchemy import select

# See create_tables.py — avoids the cosmetic Windows SSL-teardown traceback.
if sys.platform == "win32":
    asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())

from app.core.db import AsyncSessionLocal
from app.core.security import hash_password
from app.models.enums import UserRole
from app.models.food import FoodCategory, FoodItem, FoodOption, FoodOptionChoice
from app.models.user import User
from app.models.vendor import Vendor, VendorCategory, VendorDeliverySettings, VendorOperatingHours

VENDORS_JSON = (
    Path(__file__).resolve().parent.parent
    / "customer_app" / "assets" / "data" / "vendors.json"
)

SEED_OWNER_PASSWORD = "vendor123"

# 08:00-style JSON strings -> time(0, 6, 7, ...) day rows
DEFAULT_HOURS = [(d, "08:00", "20:00", False) for d in range(7)]


def _parse_hhmm(s: str):
    parts = (s or "08:00").split(":")
    hour = int(parts[0])
    minute = int(parts[1]) if len(parts) > 1 else 0
    return datetime(2000, 1, 1, hour, minute, tzinfo=timezone.utc).timetz()


async def seed() -> None:
    data = json.loads(VENDORS_JSON.read_text(encoding="utf-8"))

    async with AsyncSessionLocal() as session:
        # Global food-category taxonomy (unique names), shared by all vendors.
        category_rows: dict[str, FoodCategory] = {}
        for entry in data:
            for item in entry.get("menu", []):
                cat_name = item.get("category")
                if cat_name and cat_name not in category_rows:
                    existing = await session.execute(
                        select(FoodCategory).where(FoodCategory.name == cat_name)
                    )
                    category_rows[cat_name] = (
                        existing.scalar_one_or_none() or FoodCategory(name=cat_name)
                    )
                    session.add(category_rows[cat_name])
        await session.flush()

        for entry in data:
            existing = await session.execute(
                select(Vendor).where(Vendor.store_name == entry["storeName"])
            )
            if existing.scalar_one_or_none() is not None:
                print(f"- skip (already seeded): {entry['storeName']}")
                continue

            slug = entry["storeName"].lower().replace("'", "").replace(" ", ".")
            owner = User(
                full_name=f"{entry['storeName']} Owner",
                mobile_number=f"+6399000000{abs(hash(slug)) % 100:02d}",
                email=f"owner.{slug}@ibajayeats.dev",
                password_hash=hash_password(SEED_OWNER_PASSWORD),
                role=UserRole.vendor,
                is_email_verified=True,
            )
            session.add(owner)
            await session.flush()  # assign owner.id

            vendor = Vendor(
                owner_id=owner.id,
                store_name=entry["storeName"],
                description=entry.get("description") or None,
                logo_url=entry.get("logoUrl") or None,
                banner_url=entry.get("bannerUrl") or None,
                address=entry["address"],
                latitude=entry["latitude"],
                longitude=entry["longitude"],
                contact_number=owner.mobile_number,
                is_verified=entry.get("isVerified", False),
                is_open=entry.get("isOpen", False),
                average_rating=entry.get("rating", 0),
                total_reviews=entry.get("totalReviews", 0),
            )
            session.add(vendor)
            await session.flush()

            session.add(
                VendorDeliverySettings(
                    vendor_id=vendor.id,
                    delivery_enabled=entry["deliverySettings"].get("deliveryEnabled", True),
                    pickup_enabled=entry["deliverySettings"].get("pickupEnabled", True),
                    scheduled_delivery_enabled=entry["deliverySettings"].get(
                        "scheduledDeliveryEnabled", False
                    ),
                    delivery_radius_km=entry["deliverySettings"].get("deliveryRadiusKm", 5),
                    base_delivery_fee=entry["deliverySettings"].get("baseDeliveryFee", 30),
                    fee_per_km=entry["deliverySettings"].get("perKmFee", 8),
                    estimated_prep_minutes=entry["deliverySettings"].get(
                        "estimatedPrepMinutes", 20
                    ),
                    delivery_barangays=entry["deliverySettings"].get("deliveryBarangays", []),
                )
            )

            for name in entry.get("categories", []):
                session.add(VendorCategory(vendor_id=vendor.id, name=name))

            for day, open_s, close_s, closed in DEFAULT_HOURS:
                session.add(
                    VendorOperatingHours(
                        vendor_id=vendor.id,
                        day_of_week=day,
                        open_time=_parse_hhmm(open_s),
                        close_time=_parse_hhmm(close_s),
                        is_closed_all_day=closed,
                    )
                )

            for item in entry.get("menu", []):
                food = FoodItem(
                    vendor_id=vendor.id,
                    category_id=category_rows[item["category"]].id
                    if item.get("category") in category_rows
                    else None,
                    name=item["name"],
                    description=item.get("description") or None,
                    price=item["price"],
                    is_available=item.get("isAvailable", True),
                    is_featured=item.get("isFeatured", False),
                )
                session.add(food)
                await session.flush()

                for group in item.get("options", []):
                    option = FoodOption(
                        food_item_id=food.id,
                        group_name=group["groupName"],
                        is_required=group.get("isRequired", False),
                        allow_multiple=group.get("allowMultiple", True),
                    )
                    session.add(option)
                    await session.flush()

                    for choice in group.get("choices", []):
                        session.add(
                            FoodOptionChoice(
                                option_id=option.id,
                                label=choice["label"],
                                extra_price=choice.get("extraPrice", 0),
                            )
                        )

            print(f"+ seeded: {entry['storeName']} ({len(entry.get('menu', []))} menu items)")

        await session.commit()
        print("Seed complete.")


if __name__ == "__main__":
    asyncio.run(seed())
