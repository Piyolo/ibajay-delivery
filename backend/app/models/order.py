import uuid
from datetime import datetime

from sqlalchemy import DateTime, Enum, ForeignKey, Numeric, String, func
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.db import Base
from app.models.enums import DeliveryMethod, OrderStatus, PaymentMethod


class Order(Base):
    __tablename__ = "orders"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    order_number: Mapped[str] = mapped_column(String(20), unique=True, nullable=False)  # human-friendly, e.g. ORD-20260822-0001

    customer_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    vendor_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("vendors.id"), nullable=False)

    delivery_method: Mapped[DeliveryMethod] = mapped_column(Enum(DeliveryMethod), nullable=False)
    payment_method: Mapped[PaymentMethod] = mapped_column(Enum(PaymentMethod), nullable=False)
    status: Mapped[OrderStatus] = mapped_column(Enum(OrderStatus), default=OrderStatus.pending, nullable=False)

    # Snapshot of delivery address at order time (address may change later)
    delivery_address: Mapped[str | None] = mapped_column(String(500), nullable=True)
    delivery_latitude: Mapped[float | None] = mapped_column(nullable=True)
    delivery_longitude: Mapped[float | None] = mapped_column(nullable=True)

    scheduled_for: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    subtotal: Mapped[float] = mapped_column(Numeric(10, 2), nullable=False)
    delivery_fee: Mapped[float] = mapped_column(Numeric(10, 2), default=0)
    total: Mapped[float] = mapped_column(Numeric(10, 2), nullable=False)

    special_instructions: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    cancellation_reason: Mapped[str | None] = mapped_column(String(500), nullable=True)

    # Live tracking (vendor's last known GPS position while "out_for_delivery")
    rider_current_lat: Mapped[float | None] = mapped_column(nullable=True)
    rider_current_lng: Mapped[float | None] = mapped_column(nullable=True)
    rider_last_updated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    items: Mapped[list["OrderItem"]] = relationship(back_populates="order", cascade="all, delete-orphan")
    status_history: Mapped[list["OrderStatusHistory"]] = relationship(back_populates="order", cascade="all, delete-orphan")


class OrderItem(Base):
    __tablename__ = "order_items"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    order_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("orders.id", ondelete="CASCADE"), nullable=False)
    food_item_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("food_items.id"), nullable=False)

    # Snapshot fields so historical orders remain accurate even if the menu changes later
    item_name: Mapped[str] = mapped_column(String(150), nullable=False)
    unit_price: Mapped[float] = mapped_column(Numeric(10, 2), nullable=False)
    quantity: Mapped[int] = mapped_column(nullable=False, default=1)
    selected_options: Mapped[dict] = mapped_column(JSONB, default=dict)  # {"Extras": ["Add Cheese", "Add Bacon"]}
    line_total: Mapped[float] = mapped_column(Numeric(10, 2), nullable=False)
    special_instructions: Mapped[str | None] = mapped_column(String(500), nullable=True)

    order: Mapped[Order] = relationship(back_populates="items")


class OrderStatusHistory(Base):
    __tablename__ = "order_status_history"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    order_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("orders.id", ondelete="CASCADE"), nullable=False)
    status: Mapped[OrderStatus] = mapped_column(Enum(OrderStatus), nullable=False)
    note: Mapped[str | None] = mapped_column(String(500), nullable=True)
    changed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    order: Mapped[Order] = relationship(back_populates="status_history")
