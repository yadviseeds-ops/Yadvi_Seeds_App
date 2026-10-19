import json
import logging
import time
import secrets
from typing import List, Dict, Any, Optional, Tuple
from fastapi import WebSocket

logger = logging.getLogger("yadvi_websocket")

class ConnectionManager:
    def __init__(self):
        # active_connections maps user_id to a list of active websockets
        self.active_connections: Dict[int, List[WebSocket]] = {}

    async def connect(self, websocket: WebSocket, user_id: int):
        await websocket.accept()
        if user_id not in self.active_connections:
            self.active_connections[user_id] = []
        self.active_connections[user_id].append(websocket)
        logger.info(f"User {user_id} connected to WebSocket. Total connections for user: {len(self.active_connections[user_id])}")

    def disconnect(self, websocket: WebSocket, user_id: int):
        if user_id in self.active_connections:
            if websocket in self.active_connections[user_id]:
                self.active_connections[user_id].remove(websocket)
            if len(self.active_connections[user_id]) == 0:
                del self.active_connections[user_id]
        logger.info(f"User {user_id} disconnected from WebSocket.")

    async def send_personal_message(self, message: str, user_id: int):
        if user_id in self.active_connections:
            for connection in self.active_connections[user_id]:
                await connection.send_text(message)

    async def broadcast(self, message: str):
        # Broadcast to all connected users
        for user_id, connections in self.active_connections.items():
            for connection in connections:
                try:
                    await connection.send_text(message)
                except Exception as e:
                    logger.error(f"Error broadcasting to {user_id}: {e}")

    async def broadcast_location_update(self, employee_id: int, lat: float, lng: float, battery: int, last_update: str):
        payload = {
            "type": "LOCATION_UPDATE",
            "data": {
                "employee_id": employee_id,
                "lat": lat,
                "lng": lng,
                "battery": battery,
                "last_update": last_update
            }
        }
        await self.broadcast(json.dumps(payload))

manager = ConnectionManager()


class WebSocketTicketManager:
    """
    Manages short-lived (default 60s), single-use connection tickets
    for WebSocket authentication to prevent bearer JWTs from leaking in URL logs.
    """
    def __init__(self, ttl_seconds: int = 60):
        self.ttl_seconds = ttl_seconds
        # Maps ticket string to (user_id, expires_at)
        self._tickets: Dict[str, Tuple[int, float]] = {}

    def issue_ticket(self, user_id: int) -> str:
        self._purge_expired()
        ticket = secrets.token_urlsafe(32)
        expires_at = time.time() + self.ttl_seconds
        self._tickets[ticket] = (user_id, expires_at)
        return ticket

    def consume_ticket(self, ticket: str) -> Optional[int]:
        self._purge_expired()
        if not ticket or not isinstance(ticket, str):
            return None
        record = self._tickets.pop(ticket.strip(), None)
        if not record:
            return None
        user_id, expires_at = record
        if time.time() > expires_at:
            return None
        return user_id

    def _purge_expired(self) -> None:
        now = time.time()
        expired_keys = [k for k, (_, exp) in self._tickets.items() if now > exp]
        for k in expired_keys:
            self._tickets.pop(k, None)

    def reset_for_testing(self) -> None:
        self._tickets.clear()


ticket_manager = WebSocketTicketManager()
