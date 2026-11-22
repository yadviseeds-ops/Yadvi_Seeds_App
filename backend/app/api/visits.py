from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form
import os
import uuid
import logging
from sqlalchemy.orm import Session, joinedload
from typing import List, Optional
from pydantic import BaseModel
from datetime import datetime, timedelta
from app.core.config import settings
from app.core.database import get_db
from app.core.security import get_current_user, require_role
from app.core.media_storage import (
    get_media_storage,
    validate_image_content,
    generate_safe_filename,
)
from app.models.all_models import Visit, FieldExecutive, ShopOwner, User, Attendance

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/visits", tags=["Field Visits"])

IST_OFFSET = timedelta(hours=5, minutes=30)

def get_ist_reporting_window_utc(dt_utc: Optional[datetime] = None) -> tuple[datetime, datetime]:
    """Return UTC start and end timestamps representing current Indian Standard Time reporting day."""
    if dt_utc is None:
        dt_utc = datetime.utcnow()
    dt_ist = dt_utc + IST_OFFSET
    ist_start = dt_ist.replace(hour=0, minute=0, second=0, microsecond=0)
    ist_end = ist_start + timedelta(days=1) - timedelta(microseconds=1)
    return ist_start - IST_OFFSET, ist_end - IST_OFFSET


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


class VisitCreateRequest(BaseModel):
    shop_id: int
    purpose: Optional[str] = "Scheduled Visit"
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
@router.get("/", response_model=List[VisitOut], include_in_schema=False)
def list_visits(
    executive_id: Optional[int] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """List visits — field exec sees own, admin sees all (with optional executive_id filter)."""
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
            # Auto-generate pending visits for today for all active assigned shops
            today_start, _ = get_ist_reporting_window_utc()
            assigned_shops = db.query(ShopOwner).filter(
                ShopOwner.assigned_executive_id == exec_.id,
                ShopOwner.status == "Active"
            ).all()
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
    elif role_name in ["administrator"]:
        if executive_id is not None:
            query = query.filter(Visit.executive_id == executive_id)
    else:
        return []

    return [_build_visit_out(v) for v in query.all()]


@router.post("", response_model=VisitOut)
@router.post("/", response_model=VisitOut, include_in_schema=False)
def create_planned_visit(
    payload: VisitCreateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["field_executive", "administrator"]))
):
    """Create a planned visit for today for the Field Executive.

    Validates that the shop exists, prevents duplicate visits for the same shop
    and executive on the same day, and preserves existing shop assignments.
    """
    shop = db.query(ShopOwner).filter(ShopOwner.id == payload.shop_id).first()
    if not shop:
        raise HTTPException(status_code=404, detail="Selected shop does not exist")
    if shop.status != "Active":
        raise HTTPException(
            status_code=400,
            detail="Cannot plan visit: selected shop is inactive or unavailable"
        )

    role_name = current_user.role.name if current_user.role else ""
    if role_name == "field_executive":
        exec_ = db.query(FieldExecutive).filter(FieldExecutive.user_id == current_user.id).first()
        if not exec_:
            raise HTTPException(status_code=404, detail="Field executive profile not found")
        exec_id = exec_.id
    elif role_name == "administrator":
        exec_ = db.query(FieldExecutive).filter(FieldExecutive.user_id == current_user.id).first()
        if exec_:
            exec_id = exec_.id
        elif shop.assigned_executive_id:
            exec_id = shop.assigned_executive_id
        else:
            first_exec = db.query(FieldExecutive).first()
            if not first_exec:
                raise HTTPException(status_code=400, detail="No field executive available for visit assignment")
            exec_id = first_exec.id
    else:
        raise HTTPException(status_code=403, detail="Not authorized to create visit plans")

    # Duplicate prevention: Check if visit already exists for today's IST reporting day
    today_start, today_end = get_ist_reporting_window_utc()
    existing = db.query(Visit).filter(
        Visit.executive_id == exec_id,
        Visit.shop_id == payload.shop_id,
        Visit.scheduled_date >= today_start,
        Visit.scheduled_date <= today_end
    ).first()
    if existing:
        raise HTTPException(
            status_code=400,
            detail=f"Shop '{shop.shop_name}' is already in today's visit plan."
        )

    clean_purpose = (payload.purpose or "Scheduled Visit").strip() or "Scheduled Visit"
    clean_notes = payload.notes.strip() if payload.notes and payload.notes.strip() else None

    new_visit = Visit(
        executive_id=exec_id,
        shop_id=payload.shop_id,
        purpose=clean_purpose,
        status="Pending",
        scheduled_date=datetime.utcnow(),
        notes=clean_notes
    )
    db.add(new_visit)
    db.commit()
    db.refresh(new_visit)

    loaded_visit = (
        db.query(Visit)
        .options(
            joinedload(Visit.executive).joinedload(FieldExecutive.user),
            joinedload(Visit.shop).joinedload(ShopOwner.user),
        )
        .filter(Visit.id == new_visit.id)
        .first()
    )
    return _build_visit_out(loaded_visit)


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
    try:
        saved_url = storage.save(contents, safe_filename, content_type=detected_mime, folder="visits")
    except Exception as exc:
        logger.error(f"Failed to persist visit photo for visit {visit.id}: {exc}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to upload visit photograph: {str(exc)}"
        )

    visit.visited_at = datetime.utcnow()
    visit.status = "Visited"
    visit.photo_lat = photo_lat
    visit.photo_lng = photo_lng
    # Store canonical relative path so database remains backend-agnostic
    visit.visit_photo_url = saved_url

    if notes:
        visit.notes = notes

    # Automatically mark attendance for the Field Executive for today (Asia/Kolkata)
    if visit.executive_id:
        try:
            ist_start_utc, ist_end_utc = get_ist_reporting_window_utc()
            existing_att = (
                db.query(Attendance)
                .filter(
                    Attendance.executive_id == visit.executive_id,
                    Attendance.date >= ist_start_utc,
                    Attendance.date <= ist_end_utc,
                )
                .first()
            )

            now_utc = datetime.utcnow()
            if not existing_att:
                shop_name = visit.shop.shop_name if visit.shop else "Field"
                new_att = Attendance(
                    executive_id=visit.executive_id,
                    date=ist_start_utc,
                    check_in_time=now_utc,
                    status="Present",
                    check_in_location=f"Visit #{visit.id} - {shop_name}",
                )
                db.add(new_att)
            else:
                existing_att.status = "Present"
                if not existing_att.check_in_time:
                    existing_att.check_in_time = now_utc

            if visit.executive:
                visit.executive.attendance_status = "Present"
        except Exception as att_err:
            logger.warning(f"Could not update attendance on photo upload: {att_err}")

    db.commit()
    db.refresh(visit)
    return _build_visit_out(visit)
