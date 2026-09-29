import json
import logging
from typing import List, Dict, Any
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
