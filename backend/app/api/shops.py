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
    owner_name: Optional[str] = None
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
    username: Optional[str] = None
    email: Optional[str] = None
    shop_name: Optional[str] = None
    market_location: Optional[str] = None
    territory: Optional[str] = None
    city: Optional[str] = None
    address: Optional[str] = None
    primary_demand_crop: Optional[str] = None
    status: Optional[str] = None
    assigned_executive_id: Optional[int] = None

class ShopOwnerProfileUpdate(BaseModel):
    owner_name: Optional[str] = None
    shop_name: Optional[str] = None
    email: Optional[str] = None
    address: Optional[str] = None
    market_location: Optional[str] = None

class ShopOut(BaseModel):
    id: int
    user_id: int
    username: Optional[str] = None
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
    owner_name: Optional[str] = None
    phone: str
    email: Optional[str]
    assigned_executive_id: Optional[int] = None
    assigned_executive_name: Optional[str] = None

class ShopAssignRequest(BaseModel):
    executive_id: Optional[int]

    class Config:
        from_attributes = True


@router.post("", response_model=ShopOut)
@router.post("/", response_model=ShopOut, include_in_schema=False)
def create_shop(
    payload: ShopCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["administrator"]))
):
    """Create a new shop owner — Admin only."""
    from app.api.auth import normalize_phone_number
    from app.core.security import get_password_hash

    clean_owner_name = payload.owner_name.strip() if payload.owner_name and payload.owner_name.strip() else None
    norm_phone = normalize_phone_number(payload.phone or "")
    clean_username = (payload.username or "").strip()
    clean_shop_name = (payload.shop_name or "").strip()
    clean_address = (payload.address or "").strip()
    clean_market_location = (payload.market_location or "").strip() or "Unspecified"
    clean_email = payload.email.strip() if payload.email and payload.email.strip() else None

    # Mandatory field validation (Owner Full Name is optional per Task 6)
    if not norm_phone or len(norm_phone) != 10:
        raise HTTPException(status_code=400, detail="Phone number must be a valid 10-digit mobile number.")
    if not clean_username:
        raise HTTPException(status_code=400, detail="Username is mandatory. Please fill it.")
    if not clean_shop_name:
        raise HTTPException(status_code=400, detail="Shop Name is mandatory. Please fill it.")
    if not clean_address:
        raise HTTPException(status_code=400, detail="Address is mandatory. Please fill it.")

    # Check if username or phone exists
    if db.query(User).filter(User.username == clean_username).first():
        raise HTTPException(status_code=400, detail=f"Username '{clean_username}' already exists")

    phone_candidates = [norm_phone, f"+91{norm_phone}", f"0{norm_phone}", f"91{norm_phone}"]
    if db.query(User).filter(User.phone.in_(phone_candidates)).first():
        raise HTTPException(status_code=400, detail=f"Phone number '{norm_phone}' already exists")

    if clean_email and db.query(User).filter(User.email == clean_email).first():
        raise HTTPException(status_code=400, detail=f"Email '{clean_email}' already exists")

    from app.models.all_models import Role
    role = db.query(Role).filter(Role.name == "shop_owner").first()
    if not role:
        raise HTTPException(status_code=500, detail="Role 'shop_owner' not found in database")

    try:
        new_user = User(
            full_name=clean_owner_name,
            phone=norm_phone,
            email=clean_email,
            username=clean_username,
            role_id=role.id,
            hashed_password=get_password_hash("shop123"),
            is_active=True
        )
        db.add(new_user)
        db.flush()

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
@router.get("/", response_model=List[ShopOut], include_in_schema=False)
def list_shops(
    all_shops: bool = True,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["administrator", "field_executive"]))
):
    """List shops — Admin and Field Executive see all active registered shops by default for planning visits. Inactive shops are excluded. If all_shops=False, filters by assigned territory."""
    query = db.query(ShopOwner).options(
        joinedload(ShopOwner.user),
        joinedload(ShopOwner.assigned_executive).joinedload(FieldExecutive.user)
    ).filter(ShopOwner.status == "Active")

    if current_user.role.name == "field_executive" and not all_shops:
        exec_profile = current_user.field_profile
        if exec_profile:
            territory = exec_profile.assigned_territory
            if territory:
                query = query.filter(
                    (ShopOwner.assigned_executive_id == exec_profile.id) |
                    (ShopOwner.market_location == territory) |
                    (ShopOwner.territory == territory)
                )
            else:
                query = query.filter(ShopOwner.assigned_executive_id == exec_profile.id)
        else:
            return []

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
            owner_name=s.user.full_name if (s.user and s.user.full_name) else None,
            username=s.user.username if s.user else None,
            phone=s.user.phone if s.user else "",
            email=s.user.email if s.user else None,
            assigned_executive_id=s.assigned_executive_id,
            assigned_executive_name=s.assigned_executive.user.full_name if (s.assigned_executive and s.assigned_executive.user) else None,
        )
        for s in shops
    ]


@router.get("/my", response_model=ShopOut)
@router.get("/my/", response_model=ShopOut, include_in_schema=False)
@router.get("/me", response_model=ShopOut, include_in_schema=False)
@router.get("/me/", response_model=ShopOut, include_in_schema=False)
def get_my_shop(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["shop_owner"]))
):
    """Get own shop profile — Shop Owner only."""
    shop = db.query(ShopOwner).options(
        joinedload(ShopOwner.assigned_executive).joinedload(FieldExecutive.user)
    ).filter(ShopOwner.user_id == current_user.id).first()
    if not shop:
        # Fallback by phone number
        shop = db.query(ShopOwner).join(User, ShopOwner.user_id == User.id).filter(User.phone == current_user.phone).first()
        if shop:
            shop.user_id = current_user.id
            db.commit()
            db.refresh(shop)
    if not shop:
        raise HTTPException(status_code=404, detail="Shop profile not found")
    return ShopOut(
        id=shop.id,
        user_id=shop.user_id,
        username=current_user.username,
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


@router.put("/my", response_model=ShopOut)
@router.put("/my/", response_model=ShopOut, include_in_schema=False)
@router.put("/me", response_model=ShopOut, include_in_schema=False)
@router.put("/me/", response_model=ShopOut, include_in_schema=False)
def update_my_shop_profile(
    payload: ShopOwnerProfileUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["shop_owner"]))
):
    """Shop Owner updates own profile (Task 8).
    Strictly forbids modifying mobile number, username, role, status, or assignment."""
    shop = db.query(ShopOwner).options(
        joinedload(ShopOwner.assigned_executive).joinedload(FieldExecutive.user)
    ).filter(ShopOwner.user_id == current_user.id).first()
    if not shop:
        raise HTTPException(status_code=404, detail="Shop profile not found")

    # Editable: owner_name (optional per Task 6)
    if payload.owner_name is not None:
        current_user.full_name = payload.owner_name.strip()

    # Editable: email (validated format and uniqueness)
    if payload.email is not None:
        clean_email = payload.email.strip()
        if clean_email:
            existing = db.query(User).filter(User.email == clean_email, User.id != current_user.id).first()
            if existing:
                raise HTTPException(status_code=400, detail="Email address is already in use by another account")
            current_user.email = clean_email
        else:
            current_user.email = None

    # Editable: shop_name
    if payload.shop_name is not None and payload.shop_name.strip():
        shop.shop_name = payload.shop_name.strip()

    # Editable: address
    if payload.address is not None and payload.address.strip():
        shop.address = payload.address.strip()

    # Editable: market_location
    if payload.market_location is not None:
        shop.market_location = payload.market_location.strip() or "Unspecified"

    db.commit()
    db.refresh(shop)
    db.refresh(current_user)

    return ShopOut(
        id=shop.id,
        user_id=shop.user_id,
        username=current_user.username,
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
@router.get("/{shop_id}/", response_model=ShopOut, include_in_schema=False)
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
        owner_name=shop.user.full_name if (shop.user and shop.user.full_name) else None,
        username=shop.user.username if shop.user else None,
        phone=shop.user.phone,
        email=shop.user.email,
        assigned_executive_id=shop.assigned_executive_id,
        assigned_executive_name=exec_name
    )


@router.put("/{shop_id}", response_model=ShopOut)
@router.put("/{shop_id}/", response_model=ShopOut, include_in_schema=False)
def update_shop(
    shop_id: int,
    payload: ShopUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["administrator"]))
):
    """Update shop owner details — Admin only."""
    user_role = current_user.role.name if (current_user and current_user.role) else ""
    if user_role != "administrator":
        raise HTTPException(status_code=403, detail="Administrator access required")
    from app.models.all_models import FieldExecutive
    shop = db.query(ShopOwner).options(joinedload(ShopOwner.user)).filter(ShopOwner.id == shop_id).first()
    if not shop:
        raise HTTPException(status_code=404, detail="Shop not found")

    if payload.owner_name is not None:
        shop.user.full_name = payload.owner_name.strip() if payload.owner_name.strip() else None

    if payload.username is not None and payload.username.strip():
        clean_username = payload.username.strip()
        existing_user = db.query(User).filter(User.username == clean_username, User.id != shop.user_id).first()
        if existing_user:
            raise HTTPException(status_code=400, detail=f"Username '{clean_username}' is already in use")
        shop.user.username = clean_username

    old_phone = shop.user.phone if shop.user else None
    if payload.phone is not None and payload.phone.strip():
        from app.api.auth import normalize_phone_number
        clean_phone = normalize_phone_number(payload.phone)
        if not clean_phone or len(clean_phone) != 10:
            raise HTTPException(status_code=400, detail="Phone number must be a valid 10-digit mobile number.")
        existing_phone = db.query(User).filter(User.phone == clean_phone, User.id != shop.user_id).first()
        if existing_phone:
            raise HTTPException(status_code=400, detail=f"Phone number '{clean_phone}' is already in use")
        shop.user.phone = clean_phone
        if old_phone:
            from app.core.firebase import sync_firebase_phone
            sync_firebase_phone(old_phone, clean_phone)

    if payload.email is not None:
        clean_email = payload.email.strip() if payload.email.strip() else None
        if clean_email:
            existing_email = db.query(User).filter(User.email == clean_email, User.id != shop.user_id).first()
            if existing_email:
                raise HTTPException(status_code=400, detail=f"Email '{clean_email}' is already in use")
        shop.user.email = clean_email

    if payload.assigned_executive_id is not None:
        if payload.assigned_executive_id in (0, -1):
            shop.assigned_executive_id = None
        else:
            fe = db.query(FieldExecutive).filter(FieldExecutive.id == payload.assigned_executive_id).first()
            if not fe:
                raise HTTPException(status_code=404, detail=f"Field Executive #{payload.assigned_executive_id} not found")
            shop.assigned_executive_id = fe.id

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
        owner_name=shop.user.full_name if (shop.user and shop.user.full_name) else None,
        username=shop.user.username if shop.user else None,
        phone=shop.user.phone,
        email=shop.user.email,
        assigned_executive_id=shop.assigned_executive_id,
        assigned_executive_name=exec_name
    )

@router.delete("/{shop_id}")
@router.delete("/{shop_id}/", include_in_schema=False)
def delete_shop(
    shop_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["administrator"]))
):
    """
    Permanently delete a shop owner if no historical business records exist — Admin only.
    Rejects deletion if the shop has associated orders or visits.
    """
    shop = db.query(ShopOwner).filter(ShopOwner.id == shop_id).first()
    if not shop:
        raise HTTPException(status_code=404, detail="Shop owner not found")

    from app.models.all_models import Order, Visit, FCMDeviceToken

    has_orders = db.query(Order).filter(Order.shop_id == shop.id).first() is not None
    if has_orders:
        raise HTTPException(
            status_code=400,
            detail="Cannot delete Shop Owner with associated orders. Historical order records must be preserved."
        )

    has_visits = db.query(Visit).filter(Visit.shop_id == shop.id).first() is not None
    if has_visits:
        raise HTTPException(
            status_code=400,
            detail="Cannot delete Shop Owner with recorded field visits. Historical visit records must be preserved."
        )

    user_id = shop.user_id
    try:
        # Delete device tokens for the shop owner's user account
        if user_id:
            db.query(FCMDeviceToken).filter(FCMDeviceToken.user_id == user_id).delete(synchronize_session=False)

        # Delete ShopOwner record
        db.delete(shop)
        db.flush()

        # Delete associated User record directly without triggering orphan traversal
        if user_id:
            db.query(User).filter(User.id == user_id).delete(synchronize_session=False)

        db.commit()
        return {"success": True, "detail": "Shop owner permanently deleted"}
    except HTTPException:
        db.rollback()
        raise
    except Exception as exc:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Database error deleting shop owner: {str(exc)}")

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
