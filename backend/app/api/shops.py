from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session, joinedload
from typing import List, Optional
from pydantic import BaseModel
from datetime import datetime
from app.core.database import get_db
from app.core.security import get_current_user, require_role
from app.models.all_models import ShopOwner, User, FieldExecutive, Visit

router = APIRouter(prefix="/shops", tags=["Shop Owners"])


class ShopCreate(BaseModel):
    owner_name: str
    phone: str
    email: Optional[str] = None
    username: str
    shop_name: str
    market_location: Optional[str] = ""
    territory: Optional[str] = None
    city: Optional[str] = None
    address: str
    shop_photo_url: Optional[str] = None
    owner_photo_url: Optional[str] = None
    primary_demand_crop: Optional[str] = None

class ShopUpdate(BaseModel):
    owner_name: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[str] = None
    shop_name: Optional[str] = None
    market_location: Optional[str] = None
    territory: Optional[str] = None
    city: Optional[str] = None
    address: Optional[str] = None
    primary_demand_crop: Optional[str] = None
    status: Optional[str] = None

class ShopOut(BaseModel):
    id: int
    user_id: int
    shop_name: str
    market_location: str
    territory: Optional[str]
    city: Optional[str]
    address: str
    lat: Optional[float]
    lng: Optional[float]
    shop_photo_url: Optional[str]
    owner_photo_url: Optional[str]
    opening_stock_bags: Optional[int] = 0
    current_stock_bags: Optional[int] = 0
    opening_stock_kg: Optional[float] = 0.0
    current_stock_kg: Optional[float] = 0.0
    primary_demand_crop: Optional[str]
    status: str
    owner_name: str
    phone: str
    email: Optional[str]
    assigned_executive_id: Optional[int] = None
    assigned_executive_name: Optional[str] = None

class ShopAssignRequest(BaseModel):
    executive_id: Optional[int]

    class Config:
        from_attributes = True


@router.post("", response_model=ShopOut)
def create_shop(
    payload: ShopCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["administrator"]))
):
    """Create a new shop owner — Admin only."""
    import uuid
    clean_owner_name = (payload.owner_name or "").strip()
    clean_phone = (payload.phone or "").strip()
    clean_username = (payload.username or "").strip()
    clean_shop_name = (payload.shop_name or "").strip()
    clean_address = (payload.address or "").strip()
    clean_market_location = (payload.market_location or "").strip() or "Unspecified"
    clean_email = payload.email.strip() if payload.email and payload.email.strip() else None

    # Mandatory field validation
    if not clean_owner_name:
        raise HTTPException(status_code=400, detail="Owner Name is mandatory. Please fill it.")
    if not clean_phone:
        raise HTTPException(status_code=400, detail="Phone Number is mandatory. Please fill it.")
    if not clean_username:
        raise HTTPException(status_code=400, detail="Username is mandatory. Please fill it.")
    if not clean_shop_name:
        raise HTTPException(status_code=400, detail="Shop Name is mandatory. Please fill it.")
    if not clean_address:
        raise HTTPException(status_code=400, detail="Address is mandatory. Please fill it.")

    # Check if username or phone exists
    if db.query(User).filter(User.username == clean_username).first():
        raise HTTPException(status_code=400, detail=f"Username '{clean_username}' already exists")
    if db.query(User).filter(User.phone == clean_phone).first():
        raise HTTPException(status_code=400, detail=f"Phone number '{clean_phone}' already exists")
    if clean_email and db.query(User).filter(User.email == clean_email).first():
        raise HTTPException(status_code=400, detail=f"Email '{clean_email}' already exists")

    from app.models.all_models import Role
    role = db.query(Role).filter(Role.name == "shop_owner").first()
    if not role:
        raise HTTPException(status_code=500, detail="Role 'shop_owner' not found in database")

    try:
        new_user = User(
            full_name=clean_owner_name,
            phone=clean_phone,
            email=clean_email,
            username=clean_username,
            role_id=role.id,
            is_active=True
        )
        db.add(new_user)
        db.commit()
        db.refresh(new_user)

        new_shop = ShopOwner(
            user_id=new_user.id,
            shop_name=clean_shop_name,
            market_location=clean_market_location,
            territory=payload.territory.strip() if payload.territory and payload.territory.strip() else None,
            city=payload.city.strip() if payload.city and payload.city.strip() else None,
            address=clean_address,
            shop_photo_url=payload.shop_photo_url,
            owner_photo_url=payload.owner_photo_url,
            primary_demand_crop=payload.primary_demand_crop
        )
        db.add(new_shop)
        db.commit()
        db.refresh(new_shop)
    except Exception as exc:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Database error creating shop: {str(exc)}")

    shop_loaded = db.query(ShopOwner).options(
        joinedload(ShopOwner.user),
        joinedload(ShopOwner.assigned_executive).joinedload(FieldExecutive.user)
    ).filter(ShopOwner.id == new_shop.id).first()

    return ShopOut(
        id=shop_loaded.id,
        user_id=shop_loaded.user_id,
        shop_name=shop_loaded.shop_name,
        market_location=shop_loaded.market_location,
        territory=shop_loaded.territory,
        city=shop_loaded.city,
        address=shop_loaded.address,
        lat=shop_loaded.lat,
        lng=shop_loaded.lng,
        shop_photo_url=shop_loaded.shop_photo_url,
        owner_photo_url=shop_loaded.owner_photo_url,
        opening_stock_bags=shop_loaded.opening_stock_bags,
        current_stock_bags=shop_loaded.current_stock_bags,
        primary_demand_crop=shop_loaded.primary_demand_crop,
        status=shop_loaded.status,
        owner_name=shop_loaded.user.full_name,
        phone=shop_loaded.user.phone,
        email=shop_loaded.user.email,
        assigned_executive_id=None,
        assigned_executive_name=None,
    )

@router.get("", response_model=List[ShopOut])
def list_shops(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["administrator", "field_executive"]))
):
    """List shops — Admin sees all, Field Exec sees assigned territory or explicitly assigned shops."""
    query = db.query(ShopOwner).options(
        joinedload(ShopOwner.user),
        joinedload(ShopOwner.assigned_executive).joinedload(FieldExecutive.user)
    ).filter(ShopOwner.status == "Active")

    if current_user.role.name == "field_executive":
        exec_profile = current_user.field_profile
        if exec_profile:
            territory = exec_profile.assigned_territory
            if territory:
                query = query.filter(
                    (ShopOwner.assigned_executive_id == exec_profile.id) |
                    (ShopOwner.market_location == territory)
                )
            else:
                query = query.filter(ShopOwner.assigned_executive_id == exec_profile.id)

    shops = query.all()
    return [
        ShopOut(
            id=s.id,
            user_id=s.user_id,
            shop_name=s.shop_name,
            market_location=s.market_location,
            territory=s.territory,
            city=s.city,
            address=s.address,
            lat=s.lat,
            lng=s.lng,
            shop_photo_url=s.shop_photo_url,
            owner_photo_url=s.owner_photo_url,
            opening_stock_bags=s.opening_stock_bags,
            current_stock_bags=s.current_stock_bags,
            primary_demand_crop=s.primary_demand_crop,
            status=s.status,
            owner_name=s.user.full_name if s.user else "Unknown",
            phone=s.user.phone if s.user else "",
            email=s.user.email if s.user else None,
            assigned_executive_id=s.assigned_executive_id,
            assigned_executive_name=s.assigned_executive.user.full_name if (s.assigned_executive and s.assigned_executive.user) else None,
        )
        for s in shops
    ]


@router.get("/my", response_model=ShopOut)
def get_my_shop(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["shop_owner"]))
):
    """Get own shop profile — Shop Owner only."""
    shop = db.query(ShopOwner).options(
        joinedload(ShopOwner.assigned_executive).joinedload(FieldExecutive.user)
    ).filter(ShopOwner.user_id == current_user.id).first()
    if not shop:
        raise HTTPException(status_code=404, detail="Shop profile not found")
    return ShopOut(
        id=shop.id,
        user_id=shop.user_id,
        shop_name=shop.shop_name,
        market_location=shop.market_location,
        territory=shop.territory,
        city=shop.city,
        address=shop.address,
        lat=shop.lat,
        lng=shop.lng,
        shop_photo_url=shop.shop_photo_url,
        owner_photo_url=shop.owner_photo_url,
        opening_stock_bags=shop.opening_stock_bags,
        current_stock_bags=shop.current_stock_bags,
        primary_demand_crop=shop.primary_demand_crop,
        status=shop.status,
        owner_name=current_user.full_name,
        phone=current_user.phone,
        email=current_user.email,
        assigned_executive_id=shop.assigned_executive_id,
        assigned_executive_name=shop.assigned_executive.user.full_name if (shop.assigned_executive and shop.assigned_executive.user) else None
    )


@router.get("/{shop_id}", response_model=ShopOut)
def get_shop(
    shop_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["administrator", "field_executive"]))
):
    from app.models.all_models import FieldExecutive
    shop = db.query(ShopOwner).options(joinedload(ShopOwner.user), joinedload(ShopOwner.assigned_executive).joinedload(FieldExecutive.user)).filter(ShopOwner.id == shop_id).first()
    if not shop:
        raise HTTPException(status_code=404, detail="Shop not found")

    exec_name = None
    if shop.assigned_executive:
        exec_name = shop.assigned_executive.user.full_name

    return ShopOut(
        id=shop.id,
        user_id=shop.user_id,
        shop_name=shop.shop_name,
        market_location=shop.market_location,
        territory=shop.territory,
        city=shop.city,
        address=shop.address,
        lat=shop.lat,
        lng=shop.lng,
        shop_photo_url=shop.shop_photo_url,
        owner_photo_url=shop.owner_photo_url,
        opening_stock_bags=shop.opening_stock_bags,
        current_stock_bags=shop.current_stock_bags,
        primary_demand_crop=shop.primary_demand_crop,
        status=shop.status,
        owner_name=shop.user.full_name,
        phone=shop.user.phone,
        email=shop.user.email,
        assigned_executive_id=shop.assigned_executive_id,
        assigned_executive_name=exec_name
    )


@router.put("/{shop_id}", response_model=ShopOut)
def update_shop(
    shop_id: int,
    payload: ShopUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["administrator"]))
):
    """Update shop owner details — Admin only."""
    from app.models.all_models import FieldExecutive
    shop = db.query(ShopOwner).options(joinedload(ShopOwner.user)).filter(ShopOwner.id == shop_id).first()
    if not shop:
        raise HTTPException(status_code=404, detail="Shop not found")

    if payload.owner_name is not None and payload.owner_name.strip():
        shop.user.full_name = payload.owner_name.strip()
    if payload.phone is not None and payload.phone.strip():
        clean_phone = payload.phone.strip()
        existing_phone = db.query(User).filter(User.phone == clean_phone, User.id != shop.user_id).first()
        if existing_phone:
            raise HTTPException(status_code=400, detail=f"Phone number '{clean_phone}' is already in use")
        shop.user.phone = clean_phone
    if payload.email is not None:
        clean_email = payload.email.strip() if payload.email.strip() else None
        if clean_email:
            existing_email = db.query(User).filter(User.email == clean_email, User.id != shop.user_id).first()
            if existing_email:
                raise HTTPException(status_code=400, detail=f"Email '{clean_email}' is already in use")
        shop.user.email = clean_email

    if payload.shop_name is not None and payload.shop_name.strip():
        shop.shop_name = payload.shop_name.strip()
    if payload.market_location is not None:
        shop.market_location = payload.market_location.strip() or "Unspecified"
    if payload.address is not None and payload.address.strip():
        shop.address = payload.address.strip()
    if payload.territory is not None:
        shop.territory = payload.territory.strip() or None
    if payload.city is not None:
        shop.city = payload.city.strip() or None
    if payload.primary_demand_crop is not None:
        shop.primary_demand_crop = payload.primary_demand_crop.strip() or None
    if payload.status is not None and payload.status.strip():
        shop.status = payload.status.strip()

    try:
        db.commit()
        db.refresh(shop)
    except Exception as exc:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Database error updating shop: {str(exc)}")

    exec_name = None
    if shop.assigned_executive:
        exec_name = shop.assigned_executive.user.full_name

    return ShopOut(
        id=shop.id,
        user_id=shop.user_id,
        shop_name=shop.shop_name,
        market_location=shop.market_location,
        territory=shop.territory,
        city=shop.city,
        address=shop.address,
        lat=shop.lat,
        lng=shop.lng,
        shop_photo_url=shop.shop_photo_url,
        owner_photo_url=shop.owner_photo_url,
        opening_stock_bags=shop.opening_stock_bags,
        current_stock_bags=shop.current_stock_bags,
        primary_demand_crop=shop.primary_demand_crop,
        status=shop.status,
        owner_name=shop.user.full_name,
        phone=shop.user.phone,
        email=shop.user.email,
        assigned_executive_id=shop.assigned_executive_id,
        assigned_executive_name=exec_name
    )

@router.delete("/{shop_id}")
def delete_shop(
    shop_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["administrator"]))
):
    """Soft delete shop by setting status to Inactive — Admin only."""
    shop = db.query(ShopOwner).filter(ShopOwner.id == shop_id).first()
    if not shop:
        raise HTTPException(status_code=404, detail="Shop owner not found")

    shop.status = "Inactive"
    if shop.user:
        shop.user.is_active = False

    db.commit()
    return {"success": True, "detail": "Shop owner removed"}

@router.put("/{shop_id}/assign")
def assign_shop(
    shop_id: int,
    payload: ShopAssignRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["administrator"]))
):
    shop = db.query(ShopOwner).filter(ShopOwner.id == shop_id).first()

    if not shop:
        raise HTTPException(status_code=404, detail="Shop not found")

    # Unassign shop
    if payload.executive_id is None:
        shop.assigned_executive_id = None
        db.commit()

        return {
            "success": True,
            "message": "Shop unassigned successfully",
            "shop_id": shop.id,
            "assigned_executive_id": None,
            "assigned_executive_name": "Unassigned"
        }

    # Verify real Field Executive
    executive = (
        db.query(FieldExecutive)
        .options(joinedload(FieldExecutive.user))
        .filter(FieldExecutive.id == payload.executive_id)
        .first()
    )

    if not executive:
        raise HTTPException(
            status_code=404,
            detail="Field Executive not found"
        )

    # ---------------------------------------------------------
    # 1. REAL SHOP → FE ASSIGNMENT
    # ---------------------------------------------------------
    shop.assigned_executive_id = executive.id

    # ---------------------------------------------------------
    # 2. CREATE / UPDATE TODAY'S REAL PENDING VISIT
    # ---------------------------------------------------------
    today = datetime.utcnow().date()

    today_visits = (
        db.query(Visit)
        .filter(
            Visit.shop_id == shop.id,
            Visit.scheduled_date >= datetime.combine(today, datetime.min.time()),
            Visit.scheduled_date < datetime.combine(
                today,
                datetime.max.time()
            )
        )
        .all()
    )

    # Look for an existing Pending visit for this shop today
    pending_visit = next(
        (v for v in today_visits if v.status == "Pending"),
        None
    )

    if pending_visit:
        # Reassign the existing Pending visit
        pending_visit.executive_id = executive.id
        pending_visit.scheduled_date = datetime.utcnow()
    else:
        # Create one real Pending visit
        pending_visit = Visit(
            executive_id=executive.id,
            shop_id=shop.id,
            purpose="Shop Visit",
            status="Pending",
            scheduled_date=datetime.utcnow(),
        )
        db.add(pending_visit)

    db.commit()
    db.refresh(shop)

    exec_name = executive.user.full_name if executive.user else "Unassigned"

    return {
        "success": True,
        "message": "Shop assigned successfully",
        "shop_id": shop.id,
        "assigned_executive_id": executive.id,
        "assigned_executive_name": exec_name,
        "executive_id": executive.id,
        "visit_id": pending_visit.id,
    }
