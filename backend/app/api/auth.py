from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.security import create_access_token, get_current_user, require_role
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

def normalize_role(role_str: str) -> str:
    cleaned = role_str.strip().lower().replace(" ", "_")
    if cleaned in ["administrator", "admin"]:
        return "administrator"
    elif cleaned in ["field_executive", "field", "executive"]:
        return "field_executive"
    elif cleaned in ["shop_owner", "shop", "dealer"]:
        return "shop_owner"
    return cleaned

class VerifyUserRequest(BaseModel):
    username: str
    mobile: str

@router.post("/verify-user")
def verify_user(request: VerifyUserRequest, db: Session = Depends(get_db)):
    clean_mobile = request.mobile.strip().replace(" ", "").replace("+91", "")
    clean_username = request.username.strip()

    user = db.query(User).filter(
        User.username == clean_username,
        User.phone.like(f"%{clean_mobile}%")
    ).first()

    if not user or not user.is_active:
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
    clean_mobile = request.mobile.strip().replace(" ", "").replace("+91", "")
    clean_username = request.username.strip()

    # 1. Verify User exists in DB
    user = db.query(User).filter(
        User.username == clean_username,
        User.phone.like(f"%{clean_mobile}%")
    ).first()

    if not user or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials."
        )

    # 2. Verify Firebase Token using Admin SDK
    try:
        from firebase_admin import auth as fb_auth
        decoded_token = fb_auth.verify_id_token(request.firebase_id_token)
        firebase_phone = decoded_token.get("phone_number", "")
        # Validate that the firebase phone matches the requested mobile
        if clean_mobile not in firebase_phone:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Firebase phone number mismatch. Authentication rejected."
            )
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

    # 3. Create Session
    user_actual_role = user.role.name if user.role else ""
    redirect_map = {
        "administrator": "/admin",
        "field_executive": "/field-executive",
        "shop_owner": "/shop-owner"
    }

    metadata = {}
    if user_actual_role == "shop_owner" and user.shop_profile:
        metadata["shop_name"] = user.shop_profile.shop_name
        metadata["dealer_code"] = user.shop_profile.dealer_code
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

@router.post("/request-otp")
def request_otp(request: OTPRequest, db: Session = Depends(get_db)):
    clean_mobile = request.mobile.strip().replace(" ", "").replace("+91", "")
    clean_username = request.username.strip()

    # DB validation: username, mobile match, active account
    user = db.query(User).filter(
        User.username == clean_username,
        User.phone.like(f"%{clean_mobile}%")
    ).first()

    if not user or not user.is_active:
        # Generic safe error
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or registered mobile number."
        )

    # Cooldown check
    now = time.time()
    existing_otp = OTP_STORE.get(clean_mobile)
    if existing_otp and now < existing_otp["expires_at"] - 240: # 1 min cooldown
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Please wait before requesting a new OTP."
        )

    # Generate and store OTP
    otp = generate_secure_otp()
    OTP_STORE[clean_mobile] = {
        "otp": otp,
        "expires_at": now + 300, # 5 minutes expiry
        "attempts": 0
    }

    # Send via SMS provider
    success = send_sms_otp(clean_mobile, otp)
    if not success:
        # During local dev without config, sms provider returns False but we still want to proceed for dev testing,
        # Wait, requirement says: "Do NOT silently pretend that an SMS was sent. Return a clear configuration error. Do not expose the OTP."
        # BUT we must test this. If we return error, we can't login locally. Let's just print to console ONLY IF local dev?
        # Requirement says: "Do not print OTP to console".
        # I will raise an error if sending fails. To test, user MUST provide SMS_PROVIDER env var,
        # OR we temporarily bypass if a specific dev flag is on.
        # "Use the actual provider only after credentials/configuration are available."
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
    clean_mobile = request.mobile.strip().replace(" ", "").replace("+91", "")
    clean_username = request.username.strip()

    # Validate User
    user = db.query(User).filter(
        User.username == clean_username,
        User.phone.like(f"%{clean_mobile}%")
    ).first()

    if not user or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials."
        )

    otp_data = OTP_STORE.get(clean_mobile)
    now = time.time()

    if not otp_data:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="No active OTP found. Please request a new one."
        )

    if now > otp_data["expires_at"]:
        del OTP_STORE[clean_mobile]
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="OTP has expired. Please request a new one."
        )

    if otp_data["attempts"] >= 3:
        del OTP_STORE[clean_mobile]
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
    del OTP_STORE[clean_mobile]

    user_actual_role = user.role.name if user.role else ""
    redirect_map = {
        "administrator": "/admin",
        "field_executive": "/field-executive",
        "shop_owner": "/shop-owner"
    }

    metadata = {}
    if user_actual_role == "shop_owner" and user.shop_profile:
        metadata["shop_name"] = user.shop_profile.shop_name
        metadata["dealer_code"] = user.shop_profile.dealer_code
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

# Legacy /token for Swagger UI compatibility (using OTP in password field)
@router.post("/token", response_model=TokenResponse)
def login_swagger(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    # In Swagger, username field = mobile, password field = OTP (since we don't use passwords anymore)
    # This is ONLY for Swagger UI testing ease.
    clean_mobile = form_data.username.strip().replace(" ", "").replace("+91", "")

    user = db.query(User).filter(
        User.phone.like(f"%{clean_mobile}%")
    ).first()

    if not user or not user.is_active:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid mobile number or inactive account")

    # Verify OTP
    otp_data = OTP_STORE.get(clean_mobile)
    if not otp_data or form_data.password != otp_data["otp"]:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="OTP required. Please generate OTP first via /auth/request-otp, then enter it as password."
        )
    del OTP_STORE[clean_mobile]

    user_actual_role = user.role.name if user.role else ""
    access_token = create_access_token(
        data={"sub": str(user.id), "role": user_actual_role, "name": user.full_name}
    )
    return TokenResponse(
        access_token=access_token,
        token_type="bearer",
        role=user_actual_role,
        user_id=user.id,
        full_name=user.full_name,
        redirect_path="/",
        metadata={}
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
