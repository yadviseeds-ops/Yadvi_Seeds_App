from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import or_, and_
from sqlalchemy.orm import Session, joinedload
from typing import List, Optional
from pydantic import BaseModel
from datetime import datetime, date, timedelta
from app.core.database import get_db
from app.core.security import get_current_user, require_role
from app.models.all_models import EODReport, FieldExecutive, User, Visit

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
@router.post("/", response_model=EODReportOut, include_in_schema=False)
def submit_eod_report(
    report: EODReportIn,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["field_executive"]))
):
    """Field Executive submits EOD report with authoritative visit validation."""
    executive = db.query(FieldExecutive).filter(FieldExecutive.user_id == current_user.id).first()
    if not executive:
        raise HTTPException(status_code=404, detail="Executive profile not found")

    # Determine IST reporting window in UTC (UTC + 5:30)
    ist_offset = timedelta(hours=5, minutes=30)
    now_utc = datetime.utcnow()
    now_ist = now_utc + ist_offset
    ist_day_start = now_ist.replace(hour=0, minute=0, second=0, microsecond=0)
    ist_day_end = ist_day_start + timedelta(days=1) - timedelta(microseconds=1)
    utc_start = ist_day_start - ist_offset
    utc_end = ist_day_end - ist_offset

    # Query all authoritative visits for this executive for the current reporting day
    today_visits = (
        db.query(Visit)
        .filter(
            Visit.executive_id == executive.id,
            or_(
                and_(Visit.visited_at >= utc_start, Visit.visited_at <= utc_end),
                and_(Visit.scheduled_date >= utc_start, Visit.scheduled_date <= utc_end),
            )
        )
        .all()
    )

    # Calculate authoritative counts, deduplicated by visit ID
    seen_ids = set()
    authoritative_completed = 0
    authoritative_pending = 0
    authoritative_bags = 0

    for v in today_visits:
        if v.id in seen_ids:
            continue
        seen_ids.add(v.id)

        st = (v.status or "").strip().lower()
        if st in ["visited", "completed"] or v.visited_at is not None:
            authoritative_completed += 1
        elif st == "pending":
            authoritative_pending += 1
        authoritative_bags += int(v.bags_ordered or 0)

    # If authoritative visits exist in the database for today, they take precedence
    # over any stale or zero counts submitted by the client
    if today_visits:
        final_completed = authoritative_completed
        final_pending = authoritative_pending
        final_bags = max(report.total_bags_ordered, authoritative_bags)
    else:
        final_completed = report.completed_visits
        final_pending = report.pending_visits
        final_bags = report.total_bags_ordered

    new_report = EODReport(
        executive_id=executive.id,
        completed_visits=final_completed,
        pending_visits=final_pending,
        total_bags_ordered=final_bags,
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
@router.get("/", response_model=List[EODReportOut], include_in_schema=False)
def get_eod_reports(
    date: Optional[str] = Query(None, description="Filter reports by date (YYYY-MM-DD)"),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["administrator"]))
):
    """Admin retrieves EOD reports with optional date-wise filtering."""
    query = (
        db.query(EODReport)
        .options(joinedload(EODReport.executive).joinedload(FieldExecutive.user))
        .order_by(EODReport.created_at.desc())
    )

    if date and date.strip():
        try:
            target_date = datetime.strptime(date.strip(), "%Y-%m-%d").date()
            # Asia/Kolkata (IST = UTC+5:30) business day boundaries
            ist_offset = timedelta(hours=5, minutes=30)
            ist_day_start = datetime.combine(target_date, datetime.min.time())
            ist_next_start = ist_day_start + timedelta(days=1)
            utc_start = ist_day_start - ist_offset
            utc_end = ist_next_start - ist_offset

            # Match UTC timestamps within the IST business day window [utc_start, utc_end),
            # while also maintaining compatibility with naive local timestamps [ist_day_start, ist_next_start)
            utc_window = or_(
                and_(EODReport.report_date >= utc_start, EODReport.report_date < utc_end),
                and_(EODReport.created_at >= utc_start, EODReport.created_at < utc_end)
            )
            local_window = or_(
                and_(EODReport.report_date >= ist_day_start, EODReport.report_date < ist_next_start),
                and_(EODReport.created_at >= ist_day_start, EODReport.created_at < ist_next_start)
            )
            query = query.filter(or_(utc_window, local_window))
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid date format. Expected YYYY-MM-DD")

    reports = query.all()
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
