from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
import os
import uuid
from sqlalchemy.orm import Session, joinedload
from typing import List, Optional
from pydantic import BaseModel
from datetime import datetime
from app.core.database import get_db
from app.core.security import get_current_user, require_role
from app.models.all_models import Visit, FieldExecutive, ShopOwner, User

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
    bags_ordered: int
    scheduled_date: datetime

    class Config:
        from_attributes = True


class VisitUploadRequest(BaseModel):
    photo_lat: float
    photo_lng: float
    photo_url: str
    notes: Optional[str] = None


def _build_visit_out(v: Visit) -> VisitOut:
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
        photo_url=v.visit_photo_url,
        photo_lat=v.photo_lat,
        photo_lng=v.photo_lng,
        notes=v.notes,
        bags_ordered=v.bags_ordered,
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

    # Ensure the visits directory exists
    public_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(__file__)))), "public", "visits")
    os.makedirs(public_dir, exist_ok=True)

    # Save file
    file_ext = os.path.splitext(file.filename)[1] if file.filename else ".jpg"
    unique_filename = f"visit_{visit.id}_{uuid.uuid4().hex}{file_ext}"
    file_path = os.path.join(public_dir, unique_filename)

    with open(file_path, "wb") as f:
        f.write(file.file.read())

    visit.visited_at = datetime.utcnow()
    visit.status = "Visited"
    visit.photo_lat = photo_lat
    visit.photo_lng = photo_lng
    # Store relative path so frontend can construct the full URL, or absolute path if mounted
    visit.visit_photo_url = f"/public/visits/{unique_filename}"
    
    if notes:
        visit.notes = notes

    db.commit()
    db.refresh(visit)
    return _build_visit_out(visit)
