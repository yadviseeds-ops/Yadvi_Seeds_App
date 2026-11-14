"""
YADVI Hybrid Seeds - Multi-Admin Phone Number Authentication Test Suite
Verifies:
1. Existing primary number (9529403798) is accepted for Admin.
2. Additional secondary number (8080259924) is accepted for Admin.
3. Both numbers map to the exact same Admin account (id=1, role='administrator', username='ADMIN').
4. Unrelated numbers (e.g. 9999999999, 9123456789) are rejected.
5. Non-admin users (FE / Shop Owner) cannot obtain Admin access by entering ADMIN.
6. Firebase phone mismatch (token phone != requested mobile) is strictly rejected.
7. Missing or invalid Firebase ID tokens are rejected.
8. Rate limiting on /verify-user is preserved.
9. Database AdminPhone model mapping and fallback configuration.
"""

import sys
import asyncio
import httpx
from unittest.mock import patch, MagicMock
from app.main import app
from app.core.database import SessionLocal
from app.models.all_models import User, Role, AdminPhone
from app.core.rate_limiter import verify_user_limiter, login_failure_limiter

PRIMARY_ADMIN_PHONE = "9529403798"
SECONDARY_ADMIN_PHONE = "8080259924"
UNRELATED_PHONE = "9999999999"

async def run_multi_admin_tests():
    db = SessionLocal()
    verify_user_limiter.reset()
    login_failure_limiter.reset()
    transport = httpx.ASGITransport(app=app)

    async with httpx.AsyncClient(transport=transport, base_url="http://testserver") as client:
        print("\n=== STARTING MULTI-ADMIN PHONE AUTHENTICATION TESTS ===\n")

        # -------------------------------------------------------------
        # Setup: Ensure Admin user exists and has PRIMARY_ADMIN_PHONE
        # -------------------------------------------------------------
        admin_user = db.query(User).filter(User.username == "ADMIN").first()
        assert admin_user is not None, "ADMIN user must exist in database"
        assert admin_user.role.name == "administrator", "ADMIN user must have administrator role"
        
        # Ensure primary phone is set on User record for test
        admin_user.phone = PRIMARY_ADMIN_PHONE
        admin_user.is_active = True
        db.commit()

        # Ensure AdminPhone table can be populated
        try:
            AdminPhone.__table__.create(bind=db.bind, checkfirst=True)
            # Clean up existing test entries in admin_phones if any
            db.query(AdminPhone).filter(AdminPhone.user_id == admin_user.id).delete()
            db.commit()

            # Insert secondary admin phone into AdminPhone table
            sec_phone_entry = AdminPhone(
                user_id=admin_user.id,
                phone=SECONDARY_ADMIN_PHONE,
                label="Secondary Administrator Phone",
                is_active=True
            )
            db.add(sec_phone_entry)
            db.commit()
            print("[SETUP] Seeded AdminPhone entry for secondary phone.")
        except Exception as e:
            print(f"[SETUP NOTE] AdminPhone table note: {e}")
            db.rollback()

        # -------------------------------------------------------------
        # Test 1: Verify-User with Primary Admin Phone (9529403798)
        # -------------------------------------------------------------
        res = await client.post("/api/v1/auth/verify-user", json={
            "username": "ADMIN",
            "mobile": PRIMARY_ADMIN_PHONE,
            "expected_role": "administrator"
        })
        assert res.status_code == 200, f"Expected 200 for primary admin phone, got {res.status_code}: {res.text}"
        assert res.json()["status"] == "success"
        print("[PASS] 1. verify-user accepts primary admin phone (9529403798) -> 200 OK")

        # -------------------------------------------------------------
        # Test 2: Verify-User with Secondary Admin Phone (8080259924)
        # -------------------------------------------------------------
        res = await client.post("/api/v1/auth/verify-user", json={
            "username": "ADMIN",
            "mobile": SECONDARY_ADMIN_PHONE,
            "expected_role": "administrator"
        })
        assert res.status_code == 200, f"Expected 200 for secondary admin phone, got {res.status_code}: {res.text}"
        assert res.json()["status"] == "success"
        print("[PASS] 2. verify-user accepts secondary admin phone (8080259924) -> 200 OK")

        # -------------------------------------------------------------
        # Test 3: Verify-User with International & prefixed formats
        # -------------------------------------------------------------
        res = await client.post("/api/v1/auth/verify-user", json={
            "username": "ADMIN",
            "mobile": f"+91 {SECONDARY_ADMIN_PHONE}",
            "expected_role": "administrator"
        })
        assert res.status_code == 200, f"Expected 200 for +91 prefixed secondary phone, got {res.status_code}"
        print("[PASS] 3. verify-user normalizes international prefix +91 -> 200 OK")

        # -------------------------------------------------------------
        # Test 4: Unrelated Phone with Admin username is Rejected
        # -------------------------------------------------------------
        res = await client.post("/api/v1/auth/verify-user", json={
            "username": "ADMIN",
            "mobile": UNRELATED_PHONE,
            "expected_role": "administrator"
        })
        assert res.status_code == 401, f"Expected 401 for unrelated phone claiming ADMIN, got {res.status_code}"
        assert res.json()["detail"] == "Invalid username, phone number, or role."
        print("[PASS] 4. Unrelated phone claiming ADMIN is rejected -> 401 Unauthorized")

        # -------------------------------------------------------------
        # Test 5: Non-Admin User Phone cannot claim ADMIN
        # -------------------------------------------------------------
        fe_user = db.query(User).filter(User.role.has(name="field_executive")).first()
        assert fe_user is not None
        res = await client.post("/api/v1/auth/verify-user", json={
            "username": "ADMIN",
            "mobile": fe_user.phone,
            "expected_role": "administrator"
        })
        assert res.status_code == 401, f"Expected 401 for FE phone claiming ADMIN, got {res.status_code}"
        assert res.json()["detail"] == "Invalid username, phone number, or role."
        print("[PASS] 5. Field Executive phone attempting ADMIN login is rejected -> 401 Unauthorized")

        # -------------------------------------------------------------
        # Test 6: Firebase Login for Primary Phone (9529403798)
        # -------------------------------------------------------------
        with patch("firebase_admin.auth.verify_id_token") as mock_verify:
            mock_verify.return_value = {
                "uid": "fb_uid_admin_primary",
                "phone_number": f"+91{PRIMARY_ADMIN_PHONE}"
            }
            res = await client.post("/api/v1/auth/login-firebase", json={
                "username": "ADMIN",
                "mobile": PRIMARY_ADMIN_PHONE,
                "firebase_id_token": "valid_mock_token_primary"
            })
            assert res.status_code == 200, f"Expected 200, got {res.status_code}: {res.text}"
            data_primary = res.json()
            assert data_primary["role"] == "administrator"
            assert data_primary["user_id"] == admin_user.id
            assert "access_token" in data_primary
            print("[PASS] 6. Firebase login with primary phone maps to Admin account (user_id=1, role=administrator) -> 200 OK")

        # -------------------------------------------------------------
        # Test 7: Firebase Login for Secondary Phone (8080259924)
        # -------------------------------------------------------------
        with patch("firebase_admin.auth.verify_id_token") as mock_verify:
            mock_verify.return_value = {
                "uid": "fb_uid_admin_secondary",
                "phone_number": f"+91{SECONDARY_ADMIN_PHONE}"
            }
            res = await client.post("/api/v1/auth/login-firebase", json={
                "username": "ADMIN",
                "mobile": SECONDARY_ADMIN_PHONE,
                "firebase_id_token": "valid_mock_token_secondary"
            })
            assert res.status_code == 200, f"Expected 200, got {res.status_code}: {res.text}"
            data_sec = res.json()
            assert data_sec["role"] == "administrator"
            assert data_sec["user_id"] == admin_user.id # MUST MAP TO THE SAME ACCOUNT
            assert "access_token" in data_sec
            print("[PASS] 7. Firebase login with secondary phone maps to the SAME Admin account (user_id=1, role=administrator) -> 200 OK")

        # -------------------------------------------------------------
        # Test 8: Firebase Phone Mismatch Rejected
        # (Token is for 9529403798 but request is for 8080259924)
        # -------------------------------------------------------------
        with patch("firebase_admin.auth.verify_id_token") as mock_verify:
            mock_verify.return_value = {
                "uid": "fb_uid_mismatch",
                "phone_number": f"+91{PRIMARY_ADMIN_PHONE}"
            }
            res = await client.post("/api/v1/auth/login-firebase", json={
                "username": "ADMIN",
                "mobile": SECONDARY_ADMIN_PHONE,
                "firebase_id_token": "mismatched_token"
            })
            assert res.status_code == 401, f"Expected 401 for token phone mismatch, got {res.status_code}"
            assert "mismatch" in res.json()["detail"].lower()
            print("[PASS] 8. Firebase phone mismatch is rejected -> 401 Unauthorized")

        # -------------------------------------------------------------
        # Test 9: Invalid / Expired Firebase Token Rejected
        # -------------------------------------------------------------
        with patch("firebase_admin.auth.verify_id_token") as mock_verify:
            mock_verify.side_effect = Exception("Firebase ID token has expired")
            res = await client.post("/api/v1/auth/login-firebase", json={
                "username": "ADMIN",
                "mobile": SECONDARY_ADMIN_PHONE,
                "firebase_id_token": "expired_token"
            })
            assert res.status_code == 401, f"Expected 401 for expired token, got {res.status_code}"
            print("[PASS] 9. Expired or invalid Firebase ID token is rejected -> 401 Unauthorized")

        # -------------------------------------------------------------
        # Test 10: Inactive Admin Account Rejected
        # -------------------------------------------------------------
        admin_user.is_active = False
        db.commit()
        res = await client.post("/api/v1/auth/verify-user", json={
            "username": "ADMIN",
            "mobile": SECONDARY_ADMIN_PHONE,
            "expected_role": "administrator"
        })
        assert res.status_code == 401, f"Expected 401 for inactive admin, got {res.status_code}"
        admin_user.is_active = True
        db.commit()
        print("[PASS] 10. Inactive Admin account is rejected -> 401 Unauthorized")

        # -------------------------------------------------------------
        # Test 11: Rate Limiting Enforcement
        # -------------------------------------------------------------
        verify_user_limiter.reset()
        for i in range(10):
            r = await client.post("/api/v1/auth/verify-user", json={
                "username": "ADMIN",
                "mobile": SECONDARY_ADMIN_PHONE,
                "expected_role": "administrator"
            })
            assert r.status_code == 200
        
        # 11th request triggers rate limit
        r_blocked = await client.post("/api/v1/auth/verify-user", json={
            "username": "ADMIN",
            "mobile": SECONDARY_ADMIN_PHONE,
            "expected_role": "administrator"
        })
        assert r_blocked.status_code == 429, f"Expected 429, got {r_blocked.status_code}"
        assert "Retry-After" in r_blocked.headers
        print("[PASS] 11. Rate limiter enforces 10 req/min threshold -> 429 Too Many Requests")

        print("\n=== ALL 11 MULTI-ADMIN AUTHENTICATION TESTS PASSED SUCCESSFULLY! ===\n")

if __name__ == "__main__":
    asyncio.run(run_multi_admin_tests())
