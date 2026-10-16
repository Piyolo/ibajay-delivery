"""Request/response schemas for the vendor back-office portal.

Every string cap mirrors its model column's VARCHAR width (field lengths
were previously unchecked, so an 800-char store name reached Postgres and
surfaced as a raw 500 instead of a friendly 422). Numeric caps match sane
business ranges (prices/fees in pesos, radius in km, prep in minutes).
"""
import uuid
from datetime import datetime

from pydantic import BaseModel, Field, field_validator, model_validator


# ---- Shared guardrails ----

def _require(value: str | None, field: str, min_len: int = 1) -> str | None:
    if value is None:
        return None
    cleaned = value.strip()
    if len(cleaned) < min_len:
        raise ValueError(f"{field} is required")
    return cleaned


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
    hours: list[OperatingHourIn] = Field(default_factory=list, max_length=7)


# ---- Store profile ----

def _validate_geo(lat: float | None, lng: float | None) -> None:
    if lat is not None and not -90 <= lat <= 90:
        raise ValueError("latitude must be between -90 and 90")
    if lng is not None and not -180 <= lng <= 180:
        raise ValueError("longitude must be between -180 and 180")


class VendorStoreCreate(BaseModel):
    """Creates the store for a freshly-registered vendor account."""
    store_name: str = Field(max_length=150)   # vendors.store_name is String(150)
    description: str | None = Field(default=None, max_length=1000)  # String(1000)
    address: str = Field(max_length=500)      # vendors.address is String(500)
    latitude: float = 11.8211   # Ibajay town proper default (11°49'16"N)
    longitude: float = 122.1617
    contact_number: str = Field(default="", max_length=20)  # String(20)
    logo_url: str | None = Field(default=None, max_length=500)
    banner_url: str | None = Field(default=None, max_length=500)
    categories: list[str] = []
    delivery_enabled: bool = True
    pickup_enabled: bool = True
    scheduled_delivery_enabled: bool = False
    base_delivery_fee: float = 30
    delivery_barangays: list[str] = []
    hours: list[OperatingHourIn] = []

    @field_validator("store_name")
    @classmethod
    def clean_store_name(cls, v: str) -> str:
        return _require(v, "Store name", min_len=2) or ""

    @field_validator("address")
    @classmethod
    def clean_address(cls, v: str) -> str:
        return _require(v, "Address") or ""

    @model_validator(mode="after")
    def check_geo(self):
        _validate_geo(self.latitude, self.longitude)
        if self.base_delivery_fee < 0:
            raise ValueError("base_delivery_fee cannot be negative")
        if len(self.categories) > 20:
            raise ValueError("A store cannot have more than 20 categories")
        if len(self.delivery_barangays) > 60:
            raise ValueError("Delivery area list is too long")
        return self

    @field_validator("categories")
    @classmethod
    def clean_categories(cls, values: list[str]) -> list[str]:
        cleaned: list[str] = []
        for v in values:
            if not isinstance(v, str):
                raise ValueError("categories must be strings")
            name = v.strip()[:100]  # vendor_categories.name is String(100)
            if name and name not in cleaned:
                cleaned.append(name)
        return cleaned


class VendorMeUpdate(BaseModel):
    store_name: str | None = Field(default=None, max_length=150)
    description: str | None = Field(default=None, max_length=1000)
    address: str | None = Field(default=None, max_length=500)
    latitude: float | None = None
    longitude: float | None = None
    contact_number: str | None = Field(default=None, max_length=20)
    logo_url: str | None = Field(default=None, max_length=500)
    banner_url: str | None = Field(default=None, max_length=500)

    @model_validator(mode="after")
    def check_geo(self):
        _validate_geo(self.latitude, self.longitude)
        return self


class StoreStatusUpdate(BaseModel):
    is_open: bool | None = None
    is_paused: bool | None = None


# ---- Delivery settings ----

class DeliverySettingsUpdate(BaseModel):
    delivery_enabled: bool | None = None
    pickup_enabled: bool | None = None
    scheduled_delivery_enabled: bool | None = None
    delivery_radius_km: float | None = Field(default=None, ge=0.1, le=50)
    base_delivery_fee: float | None = Field(default=None, ge=0, le=10000)
    fee_per_km: float | None = Field(default=None, ge=0, le=10000)
    estimated_prep_minutes: int | None = Field(default=None, ge=1, le=480)
    delivery_barangays: list[str] | None = None

    @field_validator("delivery_barangays")
    @classmethod
    def clean_barangays(cls, values: list[str] | None) -> list[str] | None:
        if values is None:
            return None
        if len(values) > 60:
            raise ValueError("Delivery area list is too long")
        cleaned = []
        for v in values:
            if not isinstance(v, str):
                raise ValueError("delivery_barangays must be strings")
            name = v.strip()[:100]
            if name and name not in cleaned:
                cleaned.append(name)
        return cleaned


# ---- Categories ----

class CategoriesUpdate(BaseModel):
    categories: list[str]

    @field_validator("categories")
    @classmethod
    def cap_and_clean(cls, values: list[str]) -> list[str]:
        cleaned: list[str] = []
        for v in values:
            if not isinstance(v, str):
                raise ValueError("categories must be strings")
            name = v.strip()[:100]
            if name and name not in cleaned:
                cleaned.append(name)
        if len(cleaned) > 20:
            raise ValueError("A store cannot have more than 20 categories")
        return cleaned


# ---- Menu ----

class FoodOptionChoiceIn(BaseModel):
    label: str = Field(max_length=100)          # food_option_choices.label is String(100)
    extra_price: float = Field(default=0, ge=0, le=100000)

    @field_validator("label")
    @classmethod
    def clean_label(cls, v: str) -> str:
        return _require(v, "Choice label") or ""


class FoodOptionIn(BaseModel):
    group_name: str = Field(max_length=100)     # food_options.group_name is String(100)
    is_required: bool = False
    allow_multiple: bool = True
    choices: list[FoodOptionChoiceIn] = Field(default_factory=list, max_length=20)

    @field_validator("group_name")
    @classmethod
    def clean_group(cls, v: str) -> str:
        return _require(v, "Option group name") or ""


class FoodItemCreate(BaseModel):
    name: str = Field(max_length=150)           # food_items.name is String(150)
    description: str | None = Field(default=None, max_length=1000)  # String(1000)
    price: float = Field(gt=0, le=100000)
    category: str | None = Field(default=None, max_length=200)
    is_available: bool = True
    is_featured: bool = False
    images: list[str] = Field(default_factory=list, max_length=6)
    options: list[FoodOptionIn] = Field(default_factory=list, max_length=10)

    @field_validator("name")
    @classmethod
    def clean_name(cls, v: str) -> str:
        return _require(v, "Item name", min_len=2) or ""


class FoodItemUpdate(BaseModel):
    name: str | None = Field(default=None, max_length=150)
    description: str | None = Field(default=None, max_length=1000)
    price: float | None = Field(default=None, gt=0, le=100000)
    category: str | None = Field(default=None, max_length=200)
    is_available: bool | None = None
    is_featured: bool | None = None
    images: list[str] | None = Field(default=None, max_length=6)
    options: list[FoodOptionIn] | None = Field(default=None, max_length=10)

    @field_validator("name")
    @classmethod
    def clean_name(cls, v: str | None) -> str | None:
        if v is None:
            return None
        return _require(v, "Item name", min_len=2)


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


# ---- Promotions ----

class PromotionCreate(BaseModel):
    title: str = Field(max_length=120)          # promotions.title is String(120)
    description: str | None = Field(default=None, max_length=500)  # String(500)
    discount_type: str = "percent"   # percent | fixed
    discount_value: float            # validated below (percent cap lives at the route)
    code: str | None = Field(default=None, max_length=40)  # uppercase; None = auto-applied store-wide
    min_subtotal: float = Field(default=0, ge=0, le=100000)
    starts_at: datetime | None = None
    ends_at: datetime | None = None

    @field_validator("discount_type")
    @classmethod
    def valid_type(cls, v: str) -> str:
        if v not in ("percent", "fixed"):
            raise ValueError("discount_type must be 'percent' or 'fixed'")
        return v

    @field_validator("code")
    @classmethod
    def normalize_code(cls, v: str | None) -> str | None:
        if v is None:
            return None
        code = v.strip().upper()[:40]
        return code or None

    @field_validator("discount_value")
    @classmethod
    def positive(cls, v: float) -> float:
        if v <= 0:
            raise ValueError("discount_value must be greater than 0")
        if v > 100000:
            raise ValueError("discount_value is too large")
        return v

    @field_validator("title")
    @classmethod
    def clean_title(cls, v: str) -> str:
        return _require(v, "Promotion title", min_len=2) or ""


class PromotionUpdate(BaseModel):
    title: str | None = Field(default=None, max_length=120)
    description: str | None = Field(default=None, max_length=500)
    discount_value: float | None = Field(default=None, gt=0, le=100000)
    min_subtotal: float | None = Field(default=None, ge=0, le=100000)
    starts_at: datetime | None = None
    ends_at: datetime | None = None
    is_active: bool | None = None


class PromotionOut(BaseModel):
    id: uuid.UUID
    title: str
    description: str | None
    discount_type: str
    discount_value: float
    code: str | None
    min_subtotal: float
    starts_at: datetime | None
    ends_at: datetime | None
    is_active: bool
    times_used: int

    class Config:
        from_attributes = True
