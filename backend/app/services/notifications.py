import uuid

from app.models.enums import NotificationType
from app.models.order import Order

EVENT_TO_NOTIFICATION = {
    "new_order": (NotificationType.new_order, "New Order Received", "You have a new order {order_number}."),
    "accepted": (NotificationType.order_accepted, "Order Accepted", "Your order {order_number} has been accepted."),
    "preparing": (NotificationType.order_preparing, "Preparing Your Order", "Order {order_number} is being prepared."),
    "out_for_delivery": (NotificationType.out_for_delivery, "Out For Delivery", "Order {order_number} is on its way!"),
    "delivered": (NotificationType.delivered, "Delivered", "Order {order_number} has been delivered."),
}


async def notify_order_event(recipient_user_id: uuid.UUID, order: Order, event: str) -> None:
    """
    Writes a notification and (in production) triggers an FCM push.
    Kept decoupled from the DB session of the calling route so it can be
    fire-and-forget; wire this to a background task queue (e.g. Celery/RQ)
    once volume grows.
    """
    mapping = EVENT_TO_NOTIFICATION.get(event)
    if not mapping:
        return
    _, title, body_template = mapping
    body = body_template.format(order_number=order.order_number)

    # TODO: persist via a dedicated async session and call services/push.py (FCM)
    print(f"[NOTIFY] user={recipient_user_id} title={title!r} body={body!r}")
