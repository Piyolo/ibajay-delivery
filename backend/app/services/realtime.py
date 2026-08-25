import uuid
from collections import defaultdict

from fastapi import WebSocket


class ConnectionManager:
    """
    In-memory WebSocket registry, keyed by order_id and chat_id.

    NOTE: this works for a single backend instance. For horizontal scaling
    (multiple Render instances), back this with Redis Pub/Sub instead so
    broadcasts reach sockets connected to other instances.
    """

    def __init__(self):
        self.order_channels: dict[uuid.UUID, set[WebSocket]] = defaultdict(set)
        self.chat_channels: dict[uuid.UUID, set[WebSocket]] = defaultdict(set)

    # ---- Order tracking channel ----
    async def connect_to_order(self, order_id: uuid.UUID, ws: WebSocket):
        await ws.accept()
        self.order_channels[order_id].add(ws)

    def disconnect_from_order(self, order_id: uuid.UUID, ws: WebSocket):
        self.order_channels[order_id].discard(ws)

    async def broadcast_to_order(self, order_id: uuid.UUID, message: dict):
        dead = []
        for ws in self.order_channels.get(order_id, set()):
            try:
                await ws.send_json(message)
            except Exception:
                dead.append(ws)
        for ws in dead:
            self.order_channels[order_id].discard(ws)

    # ---- Chat channel ----
    async def connect_to_chat(self, chat_id: uuid.UUID, ws: WebSocket):
        await ws.accept()
        self.chat_channels[chat_id].add(ws)

    def disconnect_from_chat(self, chat_id: uuid.UUID, ws: WebSocket):
        self.chat_channels[chat_id].discard(ws)

    async def broadcast_to_chat(self, chat_id: uuid.UUID, message: dict):
        dead = []
        for ws in self.chat_channels.get(chat_id, set()):
            try:
                await ws.send_json(message)
            except Exception:
                dead.append(ws)
        for ws in dead:
            self.chat_channels[chat_id].discard(ws)


connection_manager = ConnectionManager()
