from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Depends
from sqlalchemy.orm import Session
from app.core.websocket import manager
from app.core.database import get_db
from app.models.all_models import User
from jose import jwt, JWTError
from app.core.config import settings
import logging

logger = logging.getLogger("yadvi_ws")
router = APIRouter(prefix="/ws", tags=["WebSockets"])

async def get_current_user_ws(websocket: WebSocket, db: Session):
    token = websocket.query_params.get("token")
    if not token:
        await websocket.close(code=1008)
        return None
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        user_id: str = payload.get("sub")
        if user_id is None:
            await websocket.close(code=1008)
            return None
    except JWTError:
        await websocket.close(code=1008)
        return None

    user = db.query(User).filter(User.id == int(user_id)).first()
    if user is None:
        await websocket.close(code=1008)
        return None
    
    # We could restrict WebSocket to admins here, or let anyone connect and filter by role
    if user.role.name != "administrator":
        # For Phase 15 MVP we let anyone connect, but we might only broadcast to admins if needed.
        # Actually, let's close if not admin, or let them connect for future features
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
