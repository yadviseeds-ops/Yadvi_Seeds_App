from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session, joinedload
from typing import List, Optional
from pydantic import BaseModel
from datetime import datetime, date, timedelta
from app.core.database import get_db
from app.core.security import get_current_user, require_role
from app.models.all_models import Attendance, FieldExecutive, User

router = APIRouter(prefix="/attendance", tags=["Attendance"])


class AttendanceOut(BaseModel):
    id: int
    executive_id: int
    employee_code: str
    full_name: str
    phone: Optional[str] = None
    date: datetime
    check_in_time: Optional[datetime] = None
    check_out_time: Optional[datetime] = None
    status: str
    distance_covered_km: float = 0.0
    check_in_location: Optional[str] = None

    class Config:
        from_attributes = True


class CheckInRequest(BaseModel):
    location: Optional[str] = "Office / Field"


class CheckOutRequest(BaseModel):
    distance_covered_km: Optional[float] = 0.0


@router.get("", response_model=List[AttendanceOut])
def list_attendance(
    date: Optional[str] = Query(None, description="Target date in YYYY-MM-DD format"),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["administrator"]))
):
    """List attendance records with FE roster calculation for selected date — Admin only."""
    IST_OFFSET = timedelta(hours=5, minutes=30)

    if date and date.strip():
        try:
            target_date = datetime.strptime(date.strip(), "%Y-%m-%d").date()
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid date format. Expected YYYY-MM-DD")
    else:
        # Default to today in Asia/Kolkata
        target_date = (datetime.utcnow() + IST_OFFSET).date()

    # UTC window corresponding to full day in Asia/Kolkata
    dt_ist_start = datetime(target_date.year, target_date.month, target_date.day)
    ist_start_utc = dt_ist_start - IST_OFFSET
    ist_end_utc = ist_start_utc + timedelta(days=1) - timedelta(microseconds=1)

    # Fetch all active Field Executives
    executives = (
        db.query(FieldExecutive)
        .join(User, FieldExecutive.user_id == User.id)
        .options(joinedload(FieldExecutive.user))
        .filter(User.is_active == True)
        .order_by(User.full_name)
        .all()
    )

    # Fetch attendance records for target date window
    records = (
        db.query(Attendance)
        .options(joinedload(Attendance.executive).joinedload(FieldExecutive.user))
        .filter(Attendance.date >= ist_start_utc, Attendance.date <= ist_end_utc)
        .all()
    )

    records_by_exec = {rec.executive_id: rec for rec in records}

    result = []
    for ex in executives:
        rec = records_by_exec.get(ex.id)
        full_name = ex.user.full_name if ex.user and ex.user.full_name else "Unknown"
        phone = ex.user.phone if ex.user else None

        if rec and rec.status.lower() == "present":
            result.append(AttendanceOut(
                id=rec.id,
                executive_id=ex.id,
                employee_code=ex.employee_code or "",
                full_name=full_name,
                phone=phone,
                date=rec.date,
                check_in_time=rec.check_in_time,
                check_out_time=rec.check_out_time,
                status="Present",
                distance_covered_km=rec.distance_covered_km or 0.0,
                check_in_location=rec.check_in_location,
            ))
        else:
            result.append(AttendanceOut(
                id=rec.id if rec else 0,
                executive_id=ex.id,
                employee_code=ex.employee_code or "",
                full_name=full_name,
                phone=phone,
                date=dt_ist_start,
                check_in_time=rec.check_in_time if rec else None,
                check_out_time=rec.check_out_time if rec else None,
                status="Absent",
                distance_covered_km=rec.distance_covered_km if rec else 0.0,
                check_in_location=rec.check_in_location if rec else None,
            ))

    return result


@router.post("/checkin")
def check_in(
    payload: CheckInRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["field_executive"]))
):
    """Mark attendance check-in for field executive."""
    exec_ = db.query(FieldExecutive).filter(FieldExecutive.user_id == current_user.id).first()
    if not exec_:
        raise HTTPException(status_code=404, detail="Field executive profile not found")

    today = datetime.utcnow().date()
    existing = db.query(Attendance).filter(
        Attendance.executive_id == exec_.id,
        Attendance.date >= datetime(today.year, today.month, today.day)
    ).first()

    if existing and existing.check_in_time:
        raise HTTPException(status_code=400, detail="Already checked in today")

    if not existing:
        record = Attendance(
            executive_id=exec_.id,
            date=datetime.utcnow(),
            check_in_time=datetime.utcnow(),
            status="Present",
            check_in_location=payload.location,
        )
        db.add(record)
    else:
        existing.check_in_time = datetime.utcnow()
        existing.check_in_location = payload.location
        existing.status = "Present"

    exec_.attendance_status = "Present"
    db.commit()
    return {"success": True, "message": "Checked in successfully", "time": datetime.utcnow().isoformat()}


@router.post("/checkout")
def check_out(
    payload: CheckOutRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["field_executive"]))
):
    """Mark attendance check-out for field executive."""
    exec_ = db.query(FieldExecutive).filter(FieldExecutive.user_id == current_user.id).first()
    if not exec_:
        raise HTTPException(status_code=404, detail="Field executive profile not found")

    today = datetime.utcnow().date()
    record = db.query(Attendance).filter(
        Attendance.executive_id == exec_.id,
        Attendance.date >= datetime(today.year, today.month, today.day)
    ).first()

    if not record or not record.check_in_time:
        raise HTTPException(status_code=400, detail="Not checked in yet today")

    if record.check_out_time:
        raise HTTPException(status_code=400, detail="Already checked out today")

    record.check_out_time = datetime.utcnow()
    record.distance_covered_km = payload.distance_covered_km or exec_.distance_covered_km
    exec_.attendance_status = "Checked Out"
    db.commit()
    return {"success": True, "message": "Checked out successfully", "time": datetime.utcnow().isoformat()}
