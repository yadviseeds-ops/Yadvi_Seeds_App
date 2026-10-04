from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional
from datetime import datetime
import logging

from app.core.database import get_db
from app.core.security import require_role
from app.models.all_models import User, FieldExecutive, Shipment, TrackingSession, LocationPoint
from app.core.websocket import manager

logger = logging.getLogger("yadvi_tracking")
router = APIRouter(prefix="/tracking", tags=["Live Tracking"])

class StartTripRequest(BaseModel):
    shipment_id: int

class EndTripRequest(BaseModel):
    session_id: int

class LocationUpdateRequest(BaseModel):
    session_id: int
    lat: float
    lng: float
    accuracy: Optional[float] = None
    speed: Optional[float] = None

@router.post("/start")
def start_tracking_session(
    payload: StartTripRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["field_executive"]))
):
    """Starts a real GPS tracking trip for a specific shipment."""
    exec_profile = db.query(FieldExecutive).filter(FieldExecutive.user_id == current_user.id).first()
    if not exec_profile:
        raise HTTPException(status_code=404, detail="Field executive profile not found")

    shipment = db.query(Shipment).filter(Shipment.id == payload.shipment_id).first()
    if not shipment:
        raise HTTPException(status_code=404, detail="Shipment not found")

    # Check if there is already an active session for this shipment
    existing_session = db.query(TrackingSession).filter(
        TrackingSession.shipment_id == shipment.id,
        TrackingSession.status == "Active"
    ).first()

    if existing_session:
        return {"success": True, "session_id": existing_session.id, "message": "Session already active"}

    # Create new tracking session
    session = TrackingSession(
        shipment_id=shipment.id,
        executive_id=exec_profile.id,
        status="Active"
    )
    db.add(session)
    db.commit()
    db.refresh(session)

    # Trigger Firebase push notification to Shop Owner here (omitted for brevity, handled by notifications.py)

    return {"success": True, "session_id": session.id, "message": "Tracking started"}

@router.post("/stop")
async def stop_tracking_session(
    payload: EndTripRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["field_executive"]))
):
    """Stops an active GPS tracking trip."""
    session = db.query(TrackingSession).filter(TrackingSession.id == payload.session_id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    if session.executive.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to stop this session")

    session.status = "Completed"
    session.end_time = datetime.utcnow()
    db.commit()

    # Broadcast TRACKING_ENDED
    broadcast_data = {
        "type": "TRACKING_ENDED",
        "data": {
            "employee_id": session.executive.id,
            "shipment_id": session.shipment_id,
            "lr_number": session.shipment.lr_number,
            "last_update": session.end_time.isoformat()
        }
    }

    from app.models.all_models import Role
    import json

    # 1. Get Admins
    admins = db.query(User).join(Role).filter(Role.name == "administrator").all()
    allowed_user_ids = [admin.id for admin in admins]

    # 2. Get Shop Owner
    order = session.shipment.order
    if order and order.shop and order.shop.user_id:
        allowed_user_ids.append(order.shop.user_id)

    message_str = json.dumps(broadcast_data)
    for u_id in set(allowed_user_ids):
        await manager.send_personal_message(message_str, u_id)

    return {"success": True, "message": "Tracking stopped"}

@router.post("/location")
async def update_location(
    payload: LocationUpdateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["field_executive"]))
):
    """Receives physical GPS coordinates and broadcasts them via WebSocket."""
    session = db.query(TrackingSession).filter(TrackingSession.id == payload.session_id).first()
    if not session or session.status != "Active":
        raise HTTPException(status_code=400, detail="Invalid or inactive tracking session")

    if session.executive.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized")

    # Persist the actual point
    point = LocationPoint(
        session_id=session.id,
        lat=payload.lat,
        lng=payload.lng,
        accuracy=payload.accuracy,
        speed=payload.speed
    )
    db.add(point)

    # Update latest known location on FieldExecutive and Shipment
    session.executive.current_lat = payload.lat
    session.executive.current_lng = payload.lng
    session.executive.last_location_update = datetime.utcnow()

    db.commit()

    # Real-time WebSocket broadcast to listening clients (Shop Owners, Admins)
    broadcast_data = {
        "type": "LOCATION_UPDATE",
        "data": {
            "employee_id": session.executive.id,
            "shipment_id": session.shipment_id,
            "lr_number": session.shipment.lr_number,
            "lat": payload.lat,
            "lng": payload.lng,
            "battery": session.executive.battery_level,
            "last_update": point.timestamp.isoformat()
        }
    }

    from app.models.all_models import Role
    import json

    # 1. Get Admins
    admins = db.query(User).join(Role).filter(Role.name == "administrator").all()
    allowed_user_ids = [admin.id for admin in admins]

    # 2. Get Shop Owner
    order = session.shipment.order
    if order and order.shop and order.shop.user_id:
        allowed_user_ids.append(order.shop.user_id)

    message_str = json.dumps(broadcast_data)
    for u_id in set(allowed_user_ids):
        await manager.send_personal_message(message_str, u_id)

    return {"success": True}
