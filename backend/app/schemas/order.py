import uuid
from datetime import datetime

from pydantic import BaseModel, model_validator

from app.models.enums import DeliveryMethod, OrderStatus, PaymentMethod


class CartItemIn(BaseModel):
    food_item_id: uuid.UUID
    quantity: int = 1
    selected_options: dict[str, list[str]] = {}  # {"Extras": ["Add Cheese"]}
    special_instructions: str | None = None


class CheckoutRequest(BaseModel):
    vendor_id: uuid.UUID
    items: list[CartItemIn]
    delivery_method: DeliveryMethod
    payment_method: PaymentMethod
    address_id: uuid.UUID | None = None  # required if delivery_method != pickup
    scheduled_for: datetime | None = None  # required if delivery_method == scheduled_delivery
    special_instructions: str | None = None
    promo_code: str | None = None

    @model_validator(mode="after")
    def validate_method_requirements(self):
        if self.delivery_method != DeliveryMethod.pickup and not self.address_id:
            raise ValueError("address_id is required for delivery orders")
        if self.delivery_method == DeliveryMethod.scheduled_delivery and not self.scheduled_for:
            raise ValueError("scheduled_for is required for scheduled deliveries")
        return self


class PromoValidateRequest(BaseModel):
    vendor_id: uuid.UUID
    code: str
    subtotal: float


class PromoValidateOut(BaseModel):
    valid: bool
    title: str | None = None
    discount: float = 0
    message: str | None = None


class OrderItemOut(BaseModel):
    id: uuid.UUID
    item_name: str
    unit_price: float
    quantity: int
    selected_options: dict
    line_total: float
    special_instructions: str | None

    class Config:
        from_attributes = True


class OrderOut(BaseModel):
    id: uuid.UUID
    order_number: str
    vendor_id: uuid.UUID
    status: OrderStatus
    delivery_method: DeliveryMethod
    payment_method: PaymentMethod
    subtotal: float
    delivery_fee: float
    discount: float = 0
    total: float
    scheduled_for: datetime | None
    created_at: datetime
    items: list[OrderItemOut]
    # Populated for the vendor inbox (customer-facing endpoints omit them):
    customer_name: str | None = None
    customer_mobile: str | None = None
    delivery_address: str | None = None
    delivery_latitude: float | None = None
    delivery_longitude: float | None = None
    special_instructions: str | None = None
    cancellation_reason: str | None = None

    class Config:
        from_attributes = True


class UpdateOrderStatus(BaseModel):
    status: OrderStatus
    note: str | None = None
