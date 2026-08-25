import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_db
from app.core.deps import require_vendor
from app.models.enums import OrderStatus
from app.models.order import Order
from app.models.user import User
from app.models.vendor import Vendor
from app.services.realtime import connection_manager

router = APIRouter(prefix="/tracking", tags=["Delivery Tracking"])


class GpsPing(BaseModel):
    latitude: float
    longitude: float


@router.post("/{order_id}/start")
async def start_delivery(order_id: uuid.UUID, user: User = Depends(require_vendor), db: AsyncSession = Depends(get_db)):
    """Vendor presses 'Start Delivery' — flips the order to out_for_delivery and opens GPS tracking."""
    order_result = await db.execute(select(Order).where(Order.id == order_id))
    order = order_result.scalar_one_or_none()
    if not order:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Order not found")

    vendor_result = await db.execute(select(Vendor).where(Vendor.id == order.vendor_id))
    vendor = vendor_result.scalar_one_or_none()
    if not vendor or vendor.owner_id != user.id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Not your store's order")
    if order.status != OrderStatus.ready:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Order must be 'ready' before starting delivery")

    order.status = OrderStatus.out_for_delivery
    await db.commit()

    await connection_manager.broadcast_to_order(
        order.id, {"type": "status_update", "order_id": str(order.id), "status": "out_for_delivery"}
    )
    return {"message": "Delivery started, GPS tracking active"}


@router.post("/{order_id}/gps-ping")
async def push_gps_ping(
    order_id: uuid.UUID,
    payload: GpsPing,
    user: User = Depends(require_vendor),
    db: AsyncSession = Depends(get_db),
):
    """
    Vendor app calls this every few seconds while status == out_for_delivery.
    Persists the last-known location and fans it out to the customer's
    tracking WebSocket in real time.
    """
    order_result = await db.execute(select(Order).where(Order.id == order_id))
    order = order_result.scalar_one_or_none()
    if not order:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Order not found")
    if order.status != OrderStatus.out_for_delivery:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Order is not currently out for delivery")

    order.rider_current_lat = payload.latitude
    order.rider_current_lng = payload.longitude
    order.rider_last_updated_at = datetime.now(timezone.utc)
    await db.commit()

    await connection_manager.broadcast_to_order(
        order.id,
        {
            "type": "gps_update",
            "order_id": str(order.id),
            "latitude": payload.latitude,
            "longitude": payload.longitude,
            "timestamp": order.rider_last_updated_at.isoformat(),
        },
    )
    return {"message": "ok"}
