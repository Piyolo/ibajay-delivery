import uuid
from datetime import datetime, timezone

from pydantic import BaseModel, Field, model_validator

from app.models.enums import DeliveryMethod, OrderStatus, PaymentMethod

# Hard caps matching DB column widths (String lengths below) and sane
# business limits. These live next to the schemas because pydantic is the
# one gate EVERY checkout request passes through before any DB work.
MAX_CART_ITEMS = 50
MAX_QUANTITY = 99
MAX_SPECIAL_INSTRUCTIONS = 1000  # orders.special_instructions is String(1000)
MAX_ITEM_INSTRUCTIONS = 500  # order_items.special_instructions is String(500)
MAX_PROMO_CODE = 40  # promotions.code is String(40)


class CartItemIn(BaseModel):
    food_item_id: uuid.UUID
    # ge=1 blocks zero/negative quantities (which previously produced
    # negative line totals and a payable ₱0 order); le=99 keeps
    # unit_price * quantity inside a sane range and away from int4 overflow.
    quantity: int = Field(default=1, ge=1, le=MAX_QUANTITY)
    selected_options: dict[str, list[str]] = {}  # {"Extras": ["Add Cheese"]}
    special_instructions: str | None = Field(default=None, max_length=MAX_ITEM_INSTRUCTIONS)


class CheckoutRequest(BaseModel):
    vendor_id: uuid.UUID
    items: list[CartItemIn]
    delivery_method: DeliveryMethod
    payment_method: PaymentMethod
    address_id: uuid.UUID | None = None  # required if delivery_method != pickup
    scheduled_for: datetime | None = None  # required if delivery_method == scheduled_delivery
    special_instructions: str | None = Field(default=None, max_length=MAX_SPECIAL_INSTRUCTIONS)
    promo_code: str | None = Field(default=None, max_length=MAX_PROMO_CODE)

    @model_validator(mode="after")
    def validate_method_requirements(self):
        if self.delivery_method != DeliveryMethod.pickup and not self.address_id:
            raise ValueError("address_id is required for delivery orders")
        if self.delivery_method == DeliveryMethod.scheduled_delivery and not self.scheduled_for:
            raise ValueError("scheduled_for is required for scheduled deliveries")
        if len(self.items) > MAX_CART_ITEMS:
            raise ValueError(f"Cart cannot contain more than {MAX_CART_ITEMS} items")
        if self.scheduled_for is not None:
            now = datetime.now(timezone.utc)
            scheduled = (
                self.scheduled_for.replace(tzinfo=timezone.utc)
                if self.scheduled_for.tzinfo is None
                else self.scheduled_for
            )
            if scheduled < now:
                raise ValueError("scheduled_for cannot be in the past")
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
    note: str | None = Field(default=None, max_length=500)  # order_status_history.note is String(500)
