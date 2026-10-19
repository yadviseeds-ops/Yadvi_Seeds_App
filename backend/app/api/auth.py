from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.security import create_access_token, get_current_user, require_role, verify_password
from app.models.all_models import User, Role
from app.schemas.auth_schemas import OTPRequest, OTPVerifyRequest, TokenResponse, UserBase, RoleCheckResponse
from app.core.sms import generate_secure_otp, send_sms_otp
from pydantic import BaseModel
import logging

logger = logging.getLogger(__name__)

import time

router = APIRouter(prefix="/auth", tags=["Authentication & RBAC"])

# In-memory OTP store for all users.
# Key: mobile string, Value: {"otp": string, "expires_at": float, "attempts": int}
OTP_STORE = {}

import re

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

    access_token = create_access_token(
        data={
            "sub": str(user.id),
            "role": user_actual_role,
            "name": user.full_name
        }
    )

    return TokenResponse(
        access_token=access_token,
        token_type="bearer",
        role=user_actual_role,
        user_id=user.id,
        full_name=user.full_name,
        redirect_path=redirect_map.get(user_actual_role, "/admin"),
        metadata=metadata
    )

class LoginRequest(BaseModel):
    username: str
    password: str

class VerifyUserRequest(BaseModel):
    username: str
    mobile: str

@router.post("/verify-user")
def verify_user(request: VerifyUserRequest, db: Session = Depends(get_db)):
    clean_username = request.username.strip()
    norm_mobile = normalize_phone_number(request.mobile)

    if not norm_mobile or len(norm_mobile) != 10:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or registered mobile number."
        )

    candidates = [norm_mobile, f"+91{norm_mobile}", f"0{norm_mobile}", f"91{norm_mobile}"]
    user = db.query(User).filter(
        User.username == clean_username,
        User.phone.in_(candidates)
    ).first()

    if not user or normalize_phone_number(user.phone) != norm_mobile or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or registered mobile number."
        )
    return {"status": "success", "message": "User verified"}

class FirebaseLoginRequest(BaseModel):
    username: str
    mobile: str
    firebase_id_token: str

@router.post("/login-firebase", response_model=TokenResponse)
def login_firebase(request: FirebaseLoginRequest, db: Session = Depends(get_db)):
    clean_username = request.username.strip()
    norm_mobile = normalize_phone_number(request.mobile)

    if not norm_mobile or len(norm_mobile) != 10:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials."
        )

    # 1. Verify User exists in DB and is active (exact phone match, no substring match)
    candidates = [norm_mobile, f"+91{norm_mobile}", f"0{norm_mobile}", f"91{norm_mobile}"]
    user = db.query(User).filter(
        User.username == clean_username,
        User.phone.in_(candidates)
    ).first()

    if not user or normalize_phone_number(user.phone) != norm_mobile:
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
    return _create_token_response(user)

@router.post("/request-otp")
def request_otp(request: OTPRequest, db: Session = Depends(get_db)):
    clean_username = request.username.strip()
    norm_mobile = normalize_phone_number(request.mobile)

    if not norm_mobile or len(norm_mobile) != 10:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or registered mobile number."
        )

    # DB validation: username, exact mobile match, active account
    candidates = [norm_mobile, f"+91{norm_mobile}", f"0{norm_mobile}", f"91{norm_mobile}"]
    user = db.query(User).filter(
        User.username == clean_username,
        User.phone.in_(candidates)
    ).first()

    if not user or normalize_phone_number(user.phone) != norm_mobile or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or registered mobile number."
        )

    # Cooldown check
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
    candidates = [norm_mobile, f"+91{norm_mobile}", f"0{norm_mobile}", f"91{norm_mobile}"]
    user = db.query(User).filter(
        User.username == clean_username,
        User.phone.in_(candidates)
    ).first()

    if not user or normalize_phone_number(user.phone) != norm_mobile or not user.is_active:
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
def login_password(request: LoginRequest, db: Session = Depends(get_db)):
    """Password-based login for Administrator and users with configured passwords."""
    clean_identifier = request.username.strip()
    clean_mobile = clean_identifier.replace(" ", "").replace("+91", "")

    user = db.query(User).filter(
        (User.username == clean_identifier) | (User.phone == clean_identifier) | (User.phone.like(f"%{clean_mobile}%"))
    ).first()

    if not user or not user.is_active:
        logger.warning(f"Login failed: user not found or inactive for {clean_identifier} (user={user})")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password."
        )

    if not user.hashed_password or not verify_password(request.password, user.hashed_password):
        logger.warning(f"Login failed: password mismatch for {clean_identifier} (has_hash={bool(user.hashed_password)})")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password."
        )

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

    user = db.query(User).filter(
        (User.username == clean_identifier) | (User.phone == clean_identifier) | (User.phone.like(f"%{clean_mobile}%"))
    ).first()

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
