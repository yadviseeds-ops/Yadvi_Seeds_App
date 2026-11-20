from fastapi import APIRouter, Depends, HTTPException, status, Request
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError
from app.core.database import get_db
from app.core.security import create_access_token, get_current_user, require_role, verify_password
from app.models.all_models import User, Role
from app.schemas.auth_schemas import (
    OTPRequest,
    OTPVerifyRequest,
    TokenResponse,
    UserBase,
    RoleCheckResponse,
    AdminProfileUpdate,
)
from app.core.sms import generate_secure_otp, send_sms_otp
from app.core.rate_limiter import (
    get_client_ip,
    verify_user_limiter,
    login_failure_limiter,
    request_otp_limiter,
)
from pydantic import BaseModel
from typing import Optional
import logging

logger = logging.getLogger(__name__)

import time

router = APIRouter(prefix="/auth", tags=["Authentication & RBAC"])

# In-memory OTP store for all users.
# Key: mobile string, Value: {"otp": string, "expires_at": float, "attempts": int}
OTP_STORE = {}

import re

def find_authorized_user(db: Session, clean_username: str, norm_mobile: str) -> Optional[User]:
    """
    Locates an active user by username and phone number.
    Supports primary phone matching for all roles via users.phone,
    as well as authorized secondary phone numbers for the administrator account
    strictly mapped in the admin_phones database table.
    """
    from sqlalchemy import func, or_
    candidates = [norm_mobile, f"+91{norm_mobile}", f"0{norm_mobile}", f"91{norm_mobile}"]
    username_candidates = [clean_username, clean_username.lower(), clean_username.capitalize()]
    if clean_username.lower() in ("shri", "shree"):
        username_candidates.extend(["Shree", "shree", "shri", "Shri"])
    username_candidates = list(set(username_candidates))

    # 1. Primary match on users.phone (case-insensitive username match)
    user = db.query(User).filter(
        or_(
            User.username.in_(username_candidates),
            func.lower(func.trim(User.username)) == clean_username.lower().strip()
        ),
        User.phone.in_(candidates)
    ).first()
    if user and normalize_phone_number(user.phone) == norm_mobile:
        return user

    # 1b. If username had minor variation, match by exact unique registered phone for SO / FE
    potential_user = db.query(User).filter(User.phone.in_(candidates)).first()
    if potential_user and normalize_phone_number(potential_user.phone) == norm_mobile and potential_user.is_active:
        user_role = potential_user.role.name if potential_user.role else ""
        u_name = (potential_user.username or "").lower().strip()
        f_name = (potential_user.full_name or "").lower().strip()
        c_name = clean_username.lower().strip()
        s_name = (potential_user.shop_profile.shop_name if potential_user.shop_profile else "").lower().strip()
        if user_role == "shop_owner":
            if not c_name or c_name == u_name or c_name == f_name or c_name == s_name:
                return potential_user
        elif user_role == "field_executive":
            if c_name and (c_name == u_name or c_name == f_name or (c_name in ("shri", "shree") and u_name in ("shri", "shree"))):
                return potential_user

    # 2. Authoritative database mapping check via admin_phones table
    try:
        from app.models.all_models import AdminPhone
        admin_phone_entry = db.query(AdminPhone).filter(
            AdminPhone.phone.in_(candidates),
            AdminPhone.is_active == True
        ).first()
        if admin_phone_entry:
            admin_user = db.query(User).filter(
                User.id == admin_phone_entry.user_id,
                User.username == clean_username,
                User.is_active == True
            ).first()
            if admin_user and admin_user.role and admin_user.role.name == "administrator":
                return admin_user
    except Exception as e:
        logger.debug(f"AdminPhone mapping lookup skipped or table not initialized: {e}")

    return None

def normalize_phone_number(phone: str) -> str:
    """
    Normalizes a phone number to standard 10-digit format for India.
    Strips country code (+91 or 91), leading 0s, spaces, hyphens, and symbols.
    """
    if not phone:
        return ""
    digits = re.sub(r"\D", "", phone.strip())
    if len(digits) == 12 and digits.startswith("91"):
        digits = digits[2:]
    elif len(digits) == 11 and digits.startswith("0"):
        digits = digits[1:]
    return digits

def normalize_role(role_str: str) -> str:
    cleaned = role_str.strip().lower().replace(" ", "_")
    if cleaned in ["administrator", "admin"]:
        return "administrator"
    elif cleaned in ["field_executive", "field", "executive"]:
        return "field_executive"
    elif cleaned in ["shop_owner", "shop", "dealer"]:
        return "shop_owner"
    return cleaned

def _create_token_response(user: User) -> TokenResponse:
    user_actual_role = user.role.name if user.role else ""
    redirect_map = {
        "administrator": "/admin",
        "field_executive": "/field-executive",
        "shop_owner": "/shop-owner"
    }

    metadata = {}
    if user_actual_role == "shop_owner" and user.shop_profile:
        metadata["shop_name"] = user.shop_profile.shop_name
        metadata["shop_id"] = user.shop_profile.id
    elif user_actual_role == "field_executive" and user.field_profile:
        metadata["employee_code"] = user.field_profile.employee_code
        metadata["assigned_territory"] = user.field_profile.assigned_territory

    effective_name = user.full_name or user.username or (
        "Shop Owner" if user_actual_role == "shop_owner" else
        "Field Executive" if user_actual_role == "field_executive" else
        "Administrator"
    )

    access_token = create_access_token(
        data={
            "sub": str(user.id),
            "role": user_actual_role,
            "name": effective_name
        }
    )

    return TokenResponse(
        access_token=access_token,
        token_type="bearer",
        role=user_actual_role,
        user_id=user.id,
        full_name=effective_name,
        redirect_path=redirect_map.get(user_actual_role, "/admin"),
        metadata=metadata
    )

class LoginRequest(BaseModel):
    username: str
    password: str

class VerifyUserRequest(BaseModel):
    username: Optional[str] = ""
    mobile: str
    expected_role: Optional[str] = None

@router.post("/verify-user")
def verify_user(
    request: VerifyUserRequest,
    req: Request,
    db: Session = Depends(get_db)
):
    client_ip = get_client_ip(req)
    # Rate limit: maximum 10 requests per IP per 60 seconds
    allowed, retry_after = verify_user_limiter.check_and_record(
        client_ip, max_requests=10, window_seconds=60
    )
    if not allowed:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Too many verification attempts from this IP. Please try again after {retry_after} seconds.",
            headers={"Retry-After": str(retry_after)}
        )

    clean_username = (request.username or "").strip()
    norm_mobile = normalize_phone_number(request.mobile)

    # Standardized generic error detail for all failures (Anti-Enumeration defense)
    generic_error = "Invalid username, phone number, or role."

    if not norm_mobile or len(norm_mobile) != 10:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=generic_error
        )

    if request.expected_role:
        norm_expected = normalize_role(request.expected_role)
        if norm_expected in ("administrator", "field_executive") and not clean_username:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=generic_error
            )

    user = find_authorized_user(db, clean_username, norm_mobile)

    if not user or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=generic_error
        )

    if request.expected_role:
        norm_expected = normalize_role(request.expected_role)
        user_actual_role = user.role.name if user.role else ""
        if user_actual_role != norm_expected:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=generic_error
            )
        if norm_expected == "shop_owner" and not user.shop_profile:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Shop profile not found for this account. Please register your shop via Admin."
            )
        if norm_expected == "field_executive" and not user.field_profile:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Field executive profile not found for this account. Please contact administrator."
            )

    return {"status": "success", "message": "User verified"}

class FirebaseLoginRequest(BaseModel):
    username: Optional[str] = ""
    mobile: str
    firebase_id_token: str

@router.post("/login-firebase", response_model=TokenResponse)
def login_firebase(request: FirebaseLoginRequest, db: Session = Depends(get_db)):
    clean_username = (request.username or "").strip()
    norm_mobile = normalize_phone_number(request.mobile)

    if not norm_mobile or len(norm_mobile) != 10:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials."
        )

    # 1. Verify User exists in DB and is active
    user = find_authorized_user(db, clean_username, norm_mobile)

    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials."
        )

    if not clean_username and user.role and user.role.name in ("administrator", "field_executive"):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials."
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Account is inactive. Please contact administrator."
        )

    # 2. Verify Firebase Token using Admin SDK
    try:
        from firebase_admin import auth as fb_auth
        decoded_token = fb_auth.verify_id_token(request.firebase_id_token)
        firebase_phone = decoded_token.get("phone_number", "")
        norm_firebase_phone = normalize_phone_number(firebase_phone)

        # Validate that the authenticated firebase phone matches the requested mobile exactly
        if not norm_firebase_phone or norm_firebase_phone != norm_mobile:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Firebase phone number mismatch. Authentication rejected."
            )
    except HTTPException:
        raise
    except ImportError:
        logger.warning("firebase_admin not installed.")
        raise HTTPException(status_code=500, detail="Firebase Admin SDK missing.")
    except ValueError as e:
        logger.error(f"Firebase Admin configuration error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Firebase authentication service is not configured correctly."
        )
    except Exception as e:
        logger.error(f"Firebase token verification failed: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired Firebase authentication token."
        )

    # 3. Create Session (always from database role, client role is not accepted)
    user_actual_role = user.role.name if user.role else ""
    if user_actual_role == "shop_owner" and not user.shop_profile:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Shop profile not found for this account. Please register your shop via Admin."
        )
    if user_actual_role == "field_executive" and not user.field_profile:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Field executive profile not found for this account. Please contact administrator."
        )

    return _create_token_response(user)

@router.post("/request-otp")
def request_otp(
    request: OTPRequest,
    req: Request,
    db: Session = Depends(get_db)
):
    client_ip = get_client_ip(req)
    # Rate limit: maximum 3 requests per IP per 10 minutes (600 seconds)
    allowed, retry_after = request_otp_limiter.check_and_record(
        client_ip, max_requests=3, window_seconds=600
    )
    if not allowed:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Too many OTP requests from this IP. Please try again after {retry_after} seconds.",
            headers={"Retry-After": str(retry_after)}
        )

    clean_username = request.username.strip()
    norm_mobile = normalize_phone_number(request.mobile)

    if not norm_mobile or len(norm_mobile) != 10:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or registered mobile number."
        )

    # DB validation: username, exact mobile match, active account
    user = find_authorized_user(db, clean_username, norm_mobile)

    if not user or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or registered mobile number."
        )

    user_role = user.role.name if user.role else ""
    if user_role == "shop_owner" and not user.shop_profile:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Shop profile not found for this account. Please register your shop via Admin."
        )
    if user_role == "field_executive" and not user.field_profile:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Field executive profile not found for this account. Please contact administrator."
        )

    # Cooldown check: preserve existing per-phone 60-second cooldown
    now = time.time()
    existing_otp = OTP_STORE.get(norm_mobile)
    if existing_otp and now < existing_otp["expires_at"] - 240: # 1 min cooldown
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Please wait before requesting a new OTP."
        )

    # Generate and store OTP
    otp = generate_secure_otp()
    OTP_STORE[norm_mobile] = {
        "otp": otp,
        "expires_at": now + 300, # 5 minutes expiry
        "attempts": 0
    }

    # Send via SMS provider
    success = send_sms_otp(norm_mobile, otp)
    if not success:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to send SMS. Please check SMS provider configuration."
        )

    return {
        "message": "If the credentials are valid, an OTP has been sent.",
        "otp_required": True
    }

@router.post("/verify-otp", response_model=TokenResponse)
def verify_otp(request: OTPVerifyRequest, db: Session = Depends(get_db)):
    clean_username = request.username.strip()
    norm_mobile = normalize_phone_number(request.mobile)

    if not norm_mobile or len(norm_mobile) != 10:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials."
        )

    # Validate User
    user = find_authorized_user(db, clean_username, norm_mobile)

    if not user or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials."
        )

    otp_data = OTP_STORE.get(norm_mobile)
    now = time.time()

    if not otp_data:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="No active OTP found. Please request a new one."
        )

    if now > otp_data["expires_at"]:
        del OTP_STORE[norm_mobile]
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="OTP has expired. Please request a new one."
        )

    if otp_data["attempts"] >= 3:
        del OTP_STORE[norm_mobile]
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Too many invalid attempts. Please request a new OTP."
        )

    if request.otp != otp_data["otp"]:
        otp_data["attempts"] += 1
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect OTP."
        )

    # Success, clear OTP
    del OTP_STORE[norm_mobile]
    return _create_token_response(user)

@router.post("/login", response_model=TokenResponse)
def login_password(
    request: LoginRequest,
    req: Request,
    db: Session = Depends(get_db)
):
    """Password-based login for Administrator and users with configured passwords."""
    client_ip = get_client_ip(req)

    # Rate limit: maximum 5 failed login attempts per IP per 5 minutes (300 seconds)
    allowed, retry_after = login_failure_limiter.is_allowed(
        client_ip, max_requests=5, window_seconds=300
    )
    if not allowed:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Too many failed login attempts from this IP. Please try again after {retry_after} seconds.",
            headers={"Retry-After": str(retry_after)}
        )

    clean_identifier = request.username.strip()
    clean_mobile = clean_identifier.replace(" ", "").replace("+91", "")
    username_candidates = [clean_identifier]
    if clean_identifier.lower() in ("shri", "shree"):
        username_candidates = ["Shree", "shree", "shri", "Shri"]

    user = db.query(User).filter(
        (User.username.in_(username_candidates)) | (User.phone == clean_identifier) | (User.phone.like(f"%{clean_mobile}%"))
    ).first()

    if not user:
        try:
            from app.models.all_models import AdminPhone
            norm_cands = [clean_mobile, f"+91{clean_mobile}", f"0{clean_mobile}", f"91{clean_mobile}"]
            admin_phone_entry = db.query(AdminPhone).filter(
                AdminPhone.phone.in_(norm_cands),
                AdminPhone.is_active == True
            ).first()
            if admin_phone_entry:
                user = db.query(User).filter(
                    User.id == admin_phone_entry.user_id,
                    User.is_active == True
                ).first()
        except Exception:
            pass

    if not user or not user.is_active:
        login_failure_limiter.record_hit(client_ip, window_seconds=300)
        logger.warning(f"Login failed: user not found or inactive for {clean_identifier} (user={user})")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password."
        )

    if not user.hashed_password or not verify_password(request.password, user.hashed_password):
        login_failure_limiter.record_hit(client_ip, window_seconds=300)
        logger.warning(f"Login failed: password mismatch for {clean_identifier} (has_hash={bool(user.hashed_password)})")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password."
        )

    # Successful login: do NOT record a failure hit
    return _create_token_response(user)


@router.post("/token", response_model=TokenResponse)
def login_oauth2(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    """
    OAuth2 Password Form endpoint for Swagger UI (/docs) and OAuth2 clients.
    Authenticates via username/phone and password hash.
    Falls back to OTP in the password field for backward compatibility.
    """
    clean_identifier = form_data.username.strip()
    clean_mobile = clean_identifier.replace(" ", "").replace("+91", "")
    username_candidates = [clean_identifier]
    if clean_identifier.lower() in ("shri", "shree"):
        username_candidates = ["Shree", "shree", "shri", "Shri"]

    user = db.query(User).filter(
        (User.username.in_(username_candidates)) | (User.phone == clean_identifier) | (User.phone.like(f"%{clean_mobile}%"))
    ).first()

    if not user:
        try:
            from app.models.all_models import AdminPhone
            norm_cands = [clean_mobile, f"+91{clean_mobile}", f"0{clean_mobile}", f"91{clean_mobile}"]
            admin_phone_entry = db.query(AdminPhone).filter(
                AdminPhone.phone.in_(norm_cands),
                AdminPhone.is_active == True
            ).first()
            if admin_phone_entry:
                user = db.query(User).filter(
                    User.id == admin_phone_entry.user_id,
                    User.is_active == True
                ).first()
        except Exception:
            pass

    if not user or not user.is_active:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials.")

    # 1. Try standard password authentication
    if user.hashed_password and verify_password(form_data.password, user.hashed_password):
        return _create_token_response(user)

    # 2. Backward compatibility fallback: check if password field was an active OTP
    otp_data = OTP_STORE.get(clean_mobile)
    if otp_data and form_data.password == otp_data.get("otp"):
        del OTP_STORE[clean_mobile]
        return _create_token_response(user)

    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid credentials. For password login, enter your registered password. For OTP login, generate an OTP first via /auth/request-otp."
    )

@router.get("/me", response_model=UserBase)
def get_current_user_profile(current_user: User = Depends(get_current_user)):
    return UserBase(
        id=current_user.id,
        full_name=current_user.full_name,
        username=current_user.username,
        phone=current_user.phone,
        email=current_user.email,
        role=current_user.role.name if current_user.role else "unknown",
        is_active=current_user.is_active
    )

@router.put("/me", response_model=UserBase)
def update_current_user_profile(
    payload: AdminProfileUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["administrator"]))
):
    # 1. Update Full Name if provided
    if payload.full_name is not None:
        cleaned_name = payload.full_name.strip()
        if not cleaned_name:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Full name cannot be empty.")
        current_user.full_name = cleaned_name

    # 2. Update Username if provided
    if payload.username is not None:
        cleaned_username = payload.username.strip()
        if not cleaned_username or len(cleaned_username) < 3:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Username must be at least 3 characters.")
        if cleaned_username != current_user.username:
            existing = db.query(User).filter(User.username == cleaned_username, User.id != current_user.id).first()
            if existing:
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Username '{cleaned_username}' is already in use.")
            current_user.username = cleaned_username

    # 3. Update Email if provided
    if payload.email is not None:
        cleaned_email = payload.email.strip().lower()
        if cleaned_email:
            email_regex = r"^[^@\s]+@[^@\s]+\.[^@\s]+$"
            if not re.match(email_regex, cleaned_email):
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid email format.")
            existing = db.query(User).filter(User.email == cleaned_email, User.id != current_user.id).first()
            if existing:
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Email is already in use by another account.")
            current_user.email = cleaned_email
        else:
            current_user.email = None

    # 4. Update Mobile Number if provided (strictly requires verified Firebase ID token)
    if payload.new_phone is not None:
        norm_new_phone = normalize_phone_number(payload.new_phone)
        if not norm_new_phone or len(norm_new_phone) != 10:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid mobile number format. Must be a 10-digit number.")
        if norm_new_phone != normalize_phone_number(current_user.phone):
            if not payload.firebase_id_token:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Changing mobile number requires SMS OTP verification. A valid Firebase ID token is required."
                )
            # Verify Firebase ID token
            try:
                from firebase_admin import auth as fb_auth
                decoded_token = fb_auth.verify_id_token(payload.firebase_id_token)
                fb_phone = decoded_token.get("phone_number", "")
                norm_fb_phone = normalize_phone_number(fb_phone)
                if norm_fb_phone != norm_new_phone:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="Firebase verified phone number does not match requested new mobile number."
                    )
            except HTTPException:
                raise
            except Exception as e:
                logger.error(f"Phone verification failed during profile update: {e}")
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Firebase phone verification failed: {str(e)}"
                )

            # 1. Uniqueness check across users table
            candidates = [norm_new_phone, f"+91{norm_new_phone}", f"0{norm_new_phone}", f"91{norm_new_phone}"]
            existing_user = db.query(User).filter(User.phone.in_(candidates), User.id != current_user.id).first()
            if existing_user:
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Mobile number is already registered to another user.")

            # 2. Uniqueness check across admin_phones table
            try:
                from app.models.all_models import AdminPhone
                # Check if new phone is mapped to another admin
                existing_admin_other = db.query(AdminPhone).filter(
                    AdminPhone.phone.in_(candidates),
                    AdminPhone.user_id != current_user.id
                ).first()
                if existing_admin_other:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="Mobile number is already registered as an authorized administrator phone."
                    )

                old_phone = current_user.phone
                old_norm = normalize_phone_number(old_phone)
                old_candidates = [old_norm, f"+91{old_norm}", f"0{old_norm}", f"91{old_norm}"]

                # Check if new phone is already registered as a secondary phone for this user
                existing_admin_self = db.query(AdminPhone).filter(
                    AdminPhone.phone.in_(candidates),
                    AdminPhone.user_id == current_user.id,
                    ~AdminPhone.phone.in_(old_candidates)
                ).first()
                if existing_admin_self:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail="Mobile number is already registered as an authorized phone for your account."
                    )

                # Update users.phone
                current_user.phone = norm_new_phone

                # Update ONLY the exact AdminPhone record that matched the old phone being replaced,
                # preserving all other secondary admin phone records!
                matching_admin_phone = db.query(AdminPhone).filter(
                    AdminPhone.user_id == current_user.id,
                    AdminPhone.phone.in_(old_candidates)
                ).first()
                if matching_admin_phone:
                    matching_admin_phone.phone = norm_new_phone
            except HTTPException:
                raise
            except Exception as e:
                logger.debug(f"AdminPhone uniqueness/matching skipped: {e}")
                current_user.phone = norm_new_phone

    try:
        db.commit()
        db.refresh(current_user)
    except IntegrityError as ie:
        db.rollback()
        logger.warning(f"IntegrityError updating admin profile for user {current_user.id}: {ie}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Profile update failed due to a uniqueness constraint violation (username, email, or phone number already in use)."
        )
    except Exception as e:
        db.rollback()
        logger.error(f"Unexpected database error updating admin profile for user {current_user.id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to update profile due to an internal database error."
        )

    return UserBase(
        id=current_user.id,
        full_name=current_user.full_name,
        username=current_user.username,
        phone=current_user.phone,
        email=current_user.email,
        role=current_user.role.name if current_user.role else "unknown",
        is_active=current_user.is_active
    )

# Role Boundary Enforcement Test Endpoints
@router.get("/test/admin-only", response_model=RoleCheckResponse)
def test_admin_access(current_user: User = Depends(require_role(["administrator"]))):
    return RoleCheckResponse(
        authorized=True,
        role="administrator",
        user_name=current_user.full_name,
        message="Authorized: Administrator has full portal access."
    )

@router.get("/test/field-only", response_model=RoleCheckResponse)
def test_field_access(current_user: User = Depends(require_role(["field_executive", "administrator"]))):
    return RoleCheckResponse(
        authorized=True,
        role=current_user.role.name,
        user_name=current_user.full_name,
        message="Authorized: Field Executive route accessed."
    )

@router.get("/test/shop-only", response_model=RoleCheckResponse)
def test_shop_access(current_user: User = Depends(require_role(["shop_owner", "administrator"]))):
    return RoleCheckResponse(
        authorized=True,
        role=current_user.role.name,
        user_name=current_user.full_name,
        message="Authorized: Shop Owner route accessed."
    )

class FCMTokenRequest(BaseModel):
    token: str
    platform: str = "android"

@router.post("/fcm-token")
def register_fcm_token(request: FCMTokenRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    from app.models.all_models import FCMDeviceToken

    # Check if token exists
    existing = db.query(FCMDeviceToken).filter(FCMDeviceToken.device_token == request.token).first()

    if existing:
        if existing.user_id != current_user.id:
            existing.user_id = current_user.id
            existing.is_active = True
            db.commit()
    else:
        new_token = FCMDeviceToken(
            user_id=current_user.id,
            device_token=request.token,
            platform=request.platform,
            is_active=True
        )
        db.add(new_token)
        db.commit()

    return {"status": "success", "message": "FCM Token registered"}


class WebSocketTicketResponse(BaseModel):
    ticket: str
    expires_in: int


@router.post("/ws-ticket", response_model=WebSocketTicketResponse)
def get_websocket_ticket(current_user: User = Depends(get_current_user)):
    """
    Issues a short-lived (60s), single-use connection ticket for WebSocket authentication.
    Prevents long-lived bearer JWTs from leaking into URL query string parameters and proxy logs.
    """
    from app.core.websocket import ticket_manager

    ticket = ticket_manager.issue_ticket(current_user.id)
    return WebSocketTicketResponse(
        ticket=ticket,
        expires_in=ticket_manager.ttl_seconds
    )
