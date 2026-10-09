from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session, joinedload
from typing import List, Optional
from pydantic import BaseModel
from datetime import datetime, date
from app.core.database import get_db
from app.core.security import get_current_user, require_role
from app.models.all_models import EODReport, FieldExecutive, User

router = APIRouter(prefix="/eod", tags=["EOD Reports"])

class EODReportIn(BaseModel):
    completed_visits: int
    pending_visits: int
    total_bags_ordered: int
    notes: Optional[str] = None

class EODReportOut(BaseModel):
    id: int
    executive_id: int
    executive_name: str
    report_date: datetime
    completed_visits: int
    pending_visits: int
    total_bags_ordered: int
    notes: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True

@router.post("", response_model=EODReportOut)
def submit_eod_report(
    report: EODReportIn,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["field_executive"]))
):
    """Field Executive submits EOD report."""
    executive = db.query(FieldExecutive).filter(FieldExecutive.user_id == current_user.id).first()
    if not executive:
        raise HTTPException(status_code=404, detail="Executive profile not found")

    new_report = EODReport(
        executive_id=executive.id,
        completed_visits=report.completed_visits,
        pending_visits=report.pending_visits,
        total_bags_ordered=report.total_bags_ordered,
        notes=report.notes
    )
    db.add(new_report)
    db.commit()
    db.refresh(new_report)

    return EODReportOut(
        id=new_report.id,
        executive_id=new_report.executive_id,
        executive_name=current_user.full_name,
        report_date=new_report.report_date,
        completed_visits=new_report.completed_visits,
        pending_visits=new_report.pending_visits,
        total_bags_ordered=new_report.total_bags_ordered,
        notes=new_report.notes,
        created_at=new_report.created_at
    )

@router.get("", response_model=List[EODReportOut])
def get_eod_reports(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["administrator"]))
):
    """Admin retrieves EOD reports."""
    reports = (
        db.query(EODReport)
        .options(joinedload(EODReport.executive).joinedload(FieldExecutive.user))
        .order_by(EODReport.created_at.desc())
        .all()
    )
    result = []
    for r in reports:
        result.append(EODReportOut(
            id=r.id,
            executive_id=r.executive_id,
            executive_name=r.executive.user.full_name if r.executive and r.executive.user else "Unknown",
            report_date=r.report_date,
            completed_visits=r.completed_visits,
            pending_visits=r.pending_visits,
            total_bags_ordered=r.total_bags_ordered,
            notes=r.notes,
            created_at=r.created_at
        ))
    return result
