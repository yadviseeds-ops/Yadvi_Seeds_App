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
    dealer_code: str
    market_location: str
    territory: Optional[str] = None
    city: Optional[str] = None
    address: str
    shop_photo_url: Optional[str] = None
    owner_photo_url: Optional[str] = None
    primary_demand_crop: Optional[str] = None

class ShopOut(BaseModel):
    id: int
    user_id: int
    shop_name: str
    dealer_code: str
    market_location: str
    territory: Optional[str]
    city: Optional[str]
    address: str
    lat: Optional[float]
    lng: Optional[float]
    shop_photo_url: Optional[str]
    owner_photo_url: Optional[str]
    opening_stock_bags: int
    current_stock_bags: int
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
    # Check if username or phone exists
    if db.query(User).filter((User.username == payload.username) | (User.phone == payload.phone)).first():
        raise HTTPException(status_code=400, detail="Username or Phone already exists")
        
    if db.query(ShopOwner).filter(ShopOwner.dealer_code == payload.dealer_code).first():
        raise HTTPException(status_code=400, detail="Dealer code already exists")

    from app.models.all_models import Role
    role = db.query(Role).filter(Role.name == "shop_owner").first()
    if not role:
        raise HTTPException(status_code=500, detail="Role 'shop_owner' not found in database")

    new_user = User(
        full_name=payload.owner_name,
        phone=payload.phone,
        email=payload.email,
        username=payload.username,
        role_id=role.id,
        is_active=True
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    new_shop = ShopOwner(
        user_id=new_user.id,
        shop_name=payload.shop_name,
        dealer_code=payload.dealer_code,
        market_location=payload.market_location,
        territory=payload.territory,
        city=payload.city,
        address=payload.address,
        shop_photo_url=payload.shop_photo_url,
        owner_photo_url=payload.owner_photo_url,
        primary_demand_crop=payload.primary_demand_crop
    )
    db.add(new_shop)
    db.commit()
    db.refresh(new_shop)
    
    shop_loaded = db.query(ShopOwner).options(joinedload(ShopOwner.user)).filter(ShopOwner.id == new_shop.id).first()
    
    return ShopOut(
        id=shop_loaded.id,
        user_id=shop_loaded.user_id,
        shop_name=shop_loaded.shop_name,
        dealer_code=shop_loaded.dealer_code,
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
    )

@router.get("", response_model=List[ShopOut])
def list_shops(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["administrator", "field_executive"]))
):
    """List shops — Admin sees all, Field Exec sees assigned territory."""
    query = db.query(ShopOwner).options(joinedload(ShopOwner.user))
    
    if current_user.role.name == "field_executive":
        exec_profile = current_user.field_profile
        if exec_profile and exec_profile.assigned_territory:
            # Simple match. In a real app this might be more complex mapping.
            query = query.filter(ShopOwner.market_location == exec_profile.assigned_territory)
            
    shops = query.all()
    return [
        ShopOut(
            id=s.id,
            user_id=s.user_id,
            shop_name=s.shop_name,
            dealer_code=s.dealer_code,
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
            owner_name=s.user.full_name,
            phone=s.user.phone,
            email=s.user.email,
        )
        for s in shops
    ]


@router.get("/my", response_model=ShopOut)
def get_my_shop(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["shop_owner"]))
):
    """Get own shop profile — Shop Owner only."""
    shop = db.query(ShopOwner).filter(ShopOwner.user_id == current_user.id).first()
    if not shop:
        raise HTTPException(status_code=404, detail="Shop profile not found")
    return ShopOut(
        id=shop.id,
        user_id=shop.user_id,
        shop_name=shop.shop_name,
        dealer_code=shop.dealer_code,
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
        assigned_executive_name=shop.assigned_executive.user.full_name if shop.assigned_executive else None
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
        dealer_code=shop.dealer_code,
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
            "message": "Shop unassigned successfully"
        }

    # Verify real Field Executive
    executive = (
        db.query(FieldExecutive)
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

    return {
        "success": True,
        "message": "Shop assigned successfully",
        "shop_id": shop.id,
        "executive_id": executive.id,
        "visit_id": pending_visit.id,
    }