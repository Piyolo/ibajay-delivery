import enum


class UserRole(str, enum.Enum):
    customer = "customer"
    vendor = "vendor"
    admin = "admin"


class OrderStatus(str, enum.Enum):
    pending = "pending"
    accepted = "accepted"
    preparing = "preparing"
    ready = "ready"
    out_for_delivery = "out_for_delivery"
    delivered = "delivered"
    completed = "completed"
    cancelled = "cancelled"


class DeliveryMethod(str, enum.Enum):
    delivery = "delivery"
    pickup = "pickup"
    scheduled_delivery = "scheduled_delivery"


class PaymentMethod(str, enum.Enum):
    cash_on_delivery = "cash_on_delivery"
    cash_on_pickup = "cash_on_pickup"
    gcash = "gcash"
    maya = "maya"
    credit_card = "credit_card"
    bank_transfer = "bank_transfer"


class OtpPurpose(str, enum.Enum):
    registration = "registration"
    password_reset = "password_reset"
    login_verification = "login_verification"


class NotificationType(str, enum.Enum):
    new_order = "new_order"
    order_accepted = "order_accepted"
    order_preparing = "order_preparing"
    out_for_delivery = "out_for_delivery"
    delivered = "delivered"
    chat_message = "chat_message"
    promotion = "promotion"
