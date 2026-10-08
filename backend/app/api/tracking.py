from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional
from datetime import datetime
import logging
import json

from app.core.database import get_db
from app.core.security import require_role
from app.models.all_models import User, FieldExecutive, FELocation, Role
from app.core.websocket import manager

logger = logging.getLogger("yadvi_tracking")
router = APIRouter(prefix="/tracking", tags=["Live Tracking"])

class LocationUpdateRequest(BaseModel):
    lat: float
    lng: float
    accuracy: Optional[float] = None
    speed: Optional[float] = None

@router.post("/location")
async def update_location(
    payload: LocationUpdateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["field_executive"]))
):
    """Receives physical GPS coordinates and broadcasts them to Admins."""
    exec_profile = db.query(FieldExecutive).filter(FieldExecutive.user_id == current_user.id).first()
    if not exec_profile:
        raise HTTPException(status_code=404, detail="Field executive profile not found")

    # Persist the actual point
    point = FELocation(
        executive_id=exec_profile.id,
        lat=payload.lat,
        lng=payload.lng,
        accuracy=payload.accuracy,
        speed=payload.speed
    )
    db.add(point)

    # Update latest known location on FieldExecutive
    exec_profile.current_lat = payload.lat
    exec_profile.current_lng = payload.lng
    exec_profile.last_location_update = datetime.utcnow()

    db.commit()

    # Real-time WebSocket broadcast to listening Admins
    broadcast_data = {
        "type": "LOCATION_UPDATE",
        "data": {
            "employee_id": exec_profile.id,
            "lat": payload.lat,
            "lng": payload.lng,
            "battery": exec_profile.battery_level,
            "last_update": point.timestamp.isoformat()
        }
    }

    admins = db.query(User).join(Role).filter(Role.name == "administrator").all()
    allowed_user_ids = [admin.id for admin in admins]
    
    # GPS is private to Admin ONLY
    message_str = json.dumps(broadcast_data)
    for u_id in set(allowed_user_ids):
        await manager.send_personal_message(message_str, u_id)

    return {"success": True}
