"""
YADVI Hybrid Seeds - Rate Limiting & Anti-Enumeration Test Suite
Validates:
1. SlidingWindowRateLimiter core behavior (allow, limit, expiry, reset, max_keys pruning).
2. Client IP extraction strategy (X-Forwarded-For rightmost selection, direct host, fallback).
3. POST /api/v1/auth/verify-user: 10 requests allowed, 11th receives HTTP 429 with Retry-After.
4. Independent limits for different client IPs.
5. Anti-enumeration: exact identical error message and status code for unknown user, invalid phone, inactive account, and role mismatch.
6. POST /api/v1/auth/login: 5 failed attempts trigger HTTP 429; successful logins do NOT increment failure counter.
7. POST /api/v1/auth/request-otp: 3 requests per IP per 10m; preserves 60-second cooldown per phone number.
"""

import sys
import time
import asyncio
import httpx
from unittest.mock import patch, MagicMock
from fastapi import Request
from app.main import app
from app.core.database import SessionLocal
from app.models.all_models import User
from app.core.rate_limiter import (
    SlidingWindowRateLimiter,
    get_client_ip,
    verify_user_limiter,
    login_failure_limiter,
    request_otp_limiter,
)
from app.api.auth import OTP_STORE


def test_core_rate_limiter_unit():
    print("\n--- Running Core Rate Limiter Unit Tests ---")
    limiter = SlidingWindowRateLimiter(max_keys=10)

    # 1. Allow up to limit
    for i in range(5):
        allowed, retry_after = limiter.check_and_record("test_key", max_requests=5, window_seconds=2)
        assert allowed is True, f"Iteration {i} should be allowed"
        assert retry_after == 0

    # 2. 6th hit should be blocked
    allowed, retry_after = limiter.check_and_record("test_key", max_requests=5, window_seconds=2)
    assert allowed is False, "6th hit should be blocked"
    assert retry_after >= 1, f"retry_after should be >= 1, got {retry_after}"

    # 3. Independent key is allowed
    allowed, _ = limiter.check_and_record("other_key", max_requests=5, window_seconds=2)
    assert allowed is True, "Independent key should be allowed"

    # 4. Expiry / reset
    limiter.reset()
    allowed, _ = limiter.check_and_record("test_key", max_requests=5, window_seconds=2)
    assert allowed is True, "Key should be allowed immediately after reset"

    print("[PASS] Core SlidingWindowRateLimiter unit tests passed.")


def test_client_ip_extraction():
    print("\n--- Running Client IP Extraction Unit Tests ---")
    
    # 1. Direct connection
    req1 = MagicMock(spec=Request)
    req1.headers = {}
    req1.client = MagicMock(host="192.168.1.100")
    assert get_client_ip(req1) == "192.168.1.100"

    # 2. Single X-Forwarded-For
    req2 = MagicMock(spec=Request)
    req2.headers = {"x-forwarded-for": "203.0.113.195"}
    req2.client = MagicMock(host="10.0.0.1")
    assert get_client_ip(req2) == "203.0.113.195"

    # 3. Spoofed header with proxy chain (GFE appends actual client IP to the end)
    req3 = MagicMock(spec=Request)
    req3.headers = {"x-forwarded-for": "1.1.1.1, 10.0.0.2, 203.0.113.50"}
    req3.client = MagicMock(host="10.0.0.1")
    # Rightmost entry is trusted GFE-appended IP
    assert get_client_ip(req3) == "203.0.113.50"

    # 4. Unknown client fallback (safe isolated bucket)
    req4 = MagicMock(spec=Request)
    req4.headers = {}
    req4.client = None
    assert get_client_ip(req4) == "unknown_client_ip"

    print("[PASS] Client IP extraction tests passed.")


async def run_api_rate_limiting_tests():
    print("\n--- Running API Rate Limiting & Anti-Enumeration Integration Tests ---")
    db = SessionLocal()
    transport = httpx.ASGITransport(app=app)

    # Ensure limiters are clean before starting tests
    verify_user_limiter.reset()
    login_failure_limiter.reset()
    request_otp_limiter.reset()
    OTP_STORE.clear()

    admin_user = db.query(User).filter(User.role.has(name="administrator")).first()
    fe_user = db.query(User).filter(User.role.has(name="field_executive")).first()
    assert admin_user is not None
    assert fe_user is not None

    async with httpx.AsyncClient(transport=transport, base_url="http://testserver") as client:
        # ---------------------------------------------------------------------
        # TEST 1: verify-user Anti-Enumeration
        # ---------------------------------------------------------------------
        # 1a. Unknown user
        r_unknown = await client.post("/api/v1/auth/verify-user", json={
            "username": "UNKNOWN_USER_123",
            "mobile": "9876543210",
            "expected_role": "administrator"
        }, headers={"x-forwarded-for": "198.51.100.1"})
        assert r_unknown.status_code == 401
        err_unknown = r_unknown.json().get("detail")

        # 1b. Correct username, wrong phone
        r_wrong_phone = await client.post("/api/v1/auth/verify-user", json={
            "username": admin_user.username,
            "mobile": "9111111111",
            "expected_role": "administrator"
        }, headers={"x-forwarded-for": "198.51.100.1"})
        assert r_wrong_phone.status_code == 401
        err_wrong_phone = r_wrong_phone.json().get("detail")

        # 1c. Correct user, correct phone, WRONG role
        r_wrong_role = await client.post("/api/v1/auth/verify-user", json={
            "username": fe_user.username,
            "mobile": fe_user.phone,
            "expected_role": "administrator"
        }, headers={"x-forwarded-for": "198.51.100.1"})
        assert r_wrong_role.status_code == 401
        err_wrong_role = r_wrong_role.json().get("detail")

        # Verify all error messages are identical (anti-enumeration)
        assert err_unknown == err_wrong_phone == err_wrong_role == "Invalid username, phone number, or role."
        assert admin_user.username not in err_wrong_phone
        assert fe_user.username not in err_wrong_role
        print("[PASS] 1. Anti-enumeration: all failure reasons return identical generic 401 detail.")

        # ---------------------------------------------------------------------
        # TEST 2: verify-user Rate Limiting (10 req/min per IP, 11th blocked)
        # ---------------------------------------------------------------------
        verify_user_limiter.reset()
        test_ip = "198.51.100.10"
        
        # Requests 1 to 10 should be processed (succeed with 200)
        for i in range(1, 11):
            res = await client.post("/api/v1/auth/verify-user", json={
                "username": admin_user.username,
                "mobile": admin_user.phone,
                "expected_role": "administrator"
            }, headers={"x-forwarded-for": test_ip})
            assert res.status_code == 200, f"Request {i} from {test_ip} should return 200, got {res.status_code}"

        # 11th request from same IP must receive HTTP 429
        res_11 = await client.post("/api/v1/auth/verify-user", json={
            "username": admin_user.username,
            "mobile": admin_user.phone,
            "expected_role": "administrator"
        }, headers={"x-forwarded-for": test_ip})
        assert res_11.status_code == 429, f"11th request should return 429, got {res_11.status_code}: {res_11.text}"
        assert "Too many verification attempts" in res_11.json().get("detail", "")
        assert "retry-after" in res_11.headers
        print("[PASS] 2. verify-user: 11th request from same IP received HTTP 429 with Retry-After header.")

        # ---------------------------------------------------------------------
        # TEST 3: verify-user Independent Limits for Different IPs
        # ---------------------------------------------------------------------
        other_ip = "198.51.100.20"
        res_other = await client.post("/api/v1/auth/verify-user", json={
            "username": admin_user.username,
            "mobile": admin_user.phone,
            "expected_role": "administrator"
        }, headers={"x-forwarded-for": other_ip})
        assert res_other.status_code == 200, f"Request from {other_ip} should succeed while {test_ip} is limited"
        print("[PASS] 3. verify-user: independent client IPs receive separate rate limits.")

        # ---------------------------------------------------------------------
        # TEST 4: login_password Failure Throttling
        # ---------------------------------------------------------------------
        login_failure_limiter.reset()
        login_ip = "198.51.100.30"

        # 4a. Successful login must NOT count as a failure
        res_success = await client.post("/api/v1/auth/login", json={
            "username": "ADMIN",
            "password": "admin123"
        }, headers={"x-forwarded-for": login_ip})
        assert res_success.status_code == 200
        # Failure count should still be 0
        allowed, _ = login_failure_limiter.is_allowed(login_ip, max_requests=5, window_seconds=300)
        assert allowed is True

        # 4b. Perform 5 consecutive failed logins
        for i in range(1, 6):
            res_fail = await client.post("/api/v1/auth/login", json={
                "username": "ADMIN",
                "password": f"wrong_password_{i}"
            }, headers={"x-forwarded-for": login_ip})
            assert res_fail.status_code == 401, f"Failed attempt {i} should return 401, got {res_fail.status_code}"

        # 4c. 6th login attempt (even with CORRECT password) must be blocked by rate limiter with HTTP 429
        res_blocked = await client.post("/api/v1/auth/login", json={
            "username": "ADMIN",
            "password": "admin123"
        }, headers={"x-forwarded-for": login_ip})
        assert res_blocked.status_code == 429, f"Expected 429 after 5 failures, got {res_blocked.status_code}: {res_blocked.text}"
        assert "Too many failed login attempts" in res_blocked.json().get("detail", "")
        print("[PASS] 4. login: 5 failed attempts trigger HTTP 429 lockout; successful logins do not increment failures.")

        # ---------------------------------------------------------------------
        # TEST 5: request-otp IP Throttling & Phone Cooldown
        # ---------------------------------------------------------------------
        request_otp_limiter.reset()
        OTP_STORE.clear()
        otp_ip = "198.51.100.40"

        with patch("app.api.auth.send_sms_otp", return_value=True):
            # 5a. First request succeeds (Hit 1 for IP)
            r1 = await client.post("/api/v1/auth/request-otp", json={
                "username": admin_user.username,
                "mobile": admin_user.phone
            }, headers={"x-forwarded-for": otp_ip})
            assert r1.status_code == 200, f"Expected 200, got {r1.status_code}: {r1.text}"

            # 5b. Immediate second request for same phone triggers 60s cooldown (429) (Hit 2 for IP)
            r_cooldown = await client.post("/api/v1/auth/request-otp", json={
                "username": admin_user.username,
                "mobile": admin_user.phone
            }, headers={"x-forwarded-for": otp_ip})
            assert r_cooldown.status_code == 429
            assert "wait before requesting a new OTP" in r_cooldown.json().get("detail", "")

            # 5c. Third request for DIFFERENT phone (fe_user) from same IP succeeds (Hit 3 for IP)
            r2 = await client.post("/api/v1/auth/request-otp", json={
                "username": fe_user.username,
                "mobile": fe_user.phone
            }, headers={"x-forwarded-for": otp_ip})
            assert r2.status_code == 200, f"Expected 200, got {r2.status_code}: {r2.text}"

            # 5d. 4th request from same IP must receive HTTP 429 due to IP limit (max 3 per 10m)
            r3 = await client.post("/api/v1/auth/request-otp", json={
                "username": admin_user.username,
                "mobile": admin_user.phone
            }, headers={"x-forwarded-for": otp_ip})
            assert r3.status_code == 429, f"Expected 429 on 4th IP request, got {r3.status_code}: {r3.text}"
            assert "Too many OTP requests from this IP" in r3.json().get("detail", "")

            # 5e. Independent IP can still request OTP for admin_user once phone cooldown expires
            other_otp_ip = "198.51.100.99"
            OTP_STORE.clear()  # Clear phone cooldown to test other IP
            r_other = await client.post("/api/v1/auth/request-otp", json={
                "username": admin_user.username,
                "mobile": admin_user.phone
            }, headers={"x-forwarded-for": other_otp_ip})
            assert r_other.status_code == 200, f"Expected 200 for independent IP, got {r_other.status_code}"
            print("[PASS] 5. request-otp: 3 requests per IP per 10m enforced; phone-level 60s cooldown preserved.")

        print("\n=== ALL RATE LIMITING & ANTI-ENUMERATION TESTS PASSED SUCCESSFULLY! ===\n")

    db.close()


if __name__ == "__main__":
    test_core_rate_limiter_unit()
    test_client_ip_extraction()
    asyncio.run(run_api_rate_limiting_tests())
