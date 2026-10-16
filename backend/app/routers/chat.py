import uuid

from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.db import get_db
from app.core.deps import get_current_user, require_vendor
from app.models.order import Order
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
    created_at: datetime

    class Config:
        from_attributes = True


class ChatOut(BaseModel):
    id: uuid.UUID
    vendor_id: uuid.UUID
    order_id: uuid.UUID | None
    messages: list[MessageOut]

    class Config:
        from_attributes = True


class ChatThreadOut(BaseModel):
    id: uuid.UUID
    vendor_id: uuid.UUID
    vendor_name: str
    vendor_logo_url: str | None
    customer_id: uuid.UUID
    customer_name: str
    order_id: uuid.UUID | None
    last_message: str | None
    last_message_at: datetime
    last_sender_id: uuid.UUID | None
    message_count: int
    # Customer's mobile so the vendor's "Call customer" action works even
    # when the thread has no linked order.
    customer_mobile: str | None = None


@router.post("", response_model=ChatOut, status_code=status.HTTP_201_CREATED)
async def start_or_get_chat(payload: ChatCreate, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """Idempotent per (customer, vendor): returns the ongoing thread for
    this pair whether or not it was started from a specific order. This
    prevents duplicate threads when a customer opens chat sometimes from an
    order and sometimes from the store profile.

    A payload.order_id is now validated: only a party of THAT order (its
    customer or its store's owner) may link it to a thread, and only to a
    thread with the same store — previously any UUID was accepted, so one
    customer could graft another customer's order id onto their own chat."""
    if payload.order_id:
        order_result = await db.execute(select(Order).where(Order.id == payload.order_id))
        order = order_result.scalar_one_or_none()
        if not order:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Order not found")
        if order.vendor_id != payload.vendor_id:
            raise HTTPException(
                status.HTTP_400_BAD_REQUEST,
                "That order does not belong to this store",
            )
        vendor_of_order = (
            await db.execute(select(Vendor).where(Vendor.id == order.vendor_id))
        ).scalar_one_or_none()
        caller_is_party = order.customer_id == user.id or (
            vendor_of_order and vendor_of_order.owner_id == user.id
        )
        if not caller_is_party:
            raise HTTPException(status.HTTP_403_FORBIDDEN, "Not authorized to link this order")

    # Server-side vendor scoping (mirrors every /vendor/me* route): a vendor
    # account may only open chat threads for its own store, never for other
    # stores' vendor_id.
    if user.role.value == "vendor":
        own_store = (
            await db.execute(
                select(Vendor).where(Vendor.id == payload.vendor_id, Vendor.owner_id == user.id)
            )
        ).scalar_one_or_none()
        if not own_store:
            raise HTTPException(
                status.HTTP_403_FORBIDDEN,
                "Vendors may only chat with customers of their own store",
            )

    base_stmt = (
        select(Chat)
        .options(selectinload(Chat.messages))
        .where(Chat.customer_id == user.id, Chat.vendor_id == payload.vendor_id)
    )

    chat = None
    if payload.order_id:
        exact = await db.execute(base_stmt.where(Chat.order_id == payload.order_id))
        chat = exact.scalars().first()

    if chat is None:
        # Fall back to ANY existing thread with this vendor (most recent first).
        any_stmt = await db.execute(base_stmt.order_by(Chat.created_at.desc()))
        chat = any_stmt.scalars().first()

    if chat is not None:
        # Attach the order that opened this conversation, if the thread
        # isn't already linked to one.
        if payload.order_id and chat.order_id is None:
            chat.order_id = payload.order_id
            await db.commit()
            await db.refresh(chat, attribute_names=["messages"])
        return chat

    vendor_result = await db.execute(select(Vendor).where(Vendor.id == payload.vendor_id))
    if not vendor_result.scalar_one_or_none():
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Vendor not found")

    chat = Chat(customer_id=user.id, vendor_id=payload.vendor_id, order_id=payload.order_id)
    db.add(chat)
    await db.commit()
    await db.refresh(chat, attribute_names=["messages"])
    return chat


@router.get("/my", response_model=list[ChatThreadOut])
async def my_threads(user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    """The customer's chat threads (for the chat list screen)."""
    result = await db.execute(
        select(Chat)
        .options(selectinload(Chat.messages))
        .where(Chat.customer_id == user.id)
        .order_by(Chat.created_at.desc())
    )
    chats = result.scalars().unique().all()
    return await _thread_payloads(db, chats, customer_view=True)


@router.get("/vendor", response_model=list[ChatThreadOut])
async def vendor_threads(user: User = Depends(require_vendor), db: AsyncSession = Depends(get_db)):
    """The vendor's chat threads across their store."""
    vendor_result = await db.execute(select(Vendor).where(Vendor.owner_id == user.id))
    vendor = vendor_result.scalar_one_or_none()
    if not vendor:
        return []

    result = await db.execute(
        select(Chat)
        .options(selectinload(Chat.messages))
        .where(Chat.vendor_id == vendor.id)
        .order_by(Chat.created_at.desc())
    )
    chats = result.scalars().unique().all()
    return await _thread_payloads(db, chats, customer_view=False)


async def _thread_payloads(db: AsyncSession, chats: list[Chat], *, customer_view: bool):
    """Builds thread summaries, resolving the display name/logo per side."""
    from sqlalchemy.orm import selectinload as _sel

    vendor_ids = {c.vendor_id for c in chats}
    customer_ids = {c.customer_id for c in chats}

    vendors: dict = {}
    if vendor_ids:
        rows = await db.execute(
            select(Vendor).options(_sel(Vendor.owner)).where(Vendor.id.in_(vendor_ids))
        )
        vendors = {v.id: v for v in rows.scalars().all()}

    customers: dict = {}
    if customer_ids:
        rows = await db.execute(select(User).where(User.id.in_(customer_ids)))
        customers = {u.id: u for u in rows.scalars().all()}

    payloads: list[ChatThreadOut] = []
    for c in chats:
        vendor = vendors.get(c.vendor_id)
        customer = customers.get(c.customer_id)
        last = max(c.messages, key=lambda m: m.created_at) if c.messages else None
        payloads.append(
            ChatThreadOut(
                id=c.id,
                vendor_id=c.vendor_id,
                vendor_name=vendor.store_name if vendor else "Store",
                vendor_logo_url=vendor.logo_url if vendor else None,
                customer_id=c.customer_id,
                customer_name=customer.full_name if customer else "Customer",
                customer_mobile=customer.mobile_number if customer else None,
                order_id=c.order_id,
                last_message=last.content if last else None,
                last_message_at=last.created_at if last else c.created_at,
                last_sender_id=last.sender_id if last else None,
                message_count=len(c.messages),
            )
        )
    return payloads


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
