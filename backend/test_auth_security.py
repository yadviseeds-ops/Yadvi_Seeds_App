"""
YADVI Hybrid Seeds - Comprehensive Authentication & Authorization Security Test Suite
Tests:
1. Password login with correct & incorrect credentials.
2. Swagger OAuth2 form authentication.
3. OTP lifecycle, expiry, and removal of hardcoded 123456 backdoor.
4. Token validation (missing, expired, malformed).
5. RBAC role enforcement across all 3 roles (Administrator, Field Executive, Shop Owner).
6. Employee location IDOR prevention.
"""

import sys
import asyncio
import time
import httpx
from unittest.mock import patch
from app.main import app
from app.core.database import SessionLocal
from app.models.all_models import User, Role, FieldExecutive, ShopOwner
from app.core.security import create_access_token, verify_password, get_password_hash
from app.api.auth import OTP_STORE


async def run_auth_security_tests():
    db = SessionLocal()
    transport = httpx.ASGITransport(app=app)

    async with httpx.AsyncClient(transport=transport, base_url="http://testserver") as client:
        print("\n=== STARTING AUTHENTICATION & RBAC SECURITY TESTS ===\n")

        # ---------------------------------------------------------
        # Setup: Verify/Retrieve Test Accounts
        # ---------------------------------------------------------
        admin_user = db.query(User).filter(User.role.has(name="administrator")).first()
        fe_user = db.query(User).filter(User.role.has(name="field_executive")).first()
        shop_user = db.query(User).filter(User.role.has(name="shop_owner")).first()

        assert admin_user is not None, "Admin user must exist"
        assert fe_user is not None, "Field Executive user must exist"
        assert shop_user is not None, "Shop Owner user must exist"

        fe_profile = db.query(FieldExecutive).filter(FieldExecutive.user_id == fe_user.id).first()
        assert fe_profile is not None, "Field Executive profile must exist"

        # Find or create a second FE to test IDOR
        other_fe = db.query(FieldExecutive).filter(FieldExecutive.id != fe_profile.id).first()
        if not other_fe:
            # Create a mock other FE ID for IDOR testing
            other_fe_id = fe_profile.id + 999
        else:
            other_fe_id = other_fe.id

        # ---------------------------------------------------------
        # Test 1: Admin Password Login (POST /api/v1/auth/login)
        # ---------------------------------------------------------
        # 1a. Correct password (admin123 seeded)
        res = await client.post("/api/v1/auth/login", json={
            "username": "ADMIN",
            "password": "admin123"
        })
        assert res.status_code == 200, f"Expected 200, got {res.status_code}: {res.text}"
        data = res.json()
        assert "access_token" in data
        assert data["role"] == "administrator"
        print("[PASS] 1a. Password login with correct password -> 200 OK")

        # 1b. Correct password using phone number as identifier
        res = await client.post("/api/v1/auth/login", json={
            "username": admin_user.phone,
            "password": "admin123"
        })
        assert res.status_code == 200, f"Expected 200, got {res.status_code}"
        print("[PASS] 1b. Password login using mobile as identifier -> 200 OK")

        # 1c. Incorrect password
        res = await client.post("/api/v1/auth/login", json={
            "username": "ADMIN",
            "password": "wrong_password_xyz"
        })
        assert res.status_code == 401, f"Expected 401, got {res.status_code}"
        print("[PASS] 1c. Password login with incorrect password -> 401 Unauthorized")

        # 1d. Non-existent username
        res = await client.post("/api/v1/auth/login", json={
            "username": "NON_EXISTENT_USER",
            "password": "any_password"
        })
        assert res.status_code == 401, f"Expected 401, got {res.status_code}"
        print("[PASS] 1d. Password login with non-existent user -> 401 Unauthorized")

        # ---------------------------------------------------------
        # Test 2: Swagger OAuth2 Token Endpoint (POST /api/v1/auth/token)
        # ---------------------------------------------------------
        # 2a. Swagger login with valid password
        res = await client.post(
            "/api/v1/auth/token",
            data={"username": "ADMIN", "password": "admin123"},
            headers={"Content-Type": "application/x-www-form-urlencoded"}
        )
        assert res.status_code == 200, f"Expected 200, got {res.status_code}: {res.text}"
        assert "access_token" in res.json()
        print("[PASS] 2a. Swagger OAuth2 form login with password -> 200 OK")

        # 2b. Swagger login with invalid password
        res = await client.post(
            "/api/v1/auth/token",
            data={"username": "ADMIN", "password": "bad_password"},
            headers={"Content-Type": "application/x-www-form-urlencoded"}
        )
        assert res.status_code == 401, f"Expected 401, got {res.status_code}"
        print("[PASS] 2b. Swagger OAuth2 form login with bad password -> 401 Unauthorized")

        # ---------------------------------------------------------
        # Test 3: OTP Flow & Backdoor Removal
        # ---------------------------------------------------------
        clean_admin_phone = admin_user.phone.replace(" ", "").replace("+91", "")

        # 3a. Seed a real OTP in OTP_STORE
        now = time.time()
        OTP_STORE[clean_admin_phone] = {
            "otp": "852963",
            "expires_at": now + 300,
            "attempts": 0
        }

        # 3b. Verify with valid real OTP
        res = await client.post("/api/v1/auth/verify-otp", json={
            "username": "ADMIN",
            "mobile": admin_user.phone,
            "otp": "852963"
        })
        assert res.status_code == 200, f"Expected 200, got {res.status_code}"
        print("[PASS] 3a. Valid OTP verification -> 200 OK")

        # 3c. Backdoor Test: Verify that hardcoded '123456' is REJECTED when real OTP is different
        OTP_STORE[clean_admin_phone] = {
            "otp": "741852",
            "expires_at": now + 300,
            "attempts": 0
        }
        res = await client.post("/api/v1/auth/verify-otp", json={
            "username": "ADMIN",
            "mobile": admin_user.phone,
            "otp": "123456"  # Attempt backdoor
        })
        assert res.status_code == 401, f"Expected 401 (backdoor blocked), got {res.status_code}"
        print("[PASS] 3b. Hardcoded 123456 OTP bypass blocked -> 401 Unauthorized")

        # 3d. Expired OTP test
        OTP_STORE[clean_admin_phone] = {
            "otp": "999888",
            "expires_at": now - 10,  # Expired
            "attempts": 0
        }
        res = await client.post("/api/v1/auth/verify-otp", json={
            "username": "ADMIN",
            "mobile": admin_user.phone,
            "otp": "999888"
        })
        assert res.status_code == 401, f"Expected 401 (expired OTP), got {res.status_code}"
        print("[PASS] 3c. Expired OTP rejected -> 401 Unauthorized")

        # 3d. Attempt limits: 3 invalid attempts triggers lockout and removes OTP
        OTP_STORE[clean_admin_phone] = {
            "otp": "555111",
            "expires_at": now + 300,
            "attempts": 0
        }
        for i in range(3):
            res = await client.post("/api/v1/auth/verify-otp", json={
                "username": "ADMIN",
                "mobile": admin_user.phone,
                "otp": "000000"
            })
            assert res.status_code == 401, f"Attempt {i+1}: Expected 401, got {res.status_code}"

        # 4th attempt should find OTP wiped due to too many invalid attempts
        res = await client.post("/api/v1/auth/verify-otp", json={
            "username": "ADMIN",
            "mobile": admin_user.phone,
            "otp": "555111"
        })
        assert res.status_code == 401, f"Expected 401 after lockout, got {res.status_code}"
        assert clean_admin_phone not in OTP_STORE
        print("[PASS] 3d. OTP lockout after 3 failed attempts verified -> 401 Unauthorized")

        # 3e. Resend throttling: request-otp cooldown check (429 Too Many Requests)
        OTP_STORE[clean_admin_phone] = {
            "otp": "111222",
            "expires_at": time.time() + 290, # Requested 10s ago, within 60s cooldown
            "attempts": 0
        }
        res = await client.post("/api/v1/auth/request-otp", json={
            "username": "ADMIN",
            "mobile": admin_user.phone
        })
        assert res.status_code == 429, f"Expected 429 (resend throttling), got {res.status_code}"
        print("[PASS] 3e. OTP resend throttling enforced -> 429 Too Many Requests")

        # 3f. verify-user exact phone match: substring phone rejected
        res = await client.post("/api/v1/auth/verify-user", json={
            "username": "ADMIN",
            "mobile": "765432" # Substring of 9876543210
        })
        assert res.status_code == 401, f"Expected 401 for substring phone, got {res.status_code}"
        # Exact phone succeeds
        res = await client.post("/api/v1/auth/verify-user", json={
            "username": "ADMIN",
            "mobile": admin_user.phone
        })
        assert res.status_code == 200, f"Expected 200 for exact phone, got {res.status_code}"
        print("[PASS] 3f. verify-user enforces exact phone matching and rejects substrings -> 200/401")

        # ---------------------------------------------------------
        # Test 4: Token Validation & Missing/Invalid Auth
        # ---------------------------------------------------------
        # 4a. Unauthenticated request to admin endpoint
        res = await client.post("/api/v1/notifications/test-whatsapp")
        assert res.status_code == 401, f"Expected 401, got {res.status_code}"
        print("[PASS] 4a. Missing Authorization header -> 401 Unauthorized")

        # 4b. Malformed token
        res = await client.post(
            "/api/v1/notifications/test-whatsapp",
            headers={"Authorization": "Bearer totally_invalid_jwt_token_string"}
        )
        assert res.status_code == 401, f"Expected 401, got {res.status_code}"
        print("[PASS] 4b. Malformed token -> 401 Unauthorized")

        # ---------------------------------------------------------
        # Test 5: Role-Based Access Control (RBAC)
        # ---------------------------------------------------------
        admin_token = create_access_token({"sub": str(admin_user.id), "role": "administrator"})
        fe_token = create_access_token({"sub": str(fe_user.id), "role": "field_executive"})
        shop_token = create_access_token({"sub": str(shop_user.id), "role": "shop_owner"})

        # 5a. Admin endpoint accessed by Shop Owner -> 403 Forbidden
        res = await client.post(
            "/api/v1/notifications/test-whatsapp",
            headers={"Authorization": f"Bearer {shop_token}"}
        )
        assert res.status_code == 403, f"Expected 403, got {res.status_code}"
        print("[PASS] 5a. Shop Owner accessing admin route -> 403 Forbidden")

        # 5b. Admin endpoint accessed by Field Executive -> 403 Forbidden
        res = await client.post(
            "/api/v1/notifications/test-whatsapp",
            headers={"Authorization": f"Bearer {fe_token}"}
        )
        assert res.status_code == 403, f"Expected 403, got {res.status_code}"
        print("[PASS] 5b. Field Executive accessing admin route -> 403 Forbidden")

        # 5c. Admin endpoint accessed by Administrator -> 200 OK (with WhatsApp mock)
        with patch("app.api.notifications.whatsapp_service.send_template_test") as mock_send:
            mock_send.return_value = {
                "success": True,
                "status": "accepted_by_meta",
                "message": "Accepted",
                "http_status": 200,
                "meta_message_id": "wamid.mock",
                "recipient_masked": "91******1234",
                "error_code": None
            }
            res = await client.post(
                "/api/v1/notifications/test-whatsapp",
                headers={"Authorization": f"Bearer {admin_token}"}
            )
            assert res.status_code == 200, f"Expected 200, got {res.status_code}"
            print("[PASS] 5c. Administrator accessing admin route -> 200 OK")

        # ---------------------------------------------------------
        # Test 6: Employee Location IDOR Prevention
        # ---------------------------------------------------------
        # 6a. Shop Owner attempting location update -> 403 Forbidden
        res = await client.put(
            f"/api/v1/employees/{fe_profile.id}/location",
            json={"lat": 16.5, "lng": 80.5, "battery_level": 85},
            headers={"Authorization": f"Bearer {shop_token}"}
        )
        assert res.status_code == 403, f"Expected 403, got {res.status_code}"
        print("[PASS] 6a. Shop Owner attempting employee location update -> 403 Forbidden")

        # 6b. Field Executive attempting to update ANOTHER employee's location -> 403 Forbidden
        res = await client.put(
            f"/api/v1/employees/{other_fe_id}/location",
            json={"lat": 16.5, "lng": 80.5, "battery_level": 85},
            headers={"Authorization": f"Bearer {fe_token}"}
        )
        assert res.status_code in [403, 404], f"Expected 403 or 404 for invalid employee, got {res.status_code}"
        print("[PASS] 6b. Field Executive attempting to update another employee -> Blocked (403/404)")

        # 6c. Field Executive updating OWN location -> 200 OK
        res = await client.put(
            f"/api/v1/employees/{fe_profile.id}/location",
            json={"lat": 16.501, "lng": 80.501, "battery_level": 90},
            headers={"Authorization": f"Bearer {fe_token}"}
        )
        assert res.status_code == 200, f"Expected 200, got {res.status_code}: {res.text}"
        print("[PASS] 6c. Field Executive updating own location -> 200 OK")

        # 6d. Administrator updating employee location -> 200 OK
        res = await client.put(
            f"/api/v1/employees/{fe_profile.id}/location",
            json={"lat": 16.502, "lng": 80.502, "battery_level": 95},
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        assert res.status_code == 200, f"Expected 200, got {res.status_code}: {res.text}"
        print("[PASS] 6d. Administrator updating employee location -> 200 OK")

        # ---------------------------------------------------------
        # Test 7: Firebase Authentication Flow (/api/v1/auth/login-firebase)
        # ---------------------------------------------------------
        with patch("firebase_admin.auth.verify_id_token") as mock_verify_token:
            # 7a. Valid Firebase Token with exact matching phone
            mock_verify_token.return_value = {
                "uid": "fb_uid_fe001",
                "phone_number": f"+91{fe_user.phone}"
            }
            res = await client.post("/api/v1/auth/login-firebase", json={
                "username": fe_user.username,
                "mobile": fe_user.phone,
                "firebase_id_token": "valid_firebase_jwt_mock"
            })
            assert res.status_code == 200, f"Expected 200, got {res.status_code}: {res.text}"
            data = res.json()
            assert "access_token" in data
            assert data["role"] == "field_executive", f"Expected field_executive, got {data['role']}"
            print("[PASS] 7a. Firebase Login with valid token & exact phone match -> 200 OK (role: field_executive)")

            # 7b. Phone mismatch: Token phone belongs to another number
            mock_verify_token.return_value = {
                "uid": "fb_uid_other",
                "phone_number": "+919999900000"
            }
            res = await client.post("/api/v1/auth/login-firebase", json={
                "username": fe_user.username,
                "mobile": fe_user.phone,
                "firebase_id_token": "mismatched_phone_token"
            })
            assert res.status_code == 401, f"Expected 401 for mismatched phone, got {res.status_code}"
            print("[PASS] 7b. Firebase Login rejected on phone number mismatch -> 401 Unauthorized")

            # 7c. Substring exploit attempt: token phone contains target phone as substring but not exact match
            mock_verify_token.return_value = {
                "uid": "fb_uid_exploit",
                "phone_number": f"+9199{fe_user.phone}" # Has phone as substring
            }
            res = await client.post("/api/v1/auth/login-firebase", json={
                "username": fe_user.username,
                "mobile": fe_user.phone,
                "firebase_id_token": "substring_token"
            })
            assert res.status_code == 401, f"Expected 401 for substring exploit, got {res.status_code}"
            print("[PASS] 7c. Firebase Login rejects substring phone exploit -> 401 Unauthorized")

            # 7d. Inactive account rejected
            # Temporarily set fe_user is_active to False
            fe_user.is_active = False
            db.commit()
            try:
                mock_verify_token.return_value = {
                    "uid": "fb_uid_fe001",
                    "phone_number": f"+91{fe_user.phone}"
                }
                res = await client.post("/api/v1/auth/login-firebase", json={
                    "username": fe_user.username,
                    "mobile": fe_user.phone,
                    "firebase_id_token": "valid_token_inactive_user"
                })
                assert res.status_code == 401, f"Expected 401 for inactive user, got {res.status_code}"
                print("[PASS] 7d. Firebase Login rejects inactive account -> 401 Unauthorized")
            finally:
                fe_user.is_active = True
                db.commit()

            # 7e. Backend role determination: Shop Owner Firebase login gets 'shop_owner' role regardless of any client input
            mock_verify_token.return_value = {
                "uid": "fb_uid_shop001",
                "phone_number": f"+91{shop_user.phone}"
            }
            res = await client.post("/api/v1/auth/login-firebase", json={
                "username": shop_user.username,
                "mobile": shop_user.phone,
                "firebase_id_token": "valid_shop_token",
                "role": "administrator" # Attempt to inject admin role
            })
            assert res.status_code == 200, f"Expected 200, got {res.status_code}"
            assert res.json()["role"] == "shop_owner", f"Expected shop_owner, got {res.json()['role']}"
            print("[PASS] 7e. Backend ignores client-specified role and enforces database role -> 200 OK (role: shop_owner)")

        print("\n=== ALL 22 AUTHENTICATION & RBAC SECURITY TEST CASES PASSED! ===\n")

    db.close()


if __name__ == "__main__":
    asyncio.run(run_auth_security_tests())
