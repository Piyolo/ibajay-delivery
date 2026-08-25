import uuid

from fastapi import APIRouter, Query, WebSocket, WebSocketDisconnect
from sqlalchemy import select

from app.core.db import AsyncSessionLocal
from app.core.security import decode_token
from app.models.order import Order
from app.models.social import Chat, Message
from app.services.realtime import connection_manager

router = APIRouter(tags=["Realtime"])


async def _authenticate_ws(token: str | None) -> str | None:
    if not token:
        return None
    payload = decode_token(token)
    if not payload or payload.get("type") != "access":
        return None
    return payload.get("sub")


@router.websocket("/ws/orders/{order_id}/track")
async def track_order(websocket: WebSocket, order_id: uuid.UUID, token: str = Query(...)):
    """
    Customer connects here to receive live vendor GPS pings + status updates
    for a specific order. Vendor app POSTs GPS updates via the REST endpoint
    below, which broadcasts into this channel.
    """
    user_id = await _authenticate_ws(token)
    if not user_id:
        await websocket.close(code=4401)
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
    """Two-way chat channel. Client sends {"content": "...", "image_url": "..."}."""
    user_id = await _authenticate_ws(token)
    if not user_id:
        await websocket.close(code=4401)
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
