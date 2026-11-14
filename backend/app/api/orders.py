import logging
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session, joinedload
from typing import List, Optional
from pydantic import BaseModel
from datetime import datetime
import uuid
from app.core.database import get_db
from app.core.security import get_current_user, require_role
from app.models.all_models import Order, OrderItem, ShopOwner, FieldExecutive, Product, User, Shipment, Notification
from app.core.whatsapp import whatsapp_service

logger = logging.getLogger("yadvi_orders")

router = APIRouter(prefix="/orders", tags=["Orders"])


class OrderItemIn(BaseModel):
    product_id: int
    package_size: Optional[str] = "Standard"
    quantity: Optional[float] = None
    unit: Optional[str] = "kg"  # "g" or "kg"
    quantity_bags: Optional[int] = None  # Backward compatibility


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
    quantity: float
    unit: str

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
    total_quantity_kg: float
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
        qty = item.quantity if item.quantity is not None else float(getattr(item, 'quantity_bags', 0) or 0)
        unit = item.unit or "kg"
        items_out.append(OrderItemOut(
            id=item.id,
            product_id=item.product_id,
            product_name=item.product.name if item.product else "Unknown",
            sku=item.product.sku if item.product else "",
            image_url=item.product.image_url if item.product else "",
            package_size=item.package_size,
            quantity=qty,
            unit=unit,
        ))

    total_kg = order.total_quantity_kg
    if (total_kg is None or total_kg == 0.0) and getattr(order, 'total_quantity_bags', None):
        total_kg = float(order.total_quantity_bags)

    return OrderOut(
        id=order.id,
        order_number=order.order_number,
        shop_id=order.shop_id,
        shop_name=order.shop.shop_name if order.shop else "Unknown",
        shop_location=order.shop.market_location if order.shop else "",
        owner_name=order.shop.user.full_name if order.shop and order.shop.user else "",
        contact_phone=order.shop.user.phone if order.shop and order.shop.user else "",
        delivery_address=order.shop.address if order.shop else "",
        total_quantity_kg=round(total_kg or 0.0, 3),
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
@router.get("/", response_model=List[OrderOut], include_in_schema=False)
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
@router.post("/", response_model=OrderOut, include_in_schema=False)
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
            # Fallback by phone number
            shop = db.query(ShopOwner).join(User, ShopOwner.user_id == User.id).filter(User.phone == current_user.phone).first()
            if shop:
                shop.user_id = current_user.id
                db.commit()
                db.refresh(shop)
        if not shop:
            raise HTTPException(status_code=404, detail="Shop profile not found")
    elif role_name == "field_executive":
        exec_ = db.query(FieldExecutive).filter(FieldExecutive.user_id == current_user.id).first()
        shop = None
        if exec_:
            shop = db.query(ShopOwner).filter(ShopOwner.assigned_executive_id == exec_.id).first()
        if not shop:
            shop = db.query(ShopOwner).first()
        if not shop:
            raise HTTPException(status_code=404, detail="No shop available to book order for")
    elif role_name == "administrator":
        shop = db.query(ShopOwner).first()
        if not shop:
            raise HTTPException(status_code=404, detail="No shop available to book order for")
    else:
        raise HTTPException(status_code=403, detail="Not authorized to place orders")

    if not payload.items:
        raise HTTPException(status_code=400, detail="Cannot place an order with zero items")

    # Validate products and quantities
    total_kg = 0.0
    order_items = []
    for item_in in payload.items:
        product = db.query(Product).filter(Product.id == item_in.product_id).first()
        if not product:
            raise HTTPException(status_code=404, detail=f"Product {item_in.product_id} not found")

        # Determine quantity and unit
        raw_qty = item_in.quantity if item_in.quantity is not None else item_in.quantity_bags
        if raw_qty is None or raw_qty <= 0:
            raise HTTPException(status_code=400, detail=f"Quantity for {product.name} must be greater than zero.")

        unit = (item_in.unit or "kg").strip().lower()
        if unit not in ["g", "kg"]:
            raise HTTPException(status_code=400, detail=f"Invalid unit '{unit}'. Unit must be 'g' or 'kg'.")

        # Convert to kg for total calculation and stock validation
        item_kg = float(raw_qty) / 1000.0 if unit == "g" else float(raw_qty)
        if product.available_stock_kg is not None and product.available_stock_kg < item_kg:
            raise HTTPException(
                status_code=400,
                detail=f"Insufficient stock for {product.name}. Available: {product.available_stock_kg} kg, requested: {raw_qty} {unit} ({item_kg} kg)."
            )

        # Deduct stock
        if product.available_stock_kg is not None:
            product.available_stock_kg = max(0.0, product.available_stock_kg - item_kg)
            product.available_stock_bags = int(product.available_stock_kg)
            if product.available_stock_kg <= 0:
                product.availability = "Out of Stock"

        total_kg += item_kg

        order_items.append(OrderItem(
            product_id=item_in.product_id,
            package_size=item_in.package_size or "Standard",
            quantity=float(raw_qty),
            unit=unit,
            quantity_bags=int(raw_qty) if unit == "kg" else max(1, int(raw_qty / 1000.0)),
        ))

    # Generate unique, collision-proof sequential order number
    count = db.query(Order).count()
    last_order = db.query(Order).order_by(Order.id.desc()).first()
    next_num = max(1021 + count + 1, ((last_order.id + 1020) if last_order else 1021))
    order_number = f"ORD-{next_num}"
    while db.query(Order).filter(Order.order_number == order_number).first():
        next_num += 1
        order_number = f"ORD-{next_num}"

    new_order = Order(
        order_number=order_number,
        shop_id=shop.id,
        assigned_executive_id=shop.assigned_executive_id,
        total_quantity_kg=round(total_kg, 3),
        total_quantity_bags=int(total_kg) if total_kg >= 1 else 1,
        total_items_count=len(order_items),
        status="New",
        source=payload.source or ("Shop Owner App" if role_name == "shop_owner" else "Field Executive"),
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

    # WhatsApp Order Confirmation to configured test recipient
    try:
        recipient_for_record = (
            whatsapp_service.test_recipient
            or (fresh.shop.user.phone if fresh.shop and fresh.shop.user else "Unknown")
        )

        # Check idempotency to prevent duplicate notifications if endpoint is retried
        existing_sent = db.query(Notification).filter(
            Notification.order_number == fresh.order_number,
            Notification.channel == "WhatsApp",
            Notification.message_content.contains("Order Confirmation"),
            Notification.status.in_(["Sent", "Delivered", "Read"])
        ).first()

        if existing_sent:
            logger.info(f"WhatsApp confirmation already sent for order {fresh.order_number}. Skipping duplicate dispatch.")
        else:
            send_res = whatsapp_service.send_order_confirmation(fresh, fresh.items)
            is_success = send_res.get("success", False)
            notif_status = "Sent" if is_success else "Failed"
            deliv_status = "Accepted" if is_success else "Failed"
            meta_id = send_res.get("meta_message_id")
            err_code = send_res.get("error_code")
            err_msg = send_res.get("message") if not is_success else None

            db_notif = Notification(
                recipient_phone=recipient_for_record,
                channel="WhatsApp",
                order_number=fresh.order_number,
                shop_name=fresh.shop.shop_name if fresh.shop else "N/A",
                total_bags=fresh.total_quantity_bags,
                total_quantity_kg=fresh.total_quantity_kg,
                status=notif_status,
                meta_message_id=meta_id,
                delivery_status=deliv_status,
                meta_error_code=err_code,
                meta_error_message=err_msg,
                message_content=send_res.get("message_text", "")
            )
            db.add(db_notif)
            db.commit()

            if send_res.get("success"):
                logger.info(f"WhatsApp order confirmation accepted by Meta for order {fresh.order_number}")
            else:
                logger.warning(
                    f"WhatsApp order confirmation rejected or failed for order {fresh.order_number}: {send_res.get('message')}"
                )
    except Exception as e:
        db.rollback()
        logger.error(f"Non-fatal error during WhatsApp order confirmation for order {fresh.order_number}: {type(e).__name__}")

    return _build_order_out(fresh)


@router.get("/{order_id}", response_model=OrderOut)
def get_order_by_id(
    order_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Retrieve an order by ID with strict ownership authorization."""
    order = (
        db.query(Order)
        .options(
            joinedload(Order.shop).joinedload(ShopOwner.user),
            joinedload(Order.assigned_executive).joinedload(FieldExecutive.user),
            joinedload(Order.items).joinedload(OrderItem.product),
            joinedload(Order.shipment),
        )
        .filter(Order.id == order_id)
        .first()
    )
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")

    role_name = current_user.role.name if current_user.role else ""
    if role_name == "shop_owner":
        shop = db.query(ShopOwner).filter(ShopOwner.user_id == current_user.id).first()
        if not shop or order.shop_id != shop.id:
            raise HTTPException(status_code=403, detail="Not authorized to access this order.")
    elif role_name == "field_executive":
        exec_ = db.query(FieldExecutive).filter(FieldExecutive.user_id == current_user.id).first()
        if not exec_ or order.assigned_executive_id != exec_.id:
            raise HTTPException(status_code=403, detail="Not authorized to access this order.")

    return _build_order_out(order)


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
