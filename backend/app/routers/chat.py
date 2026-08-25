import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.db import get_db
from app.core.deps import get_current_user
from app.models.social import Chat, Message
from app.models.user import User
from app.models.vendor import Vendor

router = APIRouter(prefix="/chats", tags=["Chat"])


class ChatCreate(BaseModel):
    vendor_id: uuid.UUID
    order_id: uuid.UUID | None = None


class MessageOut(BaseModel):
    id: uuid.UUID
    sender_id: uuid.UUID
    content: str | None
    image_url: str | None
    is_read: bool

    class Config:
        from_attributes = True


class ChatOut(BaseModel):
    id: uuid.UUID
    vendor_id: uuid.UUID
    order_id: uuid.UUID | None
    messages: list[MessageOut]

    class Config:
        from_attributes = True


@router.post("", response_model=ChatOut, status_code=status.HTTP_201_CREATED)
async def start_or_get_chat(payload: ChatCreate, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """Idempotent: returns the existing thread for this (customer, vendor, order) if one exists."""
    stmt = select(Chat).options(selectinload(Chat.messages)).where(
        Chat.customer_id == user.id, Chat.vendor_id == payload.vendor_id
    )
    if payload.order_id:
        stmt = stmt.where(Chat.order_id == payload.order_id)
    result = await db.execute(stmt)
    chat = result.scalars().first()
    if chat:
        return chat

    vendor_result = await db.execute(select(Vendor).where(Vendor.id == payload.vendor_id))
    if not vendor_result.scalar_one_or_none():
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Vendor not found")

    chat = Chat(customer_id=user.id, vendor_id=payload.vendor_id, order_id=payload.order_id)
    db.add(chat)
    await db.commit()
    await db.refresh(chat, attribute_names=["messages"])
    return chat


@router.get("/{chat_id}/messages", response_model=list[MessageOut])
async def get_messages(chat_id: uuid.UUID, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    chat_result = await db.execute(select(Chat).where(Chat.id == chat_id))
    chat = chat_result.scalar_one_or_none()
    if not chat:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Chat not found")

    vendor_result = await db.execute(select(Vendor).where(Vendor.id == chat.vendor_id))
    vendor = vendor_result.scalar_one_or_none()
    if chat.customer_id != user.id and (not vendor or vendor.owner_id != user.id):
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Not authorized")

    result = await db.execute(select(Message).where(Message.chat_id == chat_id).order_by(Message.created_at.asc()))
    return result.scalars().all()
