import logging
import uuid

from sqlalchemy.ext.asyncio import AsyncSession

from app.models.enums import NotificationType
from app.models.order import Order
from app.models.social import Notification

logger = logging.getLogger(__name__)

EVENT_TO_NOTIFICATION = {
    "new_order": (NotificationType.new_order, "New Order Received", "You have a new order {order_number}."),
    "accepted": (NotificationType.order_accepted, "Order Accepted", "Your order {order_number} has been accepted."),
    "preparing": (NotificationType.order_preparing, "Preparing Your Order", "Order {order_number} is being prepared."),
    "out_for_delivery": (NotificationType.out_for_delivery, "Out For Delivery", "Order {order_number} is on its way!"),
    "delivered": (NotificationType.delivered, "Delivered", "Order {order_number} has been delivered."),
    "cancelled": (NotificationType.order_cancelled, "Order Cancelled", "Order {order_number} has been cancelled."),
}


async def notify_order_event(
    db: AsyncSession, recipient_user_id: uuid.UUID, order: Order, event: str
) -> None:
    """Persists an in-app notification row for an order event.

    `db` is the caller's request session: every call site awaits this inside
    the request (after the order/status change itself was committed), so the
    per-request session is still open and is the simplest correct choice —
    no background queue is involved.

    A failure here must never break the already-committed status change the
    caller just made, so insert problems are rolled back and logged loudly
    instead of raised. FCM push is intentionally not implemented.
    """
    mapping = EVENT_TO_NOTIFICATION.get(event)
    if not mapping:
        return
    ntype, title, body_template = mapping
    body = body_template.format(order_number=order.order_number)

    try:
        db.add(
            Notification(
                user_id=recipient_user_id,
                type=ntype,
                title=title,
                body=body,
                related_order_id=order.id,
                is_read=False,
            )
        )
        await db.commit()
    except Exception:
        await db.rollback()
        logger.exception(
            "Failed to persist notification: user=%s event=%s order=%s",
            recipient_user_id,
            event,
            order.order_number,
        )
