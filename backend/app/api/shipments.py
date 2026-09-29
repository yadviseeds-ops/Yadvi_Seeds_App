from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session, joinedload
from typing import List, Optional
from pydantic import BaseModel
from datetime import datetime
from app.core.database import get_db
from app.core.security import require_role, get_current_user
from app.models.all_models import Shipment, Order, ShopOwner, User, FieldExecutive

router = APIRouter(prefix="/shipments", tags=["Shipments & Logistics"])


class ShipmentOut(BaseModel):
    id: int
    order_id: int
    order_number: str
    lr_number: str
    transporter_name: str
    vehicle_number: Optional[str]
    driver_name: Optional[str]
    driver_phone: Optional[str]
    dispatch_date: datetime
    estimated_delivery: str
    status: str
    current_location: str
    shop_name: str
    shop_location: str
    total_bags: int

    class Config:
        from_attributes = True


class ShipmentStatusUpdate(BaseModel):
    status: str
    current_location: Optional[str] = None


@router.get("", response_model=List[ShipmentOut])
def list_shipments(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["administrator"]))
):
    """List all shipments — Admin only."""
    shipments = (
        db.query(Shipment)
        .options(
            joinedload(Shipment.order).joinedload(Order.shop).joinedload(ShopOwner.user)
        )
        .order_by(Shipment.dispatch_date.desc())
        .all()
    )
    result = []
    for s in shipments:
        order = s.order
        shop = order.shop if order else None
        result.append(ShipmentOut(
            id=s.id,
            order_id=s.order_id,
            order_number=order.order_number if order else "",
            lr_number=s.lr_number,
            transporter_name=s.transporter_name,
            vehicle_number=s.vehicle_number,
            driver_name=s.driver_name,
            driver_phone=s.driver_phone,
            dispatch_date=s.dispatch_date,
            estimated_delivery=s.estimated_delivery,
            status=s.status,
            current_location=s.current_location,
            shop_name=shop.shop_name if shop else "Unknown",
            shop_location=shop.market_location if shop else "",
            total_bags=order.total_quantity_bags if order else 0,
        ))
    return result


@router.put("/{shipment_id}/status")
def update_shipment_status(
    shipment_id: int,
    payload: ShipmentStatusUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["administrator"]))
):
    """Update shipment status — Admin only."""
    shipment = db.query(Shipment).filter(Shipment.id == shipment_id).first()
    if not shipment:
        raise HTTPException(status_code=404, detail="Shipment not found")

    shipment.status = payload.status
    if payload.current_location:
        shipment.current_location = payload.current_location

    # Keep order status in sync
    if shipment.order:
        shipment.order.status = payload.status

    db.commit()
    return {"success": True, "shipment_id": shipment_id, "new_status": payload.status}


def _build_shipment_out(s: Shipment) -> ShipmentOut:
    order = s.order
    shop = order.shop if order else None
    return ShipmentOut(
        id=s.id,
        order_id=s.order_id,
        order_number=order.order_number if order else "",
        lr_number=s.lr_number,
        transporter_name=s.transporter_name,
        vehicle_number=s.vehicle_number,
        driver_name=s.driver_name,
        driver_phone=s.driver_phone,
        dispatch_date=s.dispatch_date,
        estimated_delivery=s.estimated_delivery,
        status=s.status,
        current_location=s.current_location,
        shop_name=shop.shop_name if shop else "Unknown",
        shop_location=shop.market_location if shop else "",
        total_bags=order.total_quantity_bags if order else 0,
    )


@router.get("/my", response_model=List[ShipmentOut])
def get_my_shipments(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["field_executive"]))
):
    """Get shipments for orders assigned to this field executive."""
    exec_ = db.query(FieldExecutive).filter(FieldExecutive.user_id == current_user.id).first()
    if not exec_:
        return []

    # Get order IDs assigned to this FE
    assigned_order_ids = [
        o.id for o in db.query(Order).filter(Order.assigned_executive_id == exec_.id).all()
    ]
    if not assigned_order_ids:
        return []

    shipments = (
        db.query(Shipment)
        .options(joinedload(Shipment.order).joinedload(Order.shop).joinedload(ShopOwner.user))
        .filter(Shipment.order_id.in_(assigned_order_ids))
        .order_by(Shipment.dispatch_date.desc())
        .all()
    )
    return [_build_shipment_out(s) for s in shipments]
