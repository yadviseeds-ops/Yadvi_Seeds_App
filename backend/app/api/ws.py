from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Depends
from sqlalchemy.orm import Session
from app.core.websocket import manager, ticket_manager
from app.core.database import get_db
from app.models.all_models import User
from jose import jwt, JWTError
from app.core.config import settings
import logging

logger = logging.getLogger("yadvi_ws")
router = APIRouter(prefix="/ws", tags=["WebSockets"])

async def get_current_user_ws(websocket: WebSocket, db: Session):
    # 1. Preferred secure method: Single-use short-lived connection ticket
    ticket = websocket.query_params.get("ticket")
    if ticket:
        user_id = ticket_manager.consume_ticket(ticket)
        if user_id is None:
            logger.warning("WebSocket connection rejected: invalid or expired connection ticket.")
            await websocket.close(code=1008)
            return None
        user = db.query(User).filter(User.id == int(user_id)).first()
        if user is None:
            await websocket.close(code=1008)
            return None
        return user

    # 2. Deprecated fallback: Query-param JWT token (logged with warning)
    token = websocket.query_params.get("token")
    if not token:
        await websocket.close(code=1008)
        return None

    logger.warning("WebSocket authenticated via deprecated query param ?token=. Migrate client to ?ticket= via POST /api/v1/auth/ws-ticket.")
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        user_id_val = payload.get("sub")
        if user_id_val is None:
            await websocket.close(code=1008)
            return None
        user_id = int(user_id_val)
    except (JWTError, ValueError):
        await websocket.close(code=1008)
        return None

    user = db.query(User).filter(User.id == user_id).first()
    if user is None:
        await websocket.close(code=1008)
        return None

    # Role checks or restrictions can be enforced here if needed
    if user.role and user.role.name != "administrator":
        pass

    return user


@router.websocket("/live-tracking")
async def websocket_endpoint(websocket: WebSocket, db: Session = Depends(get_db)):
    user = await get_current_user_ws(websocket, db)
    if not user:
        return

    await manager.connect(websocket, user.id)
    try:
        while True:
            data = await websocket.receive_text()
            # Handle incoming WS messages if any
    except WebSocketDisconnect:
        manager.disconnect(websocket, user.id)
