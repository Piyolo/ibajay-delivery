import uuid
from datetime import datetime

from pydantic import BaseModel


class VendorCardOut(BaseModel):
    id: uuid.UUID
    store_name: str
    logo_url: str | None
    average_rating: float
    is_open: bool
    delivery_enabled: bool
    pickup_enabled: bool
    estimated_prep_minutes: int
    distance_km: float | None = None

    class Config:
        from_attributes = True


class FoodOptionChoiceOut(BaseModel):
    id: uuid.UUID
    label: str
    extra_price: float

    class Config:
        from_attributes = True


class FoodOptionOut(BaseModel):
    id: uuid.UUID
    group_name: str
    is_required: bool
    allow_multiple: bool
    choices: list[FoodOptionChoiceOut]

    class Config:
        from_attributes = True


class FoodItemOut(BaseModel):
    id: uuid.UUID
    name: str
    description: str | None
    price: float
    is_available: bool
    is_featured: bool = False
    category: str | None = None
    images: list[str] = []
    options: list[FoodOptionOut] = []

    class Config:
        from_attributes = True


class PromotionOut(BaseModel):
    id: uuid.UUID
    title: str
    description: str | None = None
    discount_type: str
    discount_value: float
    code: str | None = None
    min_subtotal: float = 0
    starts_at: datetime | None = None
    ends_at: datetime | None = None

    class Config:
        from_attributes = True


class VendorProfileOut(BaseModel):
    id: uuid.UUID
    store_name: str
    description: str | None
    logo_url: str | None
    banner_url: str | None
    address: str
    latitude: float
    longitude: float
    average_rating: float
    total_reviews: int
    is_open: bool
    is_verified: bool = False
    delivery_enabled: bool
    pickup_enabled: bool
    scheduled_delivery_enabled: bool
    delivery_radius_km: float = 5
    base_delivery_fee: float = 0
    fee_per_km: float = 0
    estimated_prep_minutes: int = 20
    delivery_barangays: list[str] = []
    categories: list[str] = []
    food_items: list[FoodItemOut] = []
    promotions: list[PromotionOut] = []

    class Config:
        from_attributes = True
