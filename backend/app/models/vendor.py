import uuid
from datetime import datetime, time

from sqlalchemy import Boolean, DateTime, ForeignKey, Numeric, String, func
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.db import Base


class Vendor(Base):
    __tablename__ = "vendors"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    owner_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), unique=True, nullable=False)

    store_name: Mapped[str] = mapped_column(String(150), nullable=False)
    description: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    logo_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    banner_url: Mapped[str | None] = mapped_column(String(500), nullable=True)

    address: Mapped[str] = mapped_column(String(500), nullable=False)
    latitude: Mapped[float] = mapped_column(nullable=False)
    longitude: Mapped[float] = mapped_column(nullable=False)
    contact_number: Mapped[str] = mapped_column(String(20), nullable=False)

    is_verified: Mapped[bool] = mapped_column(Boolean, default=False)   # admin-approved badge
    is_open: Mapped[bool] = mapped_column(Boolean, default=False)       # manual open/closed toggle
    is_paused: Mapped[bool] = mapped_column(Boolean, default=False)     # "emergency pause"

    average_rating: Mapped[float] = mapped_column(Numeric(3, 2), default=0)
    total_reviews: Mapped[int] = mapped_column(default=0)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    owner = relationship("User", back_populates="vendor_profile")
    delivery_settings: Mapped["VendorDeliverySettings"] = relationship(back_populates="vendor", uselist=False, cascade="all, delete-orphan")
    operating_hours: Mapped[list["VendorOperatingHours"]] = relationship(back_populates="vendor", cascade="all, delete-orphan")
    categories: Mapped[list["VendorCategory"]] = relationship(back_populates="vendor", cascade="all, delete-orphan")
    food_items: Mapped[list["FoodItem"]] = relationship(back_populates="vendor", cascade="all, delete-orphan")


class VendorCategory(Base):
    """e.g. Fast Food, Drinks, Desserts — tags a vendor belongs to."""
    __tablename__ = "vendor_categories"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    vendor_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("vendors.id", ondelete="CASCADE"), nullable=False)
    name: Mapped[str] = mapped_column(String(100), nullable=False)

    vendor: Mapped[Vendor] = relationship(back_populates="categories")


class VendorDeliverySettings(Base):
    __tablename__ = "vendor_delivery_settings"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    vendor_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("vendors.id", ondelete="CASCADE"), unique=True, nullable=False)

    delivery_enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    pickup_enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    scheduled_delivery_enabled: Mapped[bool] = mapped_column(Boolean, default=False)

    delivery_radius_km: Mapped[float] = mapped_column(Numeric(5, 2), default=5.0)
    base_delivery_fee: Mapped[float] = mapped_column(Numeric(8, 2), default=0)
    fee_per_km: Mapped[float] = mapped_column(Numeric(8, 2), default=0)  # for distance-based fee calc
    estimated_prep_minutes: Mapped[int] = mapped_column(default=20)

    # Municipality-scoped delivery coverage: barangays of Ibajay this store
    # serves. Takes precedence over the radius when non-empty (the customer
    # app matches the customer's barangay against this list).
    delivery_barangays: Mapped[list] = mapped_column(JSONB, default=list)

    vendor: Mapped[Vendor] = relationship(back_populates="delivery_settings")


class VendorOperatingHours(Base):
    __tablename__ = "vendor_operating_hours"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    vendor_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("vendors.id", ondelete="CASCADE"), nullable=False)

    day_of_week: Mapped[int] = mapped_column(nullable=False)  # 0=Monday ... 6=Sunday
    open_time: Mapped[time] = mapped_column(nullable=False)
    close_time: Mapped[time] = mapped_column(nullable=False)
    is_closed_all_day: Mapped[bool] = mapped_column(Boolean, default=False)

    vendor: Mapped[Vendor] = relationship(back_populates="operating_hours")
