import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Numeric, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.db import Base


class FoodCategory(Base):
    """Global taxonomy (used for search/browse), distinct from a vendor's own VendorCategory tags."""
    __tablename__ = "food_categories"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name: Mapped[str] = mapped_column(String(100), unique=True, nullable=False)
    icon_url: Mapped[str | None] = mapped_column(String(500), nullable=True)


class FoodItem(Base):
    __tablename__ = "food_items"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    vendor_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("vendors.id", ondelete="CASCADE"), nullable=False)
    category_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("food_categories.id"), nullable=True)

    name: Mapped[str] = mapped_column(String(150), nullable=False)
    description: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    price: Mapped[float] = mapped_column(Numeric(10, 2), nullable=False)
    is_available: Mapped[bool] = mapped_column(Boolean, default=True)
    is_featured: Mapped[bool] = mapped_column(Boolean, default=False)  # shown in the customer app's "Featured Foods" carousel

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    vendor = relationship("Vendor", back_populates="food_items")
    category = relationship("FoodCategory")
    images: Mapped[list["FoodImage"]] = relationship(back_populates="food_item", cascade="all, delete-orphan")
    options: Mapped[list["FoodOption"]] = relationship(back_populates="food_item", cascade="all, delete-orphan")


class FoodImage(Base):
    __tablename__ = "food_images"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    food_item_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("food_items.id", ondelete="CASCADE"), nullable=False)
    image_url: Mapped[str] = mapped_column(String(500), nullable=False)
    is_primary: Mapped[bool] = mapped_column(Boolean, default=False)

    food_item: Mapped[FoodItem] = relationship(back_populates="images")


class FoodOption(Base):
    """A group of choices for a food item, e.g. 'Add-ons' or 'Size'."""
    __tablename__ = "food_options"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    food_item_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("food_items.id", ondelete="CASCADE"), nullable=False)
    group_name: Mapped[str] = mapped_column(String(100), nullable=False)  # "Extras", "Size", "Add Cheese"
    is_required: Mapped[bool] = mapped_column(Boolean, default=False)
    allow_multiple: Mapped[bool] = mapped_column(Boolean, default=True)

    food_item: Mapped[FoodItem] = relationship(back_populates="options")
    choices: Mapped[list["FoodOptionChoice"]] = relationship(back_populates="option", cascade="all, delete-orphan")


class FoodOptionChoice(Base):
    __tablename__ = "food_option_choices"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    option_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("food_options.id", ondelete="CASCADE"), nullable=False)
    label: Mapped[str] = mapped_column(String(100), nullable=False)  # "Add Bacon"
    extra_price: Mapped[float] = mapped_column(Numeric(8, 2), default=0)

    option: Mapped[FoodOption] = relationship(back_populates="choices")
