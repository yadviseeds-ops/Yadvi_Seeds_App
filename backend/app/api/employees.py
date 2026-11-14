from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session, joinedload
from typing import List, Optional
from pydantic import BaseModel
from datetime import datetime
from app.core.database import get_db
from app.core.security import get_current_user, require_role
from app.models.all_models import FieldExecutive, User, ShopOwner, Visit

router = APIRouter(prefix="/employees", tags=["Field Executives"])


class EmployeeCreate(BaseModel):
    full_name: str
    phone: str
    email: Optional[str] = None
    username: str
    employee_code: str
    designation: str = "Field Sales Officer"
    assigned_territory: Optional[str] = ""

class FEProfileUpdate(BaseModel):
    full_name: Optional[str] = None
    email: Optional[str] = None

class EmployeeAdminUpdate(BaseModel):
    full_name: Optional[str] = None
    phone: Optional[str] = None
    username: Optional[str] = None
    email: Optional[str] = None
    employee_code: Optional[str] = None
    designation: Optional[str] = None
    assigned_territory: Optional[str] = None
    is_active: Optional[bool] = None

class AssignedShopOut(BaseModel):
    id: int
    shop_name: str
    market_location: Optional[str] = ""
    address: Optional[str] = ""
    status: Optional[str] = "Active"
    phone: Optional[str] = None
    owner_name: Optional[str] = None

    class Config:
        from_attributes = True

class EmployeeOut(BaseModel):
    id: int
    user_id: int
    username: Optional[str] = None
    employee_code: str
    designation: Optional[str] = ""
    assigned_territory: Optional[str] = ""
    current_lat: Optional[float] = None
    current_lng: Optional[float] = None
    battery_level: Optional[int] = 0
    attendance_status: Optional[str] = "Present"
    distance_covered_km: Optional[float] = 0.0
    last_location_update: Optional[datetime] = None
    full_name: str
    phone: str
    email: Optional[str] = None
    is_active: bool
    assigned_shops: List[AssignedShopOut] = []
    total_assigned_shops: int = 0
    completed_visits: int = 0
    pending_visits: int = 0

    class Config:
        from_attributes = True


class LocationUpdateRequest(BaseModel):
    lat: float
    lng: float
    battery_level: Optional[int] = None


@router.post("", response_model=EmployeeOut)
@router.post("/", response_model=EmployeeOut, include_in_schema=False)
def create_employee(
    payload: EmployeeCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["administrator"]))
):
    """Create a new field executive — Admin only."""
    from app.api.auth import normalize_phone_number
    from app.core.security import get_password_hash

    clean_full_name = (payload.full_name or "").strip()
    norm_phone = normalize_phone_number(payload.phone or "")
    clean_username = (payload.username or "").strip()
    clean_employee_code = (payload.employee_code or "").strip()
    clean_designation = (payload.designation or "").strip() or "Field Executive"
    clean_territory = (payload.assigned_territory or "").strip() or "Unassigned"
    clean_email = payload.email.strip() if payload.email and payload.email.strip() else None

    # Mandatory field validation
    if not clean_full_name:
        raise HTTPException(status_code=400, detail="Full Name is mandatory. Please fill it.")
    if not norm_phone or len(norm_phone) != 10:
        raise HTTPException(status_code=400, detail="Phone number must be a valid 10-digit mobile number.")
    if not clean_username:
        raise HTTPException(status_code=400, detail="Username is mandatory. Please fill it.")
    if not clean_employee_code:
        raise HTTPException(status_code=400, detail="Employee Code is mandatory. Please fill it.")

    # Check for uniqueness
    if db.query(User).filter(User.username == clean_username).first():
        raise HTTPException(status_code=400, detail=f"Username '{clean_username}' already exists")
    
    phone_candidates = [norm_phone, f"+91{norm_phone}", f"0{norm_phone}", f"91{norm_phone}"]
    if db.query(User).filter(User.phone.in_(phone_candidates)).first():
        raise HTTPException(status_code=400, detail=f"Phone number '{norm_phone}' already exists")
    
    if clean_email and db.query(User).filter(User.email == clean_email).first():
        raise HTTPException(status_code=400, detail=f"Email '{clean_email}' already exists")
    if db.query(FieldExecutive).filter(FieldExecutive.employee_code == clean_employee_code).first():
        raise HTTPException(status_code=400, detail=f"Employee code '{clean_employee_code}' already exists")

    from app.models.all_models import Role
    role = db.query(Role).filter(Role.name == "field_executive").first()
    if not role:
        raise HTTPException(status_code=500, detail="Role 'field_executive' not found in database")

    try:
        new_user = User(
            full_name=clean_full_name,
            phone=norm_phone,
            email=clean_email,
            username=clean_username,
            role_id=role.id,
            hashed_password=get_password_hash("field123"),
            is_active=True
        )
        db.add(new_user)
        db.flush()

        new_exec = FieldExecutive(
            user_id=new_user.id,
            employee_code=clean_employee_code,
            designation=clean_designation,
            assigned_territory=clean_territory
        )
        db.add(new_exec)
        db.commit()
        db.refresh(new_exec)
    except Exception as exc:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Database error creating employee: {str(exc)}")

    # Reload with joined user to match out schema
    exec_loaded = db.query(FieldExecutive).options(joinedload(FieldExecutive.user)).filter(FieldExecutive.id == new_exec.id).first()

    return EmployeeOut(
        id=exec_loaded.id,
        user_id=exec_loaded.user_id,
        username=exec_loaded.user.username if exec_loaded.user else "",
        employee_code=exec_loaded.employee_code,
        designation=exec_loaded.designation,
        assigned_territory=exec_loaded.assigned_territory,
        current_lat=exec_loaded.current_lat,
        current_lng=exec_loaded.current_lng,
        battery_level=exec_loaded.battery_level,
        attendance_status=exec_loaded.attendance_status,
        distance_covered_km=exec_loaded.distance_covered_km,
        last_location_update=exec_loaded.last_location_update,
        full_name=exec_loaded.user.full_name,
        phone=exec_loaded.user.phone,
        email=exec_loaded.user.email,
        is_active=exec_loaded.user.is_active,
    )

@router.get("", response_model=List[EmployeeOut])
@router.get("/", response_model=List[EmployeeOut], include_in_schema=False)
def list_employees(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["administrator"]))
):
    """List all field executives — Admin only."""
    executives = (
        db.query(FieldExecutive)
        .join(User)
        .filter(User.is_active == True)
        .options(joinedload(FieldExecutive.user))
        .all()
    )
    result = []
    for exec_ in executives:
        result.append(EmployeeOut(
            id=exec_.id,
            user_id=exec_.user_id,
            username=exec_.user.username if exec_.user else "",
            employee_code=exec_.employee_code,
            designation=exec_.designation or "",
            assigned_territory=exec_.assigned_territory or "",
            current_lat=exec_.current_lat,
            current_lng=exec_.current_lng,
            battery_level=exec_.battery_level if exec_.battery_level is not None else 0,
            attendance_status=exec_.attendance_status or "Present",
            distance_covered_km=exec_.distance_covered_km if exec_.distance_covered_km is not None else 0.0,
            last_location_update=exec_.last_location_update,
            full_name=exec_.user.full_name,
            phone=exec_.user.phone,
            email=exec_.user.email,
            is_active=exec_.user.is_active,
        ))
    return result


@router.delete("/{employee_id}")
@router.delete("/{employee_id}/", include_in_schema=False)
def delete_employee(
    employee_id: int,
    force: bool = False,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["administrator"]))
):
    """
    Permanently delete a field executive — Admin only.
    If force=False (default), rejects deletion if the executive is referenced by visits, attendances, EOD reports, or orders.
    If force=True, unassigns shops/orders and cascades associated historical records safely.
    """
    exec_ = db.query(FieldExecutive).filter(FieldExecutive.id == employee_id).first()
    if not exec_:
        raise HTTPException(status_code=404, detail="Field executive not found")

    from app.models.all_models import Visit, Attendance, EODReport, Order, FELocation, FCMDeviceToken, ShopOwner

    if not force:
        has_visits = db.query(Visit).filter(Visit.executive_id == exec_.id).first() is not None
        if has_visits:
            raise HTTPException(
                status_code=400,
                detail="Cannot delete Field Executive with recorded visits. Historical visit records must be preserved."
            )

        has_attendance = db.query(Attendance).filter(Attendance.executive_id == exec_.id).first() is not None
        if has_attendance:
            raise HTTPException(
                status_code=400,
                detail="Cannot delete Field Executive with recorded attendance. Attendance history must be preserved."
            )

        has_eod = db.query(EODReport).filter(EODReport.executive_id == exec_.id).first() is not None
        if has_eod:
            raise HTTPException(
                status_code=400,
                detail="Cannot delete Field Executive with submitted EOD reports. Daily reports must be preserved."
            )

        has_orders = db.query(Order).filter(Order.assigned_executive_id == exec_.id).first() is not None
        if has_orders:
            raise HTTPException(
                status_code=400,
                detail="Cannot delete Field Executive associated with orders. Order assignment history must be preserved."
            )
    else:
        db.query(Order).filter(Order.assigned_executive_id == exec_.id).update(
            {"assigned_executive_id": None}, synchronize_session=False
        )
        db.query(Visit).filter(Visit.executive_id == exec_.id).delete(synchronize_session=False)
        db.query(EODReport).filter(EODReport.executive_id == exec_.id).delete(synchronize_session=False)
        db.query(Attendance).filter(Attendance.executive_id == exec_.id).delete(synchronize_session=False)

    user_id = exec_.user_id
    try:
        # Unlink any shops assigned to this executive
        db.query(ShopOwner).filter(ShopOwner.assigned_executive_id == exec_.id).update(
            {"assigned_executive_id": None}, synchronize_session=False
        )

        # Delete ephemeral telemetry/location records
        db.query(FELocation).filter(FELocation.executive_id == exec_.id).delete(synchronize_session=False)

        # Delete device tokens for the user
        if user_id:
            db.query(FCMDeviceToken).filter(FCMDeviceToken.user_id == user_id).delete(synchronize_session=False)

        # Delete FieldExecutive record
        db.delete(exec_)
        db.flush()

        # Delete associated User record directly without triggering orphan traversal
        if user_id:
            db.query(User).filter(User.id == user_id).delete(synchronize_session=False)

        db.commit()
        return {"success": True, "detail": "Field executive permanently deleted"}
    except HTTPException:
        db.rollback()
        raise
    except Exception as exc:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Database error deleting field executive: {str(exc)}")

@router.get("/me", response_model=EmployeeOut)
@router.get("/me/", response_model=EmployeeOut, include_in_schema=False)
@router.get("/my", response_model=EmployeeOut, include_in_schema=False)
def get_my_profile(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["field_executive"]))
):
    """Get own field executive profile."""
    exec_ = db.query(FieldExecutive).filter(FieldExecutive.user_id == current_user.id).first()
    if not exec_:
        raise HTTPException(status_code=404, detail="Field executive profile not found")
    assigned_shops_query = (
        db.query(ShopOwner)
        .options(joinedload(ShopOwner.user))
        .filter(ShopOwner.assigned_executive_id == exec_.id)
        .order_by(ShopOwner.shop_name.asc())
        .all()
    )
    assigned_shops_list = [
        AssignedShopOut(
            id=s.id,
            shop_name=s.shop_name,
            market_location=s.market_location or "",
            address=s.address or "",
            status=s.status or "Active",
            phone=s.user.phone if s.user else None,
            owner_name=s.user.full_name if s.user else None,
        )
        for s in assigned_shops_query
    ]
    completed_visits_count = db.query(Visit).filter(Visit.executive_id == exec_.id, Visit.status.in_(["Completed", "Visited"])).count()
    pending_visits_count = db.query(Visit).filter(Visit.executive_id == exec_.id, Visit.status.in_(["Pending", "Scheduled", "In Progress"])).count()

    return EmployeeOut(
        id=exec_.id,
        user_id=exec_.user_id,
        username=current_user.username,
        employee_code=exec_.employee_code,
        designation=exec_.designation,
        assigned_territory=exec_.assigned_territory,
        current_lat=exec_.current_lat,
        current_lng=exec_.current_lng,
        battery_level=exec_.battery_level,
        attendance_status=exec_.attendance_status,
        distance_covered_km=exec_.distance_covered_km,
        last_location_update=exec_.last_location_update,
        full_name=current_user.full_name or "",
        phone=current_user.phone,
        email=current_user.email,
        is_active=current_user.is_active,
        assigned_shops=assigned_shops_list,
        total_assigned_shops=len(assigned_shops_list),
        completed_visits=completed_visits_count,
        pending_visits=pending_visits_count,
    )


@router.put("/me", response_model=EmployeeOut)
@router.put("/me/", response_model=EmployeeOut, include_in_schema=False)
@router.put("/my", response_model=EmployeeOut, include_in_schema=False)
def update_my_profile(
    payload: FEProfileUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["field_executive"]))
):
    """Field Executive updates own profile (Task 8).
    Strictly forbids modifying mobile number, username, employee_code, role, or territory."""
    exec_ = db.query(FieldExecutive).filter(FieldExecutive.user_id == current_user.id).first()
    if not exec_:
        raise HTTPException(status_code=404, detail="Field executive profile not found")

    if payload.full_name is not None and payload.full_name.strip():
        current_user.full_name = payload.full_name.strip()

    if payload.email is not None:
        clean_email = payload.email.strip()
        if clean_email:
            existing = db.query(User).filter(User.email == clean_email, User.id != current_user.id).first()
            if existing:
                raise HTTPException(status_code=400, detail="Email address is already in use by another account")
            current_user.email = clean_email
        else:
            current_user.email = None

    db.commit()
    db.refresh(exec_)
    db.refresh(current_user)

    return EmployeeOut(
        id=exec_.id,
        user_id=exec_.user_id,
        username=current_user.username,
        employee_code=exec_.employee_code,
        designation=exec_.designation,
        assigned_territory=exec_.assigned_territory,
        current_lat=exec_.current_lat,
        current_lng=exec_.current_lng,
        battery_level=exec_.battery_level,
        attendance_status=exec_.attendance_status,
        distance_covered_km=exec_.distance_covered_km,
        last_location_update=exec_.last_location_update,
        full_name=current_user.full_name or "",
        phone=current_user.phone,
        email=current_user.email,
        is_active=current_user.is_active,
    )


@router.get("/{employee_id}", response_model=EmployeeOut)
@router.get("/{employee_id}/", response_model=EmployeeOut, include_in_schema=False)
def get_employee(
    employee_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["administrator"]))
):
    """Get a single field executive's profile details with assigned shops and visit metrics — Admin only."""
    exec_ = (
        db.query(FieldExecutive)
        .options(joinedload(FieldExecutive.user))
        .filter(FieldExecutive.id == employee_id)
        .first()
    )
    if not exec_ or not exec_.user:
        raise HTTPException(status_code=404, detail="Field executive not found")

    assigned_shops_query = (
        db.query(ShopOwner)
        .options(joinedload(ShopOwner.user))
        .filter(ShopOwner.assigned_executive_id == exec_.id)
        .order_by(ShopOwner.shop_name.asc())
        .all()
    )
    assigned_shops_list = [
        AssignedShopOut(
            id=s.id,
            shop_name=s.shop_name,
            market_location=s.market_location or "",
            address=s.address or "",
            status=s.status or "Active",
            phone=s.user.phone if s.user else None,
            owner_name=s.user.full_name if s.user else None,
        )
        for s in assigned_shops_query
    ]

    completed_visits_count = (
        db.query(Visit)
        .filter(
            Visit.executive_id == exec_.id,
            Visit.status.in_(["Completed", "Visited"])
        )
        .count()
    )

    pending_visits_count = (
        db.query(Visit)
        .filter(
            Visit.executive_id == exec_.id,
            Visit.status.in_(["Pending", "Scheduled", "In Progress"])
        )
        .count()
    )

    return EmployeeOut(
        id=exec_.id,
        user_id=exec_.user_id,
        username=exec_.user.username if exec_.user else "",
        employee_code=exec_.employee_code,
        designation=exec_.designation or "",
        assigned_territory=exec_.assigned_territory or "",
        current_lat=exec_.current_lat,
        current_lng=exec_.current_lng,
        battery_level=exec_.battery_level if exec_.battery_level is not None else 0,
        attendance_status=exec_.attendance_status or "Present",
        distance_covered_km=exec_.distance_covered_km if exec_.distance_covered_km is not None else 0.0,
        last_location_update=exec_.last_location_update,
        full_name=exec_.user.full_name,
        phone=exec_.user.phone,
        email=exec_.user.email,
        is_active=exec_.user.is_active,
        assigned_shops=assigned_shops_list,
        total_assigned_shops=len(assigned_shops_list),
        completed_visits=completed_visits_count,
        pending_visits=pending_visits_count,
    )


@router.get("/{employee_id}/management-details", response_model=EmployeeOut)
def get_employee_management_details(
    employee_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["administrator"]))
):
    """Admin-authorized FE detail endpoint returning assigned shops and visit metrics."""
    return get_employee(employee_id=employee_id, db=db, current_user=current_user)


@router.put("/{employee_id}", response_model=EmployeeOut)
@router.put("/{employee_id}/", response_model=EmployeeOut, include_in_schema=False)
def update_employee(
    employee_id: int,
    payload: EmployeeAdminUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["administrator"]))
):
    """Update a field executive's profile and credentials — Admin only."""
    user_role = current_user.role.name if (current_user and current_user.role) else ""
    if user_role != "administrator":
        raise HTTPException(status_code=403, detail="Administrator access required")
    from app.api.auth import normalize_phone_number

    exec_ = (
        db.query(FieldExecutive)
        .options(joinedload(FieldExecutive.user))
        .filter(FieldExecutive.id == employee_id)
        .first()
    )
    if not exec_ or not exec_.user:
        raise HTTPException(status_code=404, detail="Field executive not found")

    user = exec_.user

    if payload.full_name is not None and payload.full_name.strip():
        user.full_name = payload.full_name.strip()

    old_phone = user.phone
    if payload.phone is not None:
        norm_phone = normalize_phone_number(payload.phone)
        if not norm_phone or len(norm_phone) != 10:
            raise HTTPException(status_code=400, detail="Phone number must be a valid 10-digit mobile number.")
        existing_phone = db.query(User).filter(User.phone == norm_phone, User.id != user.id).first()
        if existing_phone:
            raise HTTPException(status_code=400, detail=f"Phone number '{norm_phone}' is already in use by another user.")
        user.phone = norm_phone
        from app.core.firebase import sync_firebase_phone
        sync_firebase_phone(old_phone, norm_phone)

    if payload.username is not None and payload.username.strip():
        clean_username = payload.username.strip()
        existing_username = db.query(User).filter(User.username == clean_username, User.id != user.id).first()
        if existing_username:
            raise HTTPException(status_code=400, detail=f"Username '{clean_username}' is already in use.")
        user.username = clean_username

    if payload.email is not None:
        clean_email = payload.email.strip() if payload.email.strip() else None
        if clean_email:
            existing_email = db.query(User).filter(User.email == clean_email, User.id != user.id).first()
            if existing_email:
                raise HTTPException(status_code=400, detail=f"Email '{clean_email}' is already in use.")
        user.email = clean_email

    if payload.employee_code is not None and payload.employee_code.strip():
        clean_code = payload.employee_code.strip()
        existing_code = db.query(FieldExecutive).filter(
            FieldExecutive.employee_code == clean_code,
            FieldExecutive.id != exec_.id
        ).first()
        if existing_code:
            raise HTTPException(status_code=400, detail=f"Employee code '{clean_code}' is already in use.")
        exec_.employee_code = clean_code

    if payload.designation is not None and payload.designation.strip():
        exec_.designation = payload.designation.strip()

    if payload.assigned_territory is not None:
        exec_.assigned_territory = payload.assigned_territory.strip()

    if payload.is_active is not None:
        user.is_active = payload.is_active

    try:
        db.commit()
        db.refresh(exec_)
        db.refresh(user)
    except Exception as exc:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Database error updating field executive: {str(exc)}")

    return get_employee(employee_id=employee_id, db=db, current_user=current_user)


@router.put("/{employee_id}/location")
@router.put("/{employee_id}/location/", include_in_schema=False)
async def update_location(
    employee_id: int,
    payload: LocationUpdateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["field_executive", "administrator"]))
):
    """Update GPS location for a field executive."""
    exec_ = db.query(FieldExecutive).filter(FieldExecutive.id == employee_id).first()
    if not exec_:
        raise HTTPException(status_code=404, detail="Employee not found")

    user_role = current_user.role.name if current_user.role else ""
    if user_role == "field_executive" and exec_.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Access denied: field executives can only update their own location")

    exec_.current_lat = payload.lat
    exec_.current_lng = payload.lng
    now_utc = datetime.utcnow()
    exec_.last_location_update = now_utc
    if payload.battery_level is not None:
        exec_.battery_level = payload.battery_level
    db.commit()

    from app.core.websocket import manager
    from app.models.all_models import Role, User
    import json

    try:
        admins = db.query(User).join(Role).filter(Role.name == "administrator").all()
        allowed_user_ids = [admin.id for admin in admins]

        broadcast_data = {
            "type": "LOCATION_UPDATE",
            "data": {
                "employee_id": exec_.id,
                "lat": exec_.current_lat,
                "lng": exec_.current_lng,
                "battery": exec_.battery_level or 100,
                "last_update": now_utc.isoformat()
            }
        }
        message_str = json.dumps(broadcast_data)

        for u_id in set(allowed_user_ids):
            await manager.send_personal_message(message_str, u_id)

    except Exception as e:
        import logging
        logging.error(f"Error broadcasting location: {e}")

    return {"success": True, "lat": exec_.current_lat, "lng": exec_.current_lng}
