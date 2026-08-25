"""Request/response schemas for the vendor back-office portal."""
import uuid

from pydantic import BaseModel, field_validator


# ---- Store profile ----

class VendorMeUpdate(BaseModel):
    store_name: str | None = None
    description: str | None = None
    address: str | None = None
    latitude: float | None = None
    longitude: float | None = None
    contact_number: str | None = None
    logo_url: str | None = None
    banner_url: str | None = None


class StoreStatusUpdate(BaseModel):
    is_open: bool | None = None
    is_paused: bool | None = None


# ---- Delivery settings ----

class DeliverySettingsUpdate(BaseModel):
    delivery_enabled: bool | None = None
    pickup_enabled: bool | None = None
    scheduled_delivery_enabled: bool | None = None
    delivery_radius_km: float | None = None
    base_delivery_fee: float | None = None
    fee_per_km: float | None = None
    estimated_prep_minutes: int | None = None
    delivery_barangays: list[str] | None = None


# ---- Operating hours ----

class OperatingHourIn(BaseModel):
    day_of_week: int  # 0=Monday ... 6=Sunday
    open_time: str    # "HH:MM"
    close_time: str   # "HH:MM"
    is_closed_all_day: bool = False

    @field_validator("day_of_week")
    @classmethod
    def valid_day(cls, v: int) -> int:
        if not 0 <= v <= 6:
            raise ValueError("day_of_week must be 0 (Monday) .. 6 (Sunday)")
        return v

    @field_validator("open_time", "close_time")
    @classmethod
    def valid_time(cls, v: str) -> str:
        parts = v.split(":")
        if len(parts) < 2 or not all(p.isdigit() for p in parts[:2]):
            raise ValueError("time must be HH:MM")
        hour, minute = int(parts[0]), int(parts[1])
        if not (0 <= hour <= 23 and 0 <= minute <= 59):
            raise ValueError("time must be HH:MM")
        return v


class HoursUpdate(BaseModel):
    hours: list[OperatingHourIn]


# ---- Categories ----

class CategoriesUpdate(BaseModel):
    categories: list[str]


# ---- Menu ----

class FoodOptionChoiceIn(BaseModel):
    label: str
    extra_price: float = 0


class FoodOptionIn(BaseModel):
    group_name: str
    is_required: bool = False
    allow_multiple: bool = True
    choices: list[FoodOptionChoiceIn] = []


class FoodItemCreate(BaseModel):
    name: str
    description: str | None = None
    price: float
    category: str | None = None
    is_available: bool = True
    is_featured: bool = False
    images: list[str] = []
    options: list[FoodOptionIn] = []


class FoodItemUpdate(BaseModel):
    name: str | None = None
    description: str | None = None
    price: float | None = None
    category: str | None = None
    is_available: bool | None = None
    is_featured: bool | None = None
    images: list[str] | None = None
    options: list[FoodOptionIn] | None = None


# ---- Analytics ----

class DayRevenue(BaseModel):
    date: str      # YYYY-MM-DD
    revenue: float
    orders: int


class AnalyticsOut(BaseModel):
    today_revenue: float
    today_orders: int
    pending_orders: int
    active_orders: int       # accepted/preparing/ready/out_for_delivery
    completed_today: int
    cancelled_today: int
    week: list[DayRevenue]   # last 7 days, oldest first
