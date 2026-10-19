from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form
import os
import uuid
import logging
from sqlalchemy.orm import Session, joinedload
from typing import List, Optional
from pydantic import BaseModel
from datetime import datetime
from app.core.config import settings
from app.core.database import get_db
from app.core.security import get_current_user, require_role
from app.core.media_storage import (
    get_media_storage,
    validate_image_content,
    generate_safe_filename,
)
from app.models.all_models import Visit, FieldExecutive, ShopOwner, User

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/visits", tags=["Field Visits"])


class VisitOut(BaseModel):
    id: int
    executive_id: int
    executive_name: str
    employee_code: str
    shop_id: int
    shop_name: str
    shop_location: str
    shop_owner_name: Optional[str] = None
    shop_territory: Optional[str] = None
    shop_city: Optional[str] = None
    shop_address: Optional[str] = None
    shop_photo_url_profile: Optional[str] = None
    shop_owner_photo_url: Optional[str] = None
    shop_phone: Optional[str] = None
    purpose: str
    status: str
    visited_at: Optional[datetime]
    photo_url: Optional[str]
    photo_lat: Optional[float] = None
    photo_lng: Optional[float] = None
    notes: Optional[str]
    bags_ordered: Optional[int] = 0
    quantity_booked_kg: Optional[float] = 0.0
    scheduled_date: datetime

    class Config:
        from_attributes = True


class VisitUploadRequest(BaseModel):
    photo_lat: float
    photo_lng: float
    photo_url: str
    notes: Optional[str] = None


def _build_visit_out(v: Visit) -> VisitOut:
    photo_url = v.visit_photo_url
    booked_kg = v.quantity_booked_kg if v.quantity_booked_kg is not None else float(v.bags_ordered or 0)
    return VisitOut(
        id=v.id,
        executive_id=v.executive_id,
        executive_name=v.executive.user.full_name if v.executive and v.executive.user else "Unknown",
        employee_code=v.executive.employee_code if v.executive else "",
        shop_id=v.shop_id,
        shop_name=v.shop.shop_name if v.shop else "Unknown",
        shop_location=v.shop.market_location if v.shop else "",
        shop_owner_name=v.shop.user.full_name if v.shop and v.shop.user else None,
        shop_territory=v.shop.territory if v.shop else None,
        shop_city=v.shop.city if v.shop else None,
        shop_address=v.shop.address if v.shop else None,
        shop_photo_url_profile=v.shop.shop_photo_url if v.shop else None,
        shop_owner_photo_url=v.shop.owner_photo_url if v.shop else None,
        shop_phone=v.shop.user.phone if v.shop and v.shop.user else None,
        purpose=v.purpose,
        status=v.status,
        visited_at=v.visited_at,
        photo_url=photo_url,
        photo_lat=v.photo_lat,
        photo_lng=v.photo_lng,
        notes=v.notes,
        bags_ordered=v.bags_ordered or int(booked_kg),
        quantity_booked_kg=booked_kg,
        scheduled_date=v.scheduled_date,
    )


@router.get("", response_model=List[VisitOut])
def list_visits(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """List visits — field exec sees own, admin sees all."""
    role_name = current_user.role.name if current_user.role else ""
    query = (
        db.query(Visit)
        .options(
            joinedload(Visit.executive).joinedload(FieldExecutive.user),
            joinedload(Visit.shop),
        )
        .order_by(Visit.scheduled_date.desc())
    )
    if role_name == "field_executive":
        exec_ = db.query(FieldExecutive).filter(FieldExecutive.user_id == current_user.id).first()
        if exec_:
            # Auto-generate pending visits for today for all assigned shops
            today_start = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
            assigned_shops = db.query(ShopOwner).filter(ShopOwner.assigned_executive_id == exec_.id).all()
            for shop in assigned_shops:
                existing_visit = db.query(Visit).filter(
                    Visit.executive_id == exec_.id,
                    Visit.shop_id == shop.id,
                    Visit.scheduled_date >= today_start
                ).first()
                if not existing_visit:
                    new_visit = Visit(
                        executive_id=exec_.id,
                        shop_id=shop.id,
                        purpose="Scheduled Visit",
                        status="Pending",
                        scheduled_date=datetime.utcnow()
                    )
                    db.add(new_visit)
            db.commit()

            query = query.filter(Visit.executive_id == exec_.id)
        else:
            return []
    elif role_name not in ["administrator"]:
        return []

    return [_build_visit_out(v) for v in query.all()]


@router.post("/{visit_id}/upload-photo", response_model=VisitOut)
def upload_visit_photo(
    visit_id: int,
    photo_lat: float = Form(...),
    photo_lng: float = Form(...),
    notes: Optional[str] = Form(None),
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["field_executive", "administrator"]))
):
    visit = (
        db.query(Visit)
        .options(
            joinedload(Visit.executive).joinedload(FieldExecutive.user),
            joinedload(Visit.shop),
        )
        .filter(Visit.id == visit_id)
        .first()
    )
    if not visit:
        raise HTTPException(status_code=404, detail="Visit not found")

    # Verify authorization: field executive can only upload for their own assigned visits
    role_name = current_user.role.name if current_user.role else ""
    if role_name == "field_executive":
        if not visit.executive or visit.executive.user_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Not authorized to upload photo for another executive's visit."
            )

    # Validate image content & 10MB size limit
    contents = file.file.read()
    detected_ext, detected_mime = validate_image_content(
        contents,
        max_size_bytes=10 * 1024 * 1024,
        allowed_extensions=["jpg", "jpeg", "png", "webp"]
    )

    # Generate secure server-side filename and persist through media storage abstraction
    safe_filename = generate_safe_filename(prefix=f"visit_{visit.id}", extension=detected_ext)
    storage = get_media_storage()
    saved_url = storage.save(contents, safe_filename, content_type=detected_mime, folder="visits")

    visit.visited_at = datetime.utcnow()
    visit.status = "Visited"
    visit.photo_lat = photo_lat
    visit.photo_lng = photo_lng
    # Store canonical relative path so database remains backend-agnostic
    visit.visit_photo_url = saved_url

    if notes:
        visit.notes = notes

    db.commit()
    db.refresh(visit)
    return _build_visit_out(visit)
