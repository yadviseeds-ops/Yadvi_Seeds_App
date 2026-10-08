from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session, joinedload
from typing import List, Optional
from pydantic import BaseModel
from datetime import datetime
import uuid
from app.core.database import get_db
from app.core.security import get_current_user, require_role
from app.models.all_models import Order, OrderItem, ShopOwner, FieldExecutive, Product, User, Shipment

router = APIRouter(prefix="/orders", tags=["Orders"])


class OrderItemIn(BaseModel):
    product_id: int
    package_size: str
    quantity_bags: int


class OrderCreateRequest(BaseModel):
    items: List[OrderItemIn]
    delivery_notes: Optional[str] = None
    source: Optional[str] = "Shop Owner App"


class OrderItemOut(BaseModel):
    id: int
    product_id: int
    product_name: str
    sku: str
    image_url: str
    package_size: str
    quantity_bags: int

    class Config:
        from_attributes = True


class OrderOut(BaseModel):
    id: int
    order_number: str
    shop_id: int
    shop_name: str
    shop_location: str
    owner_name: str
    contact_phone: str
    delivery_address: str
    total_quantity_bags: int
    total_items_count: int
    status: str
    source: str
    delivery_notes: Optional[str]
    assigned_executive_name: Optional[str]
    lr_number: Optional[str]
    transporter_name: Optional[str]
    created_at: datetime
    items: List[OrderItemOut]

    class Config:
        from_attributes = True


class StatusUpdateRequest(BaseModel):
    status: str
    lr_number: Optional[str] = None
    transporter_name: Optional[str] = None
    vehicle_number: Optional[str] = None
    driver_name: Optional[str] = None
    driver_phone: Optional[str] = None


def _build_order_out(order: Order) -> OrderOut:
    assigned_name = None
    if order.assigned_executive:
        assigned_name = order.assigned_executive.user.full_name

    lr_number = None
    transporter_name = None
    if order.shipment:
        lr_number = order.shipment.lr_number
        transporter_name = order.shipment.transporter_name

    items_out = []
    for item in order.items:
        items_out.append(OrderItemOut(
            id=item.id,
            product_id=item.product_id,
            product_name=item.product.name if item.product else "Unknown",
            sku=item.product.sku if item.product else "",
            image_url=item.product.image_url if item.product else "",
            package_size=item.package_size,
            quantity_bags=item.quantity_bags,
        ))

    return OrderOut(
        id=order.id,
        order_number=order.order_number,
        shop_id=order.shop_id,
        shop_name=order.shop.shop_name if order.shop else "Unknown",
        shop_location=order.shop.market_location if order.shop else "",
        owner_name=order.shop.user.full_name if order.shop and order.shop.user else "",
        contact_phone=order.shop.user.phone if order.shop and order.shop.user else "",
        delivery_address=order.shop.address if order.shop else "",
        total_quantity_bags=order.total_quantity_bags,
        total_items_count=order.total_items_count,
        status=order.status,
        source=order.source,
        delivery_notes=order.delivery_notes,
        assigned_executive_name=assigned_name,
        lr_number=lr_number,
        transporter_name=transporter_name,
        created_at=order.created_at,
        items=items_out,
    )


@router.get("", response_model=List[OrderOut])
def list_orders(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """List orders — filtered by role."""
    role_name = current_user.role.name if current_user.role else ""
    query = (
        db.query(Order)
        .options(
            joinedload(Order.shop).joinedload(ShopOwner.user),
            joinedload(Order.assigned_executive).joinedload(FieldExecutive.user),
            joinedload(Order.items).joinedload(OrderItem.product),
            joinedload(Order.shipment),
        )
        .order_by(Order.created_at.desc())
    )

    if role_name == "shop_owner":
        shop = db.query(ShopOwner).filter(ShopOwner.user_id == current_user.id).first()
        if shop:
            query = query.filter(Order.shop_id == shop.id)
        else:
            return []
    elif role_name == "field_executive":
        exec_ = db.query(FieldExecutive).filter(FieldExecutive.user_id == current_user.id).first()
        if exec_:
            query = query.filter(Order.assigned_executive_id == exec_.id)
        else:
            return []

    return [_build_order_out(o) for o in query.all()]


@router.post("", response_model=OrderOut)
def create_order(
    payload: OrderCreateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["shop_owner", "field_executive", "administrator"]))
):
    """Place a new order."""
    role_name = current_user.role.name if current_user.role else ""

    # Resolve shop
    if role_name == "shop_owner":
        shop = db.query(ShopOwner).filter(ShopOwner.user_id == current_user.id).first()
        if not shop:
            raise HTTPException(status_code=404, detail="Shop profile not found")
    else:
        raise HTTPException(status_code=403, detail="Only shop owners can place orders directly via this endpoint")

    # Validate products
    total_bags = 0
    order_items = []
    for item_in in payload.items:
        product = db.query(Product).filter(Product.id == item_in.product_id).first()
        if not product:
            raise HTTPException(status_code=404, detail=f"Product {item_in.product_id} not found")
        total_bags += item_in.quantity_bags
        order_items.append(OrderItem(
            product_id=item_in.product_id,
            package_size=item_in.package_size,
            quantity_bags=item_in.quantity_bags,
        ))

    # Generate order number
    count = db.query(Order).count()
    order_number = f"ORD-{1021 + count + 1}"

    new_order = Order(
        order_number=order_number,
        shop_id=shop.id,
        assigned_executive_id=shop.assigned_executive_id,
        total_quantity_bags=total_bags,
        total_items_count=len(order_items),
        status="New",
        source=payload.source or "Shop Owner App",
        delivery_notes=payload.delivery_notes,
    )
    db.add(new_order)
    db.flush()

    for oi in order_items:
        oi.order_id = new_order.id
        db.add(oi)

    db.commit()
    db.refresh(new_order)

    # Notify Admin
    try:
        from app.core.notifications import NotificationService
        admin_user = db.query(User).filter(User.role.has(name="administrator")).first()
        if admin_user:
            notif_service = NotificationService(db)
            notif_service.notify_admin_new_order(new_order, admin_user)
    except Exception as e:
        import logging
        logging.error(f"Failed to send admin notification for order {new_order.id}: {e}")

    # Reload with joins
    fresh = (
        db.query(Order)
        .options(
            joinedload(Order.shop).joinedload(ShopOwner.user),
            joinedload(Order.assigned_executive).joinedload(FieldExecutive.user),
            joinedload(Order.items).joinedload(OrderItem.product),
            joinedload(Order.shipment),
        )
        .filter(Order.id == new_order.id)
        .first()
    )
    return _build_order_out(fresh)


@router.put("/{order_id}/status")
def update_order_status(
    order_id: int,
    payload: StatusUpdateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["administrator"]))
):
    """Update order status — Admin only. If status=Dispatched, creates a shipment."""
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    order.status = payload.status

    if payload.lr_number:
        existing_shipment = db.query(Shipment).filter(Shipment.order_id == order.id).first()
        if not existing_shipment:
            shipment = Shipment(
                order_id=order.id,
                lr_number=payload.lr_number,
                transporter_name=payload.transporter_name or "Navata Road Transport",
                vehicle_number=payload.vehicle_number or "AP 16 TZ 5519",
                driver_name=payload.driver_name or "R. Koteswara Rao",
                driver_phone=payload.driver_phone or "+91 94402 88123",
                status=payload.status if payload.status in ["Dispatched", "In Transit", "Out for Delivery", "Delivered"] else "Dispatched",
                current_location="Gannavaram Central Hub",
                estimated_delivery="Within 48 Hours",
            )
            db.add(shipment)
        else:
            existing_shipment.lr_number = payload.lr_number
            if payload.transporter_name:
                existing_shipment.transporter_name = payload.transporter_name
            if payload.vehicle_number:
                existing_shipment.vehicle_number = payload.vehicle_number
            if payload.driver_name:
                existing_shipment.driver_name = payload.driver_name
            if payload.driver_phone:
                existing_shipment.driver_phone = payload.driver_phone
            if payload.status in ["Dispatched", "In Transit", "Out for Delivery", "Delivered"]:
                existing_shipment.status = payload.status

    db.commit()
    
    # Notify shop owner
    try:
        from app.core.notifications import NotificationService
        if order.shop and order.shop.user:
            notif_service = NotificationService(db)
            notif_service.notify_shop_order_status(order, order.shop.user)
    except Exception as e:
        import logging
        logging.error(f"Failed to send shop notification for order {order_id}: {e}")
        
    return {"success": True, "order_id": order_id, "new_status": payload.status}

