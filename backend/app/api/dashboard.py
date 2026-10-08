from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import List
from app.core.database import get_db
from app.core.security import require_role
from app.models.all_models import (
    User, Order, Product, ShopOwner, FieldExecutive, Attendance, Visit, Shipment
)

router = APIRouter(prefix="/dashboard", tags=["Dashboard & KPIs"])


class KPICard(BaseModel):
    label: str
    value: str
    sub: str
    trend: str  # "up" | "down" | "neutral"


class DashboardData(BaseModel):
    kpis: List[KPICard]
    total_orders: int
    pending_orders: int
    dispatched_orders: int
    delivered_orders: int
    total_products: int
    total_shops: int
    total_executives: int
    present_today: int
    total_visits_today: int
    completed_visits_today: int


@router.get("/admin", response_model=DashboardData)
def get_admin_dashboard(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["administrator"]))
):
    """Admin dashboard KPIs."""
    total_orders = db.query(Order).count()
    pending_orders = db.query(Order).filter(Order.status.in_(["New", "Confirmed", "Processing"])).count()
    dispatched_orders = db.query(Order).filter(Order.status.in_(["Dispatched", "In Transit"])).count()
    delivered_orders = db.query(Order).filter(Order.status == "Delivered").count()
    total_products = db.query(Product).count()
    total_shops = db.query(ShopOwner).count()
    total_executives = db.query(FieldExecutive).count()

    from datetime import datetime, date
    today = datetime.utcnow().date()
    today_start = datetime(today.year, today.month, today.day)

    present_today = db.query(Attendance).filter(
        Attendance.date >= today_start,
        Attendance.status.in_(["Present", "Late"])
    ).count()

    total_visits_today = db.query(Visit).filter(Visit.scheduled_date >= today_start).count()
    completed_visits_today = db.query(Visit).filter(
        Visit.scheduled_date >= today_start,
        Visit.status == "Visited"
    ).count()

    kpis = [
        KPICard(
            label="Total Orders",
            value=str(total_orders),
            sub=f"{pending_orders} pending",
            trend="up"
        ),
        KPICard(
            label="Active Dealers",
            value=str(total_shops),
            sub="Authorized distributors",
            trend="neutral"
        ),
        KPICard(
            label="Field Executives",
            value=str(total_executives),
            sub=f"{present_today} present today",
            trend="up"
        ),
        KPICard(
            label="In Transit",
            value=str(dispatched_orders),
            sub="Shipments on the road",
            trend="up" if dispatched_orders > 0 else "neutral"
        ),
        KPICard(
            label="Products Listed",
            value=str(total_products),
            sub="Across all categories",
            trend="neutral"
        ),
        KPICard(
            label="Delivered Today",
            value=str(delivered_orders),
            sub="Successfully completed",
            trend="up"
        ),
    ]

    return DashboardData(
        kpis=kpis,
        total_orders=total_orders,
        pending_orders=pending_orders,
        dispatched_orders=dispatched_orders,
        delivered_orders=delivered_orders,
        total_products=total_products,
        total_shops=total_shops,
        total_executives=total_executives,
        present_today=present_today,
        total_visits_today=total_visits_today,
        completed_visits_today=completed_visits_today,
    )
