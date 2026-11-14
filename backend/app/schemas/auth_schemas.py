from pydantic import BaseModel, EmailStr
from typing import Optional
from enum import Enum

class RoleType(str, Enum):
    ADMINISTRATOR = "administrator"
    FIELD_EXECUTIVE = "field_executive"
    SHOP_OWNER = "shop_owner"

class OTPRequest(BaseModel):
    username: str
    mobile: str

class OTPVerifyRequest(BaseModel):
    username: str
    mobile: str
    otp: str

class UserBase(BaseModel):
    id: int
    full_name: Optional[str] = None
    username: Optional[str] = None
    phone: str
    email: Optional[str] = None
    role: str
    is_active: bool

class AdminProfileUpdate(BaseModel):
    full_name: Optional[str] = None
    username: Optional[str] = None
    email: Optional[str] = None
    new_phone: Optional[str] = None
    firebase_id_token: Optional[str] = None

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    role: str
    user_id: int
    full_name: Optional[str] = None
    redirect_path: str  # /admin, /field-executive, /shop-owner
    metadata: Optional[dict] = None

class RoleCheckResponse(BaseModel):
    authorized: bool
    role: str
    user_name: str
    message: str
