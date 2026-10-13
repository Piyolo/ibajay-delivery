import uuid

from fastapi import APIRouter, Query, WebSocket, WebSocketDisconnect
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.db import AsyncSessionLocal
from app.core.security import decode_token
from app.models.order import Order
from app.models.social import Chat, Message
from app.models.user import User
from app.models.vendor import Vendor
from app.services.realtime import connection_manager

router = APIRouter(tags=["Realtime"])

# Close codes follow the existing style: 4401 when the connection is denied.
UNAUTHORIZED_CLOSE_CODE = 4401
NOT_FOUND_CLOSE_CODE = 4404


async def _authenticate_ws(token: str | None) -> dict | None:
    """Validate the access token, returning its claims (incl. `sub` + `tv`).

    Returns None when the token is missing or not a valid access token.
    """
    if not token:
        return None
    payload = decode_token(token)
    if not payload or payload.get("type") != "access":
        return None
    if not isinstance(payload.get("sub"), str) or not payload["sub"]:
        return None
    return payload


async def _load_authorized_user(db: AsyncSession, payload: dict) -> User | None:
    """Resolve the connecting user, enforcing revocation too.

    Returns None when the user no longer exists, is inactive, or the token's
    `tv` claim doesn't match user.token_version (password changed / pre-revocation
    deploy token) — mirroring deps.get_current_user.
    """
    try:
        user_uuid = uuid.UUID(payload.get("sub"))
    except (ValueError, TypeError):
        return None
    result = await db.execute(select(User).where(User.id == user_uuid))
    user = result.scalar_one_or_none()
    if not user or not user.is_active:
        return None
    if payload.get("tv") != user.token_version:
        return None
    return user


@router.websocket("/ws/orders/{order_id}/track")
async def track_order(websocket: WebSocket, order_id: uuid.UUID, token: str = Query(...)):
    """
    Customer connects here to receive live vendor GPS pings + status updates
    for a specific order. Vendor app POSTs GPS updates via the REST endpoint
    below, which broadcasts into this channel.

    Only the order's customer and the owner of the order's vendor may
    subscribe; anyone else is closed with 4401.
    """
    payload = await _authenticate_ws(token)
    if not payload:
        await websocket.close(code=UNAUTHORIZED_CLOSE_CODE)
        return

    async with AsyncSessionLocal() as db:
        user = await _load_authorized_user(db, payload)
        if not user:
            await websocket.close(code=UNAUTHORIZED_CLOSE_CODE)
            return

        order_result = await db.execute(select(Order).where(Order.id == order_id))
        order = order_result.scalar_one_or_none()
        if not order:
            await websocket.close(code=NOT_FOUND_CLOSE_CODE)
            return

        if order.customer_id != user.id:
            vendor_result = await db.execute(select(Vendor).where(Vendor.id == order.vendor_id))
            vendor = vendor_result.scalar_one_or_none()
            if not vendor or vendor.owner_id != user.id:
                await websocket.close(code=UNAUTHORIZED_CLOSE_CODE)
                return

    await connection_manager.connect_to_order(order_id, websocket)
    try:
        while True:
            # Customers don't send data on this channel; just keep the socket alive.
            await websocket.receive_text()
    except WebSocketDisconnect:
        connection_manager.disconnect_from_order(order_id, websocket)


@router.websocket("/ws/chats/{chat_id}")
async def chat_channel(websocket: WebSocket, chat_id: uuid.UUID, token: str = Query(...)):
    """Two-way chat channel. Client sends {"content": "...", "image_url": "..."}.

    Same membership rule as GET /chats/{chat_id}/messages: only the thread's
    customer or the owner of its vendor may join (the pre-existing gap let
    any authenticated user listen in on and post to any thread).
    """
    payload = await _authenticate_ws(token)
    if not payload:
        await websocket.close(code=UNAUTHORIZED_CLOSE_CODE)
        return
    user_id = payload["sub"]

    async with AsyncSessionLocal() as db:
        user = await _load_authorized_user(db, payload)
        if not user:
            await websocket.close(code=UNAUTHORIZED_CLOSE_CODE)
            return

        chat_result = await db.execute(select(Chat).where(Chat.id == chat_id))
        chat = chat_result.scalar_one_or_none()
        if not chat:
            await websocket.close(code=NOT_FOUND_CLOSE_CODE)
            return

        vendor_result = await db.execute(select(Vendor).where(Vendor.id == chat.vendor_id))
        vendor = vendor_result.scalar_one_or_none()
        if chat.customer_id != user.id and (not vendor or vendor.owner_id != user.id):
            await websocket.close(code=UNAUTHORIZED_CLOSE_CODE)
            return

    await connection_manager.connect_to_chat(chat_id, websocket)
    try:
        while True:
            data = await websocket.receive_json()
            async with AsyncSessionLocal() as db:
                chat_result = await db.execute(select(Chat).where(Chat.id == chat_id))
                chat = chat_result.scalar_one_or_none()
                if not chat:
                    continue

                message = Message(
                    chat_id=chat_id,
                    sender_id=uuid.UUID(user_id),
                    content=data.get("content"),
                    image_url=data.get("image_url"),
                )
                db.add(message)
                await db.commit()
                await db.refresh(message)

            await connection_manager.broadcast_to_chat(
                chat_id,
                {
                    "type": "message",
                    "chat_id": str(chat_id),
                    "sender_id": user_id,
                    "content": message.content,
                    "image_url": message.image_url,
                    "created_at": message.created_at.isoformat(),
                },
            )
    except WebSocketDisconnect:
        connection_manager.disconnect_from_chat(chat_id, websocket)
