import uuid
from datetime import datetime

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import get_db
from app.core.deps import get_current_user
from app.models.enums import NotificationType
from app.models.social import Notification
from app.models.user import User

router = APIRouter(prefix="/notifications", tags=["Notifications"])

# In-app notification center: newest-first, capped so the payload stays small.
LIST_LIMIT = 50


class NotificationOut(BaseModel):
    id: uuid.UUID
    title: str
    body: str
    type: NotificationType
    related_order_id: uuid.UUID | None
    is_read: bool
    created_at: datetime

    class Config:
        from_attributes = True


class ReadAllOut(BaseModel):
    updated: int


@router.get("", response_model=list[NotificationOut])
async def list_notifications(user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """The current user's notifications (customer or vendor), newest first."""
    result = await db.execute(
        select(Notification)
        .where(Notification.user_id == user.id)
        .order_by(Notification.created_at.desc())
        .limit(LIST_LIMIT)
    )
    return result.scalars().all()


@router.post("/read-all", response_model=ReadAllOut)
async def mark_all_read(user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """Marks every unread notification of the current user as read."""
    result = await db.execute(
        update(Notification)
        .where(Notification.user_id == user.id, Notification.is_read == False)  # noqa: E712
        .values(is_read=True)
    )
    await db.commit()
    return ReadAllOut(updated=int(result.rowcount or 0))
