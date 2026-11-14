"""
Automated Test Suite for Shop Owner (SO) Creation & Authentication Flows:
- POST /api/v1/shops (Authorization, Validation, Normalization, Duplicate Handling, Single Transaction)
- POST /api/v1/auth/verify-user (Pre-login Verification for Shop Owner)
- POST /api/v1/auth/login (Password Login & Token Generation for Shop Owner)
- GET /api/v1/shops/my (Shop Profile Access with Authenticated Shop Owner Token)
"""
import sys
import asyncio
import httpx
from app.main import app
from app.core.database import SessionLocal
from app.models.all_models import User, Role, ShopOwner, FieldExecutive
from app.core.security import create_access_token

async def run_shop_owner_tests():
    db = SessionLocal()
    transport = httpx.ASGITransport(app=app)

    async with httpx.AsyncClient(transport=transport, base_url="http://testserver") as client:
        print("\n=== STARTING SHOP OWNER CREATION & AUTHENTICATION TESTS ===\n")

        admin_user = db.query(User).filter(User.role.has(name="administrator")).first()
        fe_user = db.query(User).filter(User.role.has(name="field_executive")).first()
        assert admin_user is not None, "Admin user must exist"
        assert fe_user is not None, "FE user must exist"

        admin_token = create_access_token(data={"sub": str(admin_user.id), "role": "administrator", "name": admin_user.full_name})
        fe_token = create_access_token(data={"sub": str(fe_user.id), "role": "field_executive", "name": fe_user.full_name})

        admin_headers = {"Authorization": f"Bearer {admin_token}", "Content-Type": "application/json"}
        fe_headers = {"Authorization": f"Bearer {fe_token}", "Content-Type": "application/json"}

        # Test identifiers
        test_phones = ["9997770001", "9997770002", "9997770003"]
        test_usernames = ["so_test_001", "so_test_002", "so_test_003"]

        def cleanup_test_records():
            for p in test_phones:
                users = db.query(User).filter(User.phone.like(f"%{p}%")).all()
                for u in users:
                    db.query(ShopOwner).filter(ShopOwner.user_id == u.id).delete()
                    db.delete(u)
            for u_name in test_usernames:
                users = db.query(User).filter(User.username == u_name).all()
                for u in users:
                    db.query(ShopOwner).filter(ShopOwner.user_id == u.id).delete()
                    db.delete(u)
            db.commit()

        cleanup_test_records()

        try:
            # 1. Non-admin access rejected (403 Forbidden)
            fe_res = await client.post("/api/v1/shops", json={
                "shop_name": "Unauthorized Shop",
                "owner_name": "Unauthorized User",
                "phone": "9997770001",
                "username": "so_test_001",
                "market_location": "Market Yard",
                "address": "123 Market St"
            }, headers=fe_headers)
            assert fe_res.status_code == 403, f"Expected 403, got {fe_res.status_code}"
            print("[PASS] 1. Non-admin user receives 403 Forbidden on SO creation")

            # 2. Successful creation with un-normalized phone (+91 99977 70001 -> stored as 9997770001)
            create_res = await client.post("/api/v1/shops", json={
                "shop_name": "Sri Krishna Agro Seeds",
                "owner_name": "K. Venkateswara Rao",
                "phone": "+91 99977 70001",
                "username": "so_test_001",
                "market_location": "Tenali Market Yard",
                "address": "Shop #24, Main Road, Tenali"
            }, headers=admin_headers)
            assert create_res.status_code == 200, f"Expected 200, got {create_res.status_code}: {create_res.text}"
            data = create_res.json()
            assert data["phone"] == "9997770001", f"Expected phone normalized to 9997770001, got {data['phone']}"
            assert data["owner_name"] == "K. Venkateswara Rao"
            assert data["shop_name"] == "Sri Krishna Agro Seeds"
            assert data["status"] == "Active"
            created_user_id = data["user_id"]
            created_shop_id = data["id"]
            print("[PASS] 2. Admin creates SO with phone normalization -> 200 OK (stored as 10-digit mobile)")

            # 3. Verify database state for created User and ShopOwner
            created_user = db.query(User).filter(User.id == created_user_id).first()
            assert created_user is not None, "Created user must exist in DB"
            assert created_user.role.name == "shop_owner", f"Expected role shop_owner, got {created_user.role.name}"
            assert created_user.hashed_password is not None, "hashed_password must be populated"
            assert created_user.phone == "9997770001"
            assert created_user.is_active is True

            created_shop = db.query(ShopOwner).filter(ShopOwner.id == created_shop_id).first()
            assert created_shop is not None, "Created shop must exist in DB"
            assert created_shop.user_id == created_user.id
            assert created_shop.shop_name == "Sri Krishna Agro Seeds"
            print("[PASS] 3. Database state verified (User linked to ShopOwner with shop_owner role and password hash)")

            # 4. Duplicate username rejected
            dup_user_res = await client.post("/api/v1/shops", json={
                "shop_name": "Another Shop",
                "owner_name": "Another Name",
                "phone": "9997770002",
                "username": "so_test_001",
                "market_location": "Guntur",
                "address": "Shop 1"
            }, headers=admin_headers)
            assert dup_user_res.status_code == 400, f"Expected 400, got {dup_user_res.status_code}"
            assert "Username 'so_test_001' already exists" in dup_user_res.json().get("detail", "")
            print("[PASS] 4. Duplicate username rejected with clear 400 detail")

            # 5. Duplicate phone rejected across formats (input with +91 vs raw 10 digits)
            dup_phone_res = await client.post("/api/v1/shops", json={
                "shop_name": "Another Shop",
                "owner_name": "Another Name",
                "phone": "9997770001", # Existing was created as +91 99977 70001
                "username": "so_test_002",
                "market_location": "Guntur",
                "address": "Shop 2"
            }, headers=admin_headers)
            assert dup_phone_res.status_code == 400, f"Expected 400, got {dup_phone_res.status_code}"
            assert "Phone number '9997770001' already exists" in dup_phone_res.json().get("detail", "")
            print("[PASS] 5. Duplicate phone rejected across formats with clear 400 detail")

            # 6. Invalid / short phone number rejected
            bad_phone_res = await client.post("/api/v1/shops", json={
                "shop_name": "Bad Phone Shop",
                "owner_name": "Bad Phone Owner",
                "phone": "12345",
                "username": "so_test_003",
                "market_location": "Guntur",
                "address": "Shop 3"
            }, headers=admin_headers)
            assert bad_phone_res.status_code == 400, f"Expected 400, got {bad_phone_res.status_code}"
            assert "Phone number must be a valid 10-digit mobile number." in bad_phone_res.json().get("detail", "")
            print("[PASS] 6. Invalid / short phone number rejected with 400")

            # 7. Mandatory field validation
            empty_shop_res = await client.post("/api/v1/shops", json={
                "shop_name": "",
                "owner_name": "Name",
                "phone": "9997770002",
                "username": "so_test_002",
                "market_location": "Guntur",
                "address": "Shop 2"
            }, headers=admin_headers)
            assert empty_shop_res.status_code == 400
            assert "Shop Name is mandatory" in empty_shop_res.json().get("detail", "")
            print("[PASS] 7. Missing mandatory fields rejected with 400")

            # 8. Authentication Pre-Verification (/api/v1/auth/verify-user) succeeds for created SO
            verify_res = await client.post("/api/v1/auth/verify-user", json={
                "username": "so_test_001",
                "mobile": "9997770001",
                "expected_role": "shop_owner"
            })
            assert verify_res.status_code == 200, f"Expected 200, got {verify_res.status_code}: {verify_res.text}"
            assert verify_res.json().get("status") == "success"
            print("[PASS] 8. Pre-login verification (/verify-user) succeeds for created SO")

            # 9. Pre-verification fails if wrong role is requested (Anti-Role escalation)
            wrong_role_res = await client.post("/api/v1/auth/verify-user", json={
                "username": "so_test_001",
                "mobile": "9997770001",
                "expected_role": "field_executive"
            })
            assert wrong_role_res.status_code == 401, f"Expected 401, got {wrong_role_res.status_code}"
            print("[PASS] 9. Role mismatch rejected with 401 during verify-user")

            # 10. Password Login (/api/v1/auth/login) succeeds with default password
            login_res = await client.post("/api/v1/auth/login", json={
                "username": "so_test_001",
                "password": "shop123"
            })
            assert login_res.status_code == 200, f"Expected 200, got {login_res.status_code}: {login_res.text}"
            login_data = login_res.json()
            assert login_data["role"] == "shop_owner"
            assert login_data["metadata"]["shop_name"] == "Sri Krishna Agro Seeds"
            assert login_data["metadata"]["shop_id"] == created_shop_id
            so_token = login_data["access_token"]
            print("[PASS] 10. Password login succeeds with default credentials, returning JWT with shop metadata")

            # 11. Profile Access (/api/v1/shops/my) with newly authenticated Shop Owner token
            so_headers = {"Authorization": f"Bearer {so_token}", "Content-Type": "application/json"}
            profile_res = await client.get("/api/v1/shops/my", headers=so_headers)
            assert profile_res.status_code == 200, f"Expected 200, got {profile_res.status_code}: {profile_res.text}"
            profile_data = profile_res.json()
            assert profile_data["id"] == created_shop_id
            assert profile_data["shop_name"] == "Sri Krishna Agro Seeds"
            assert profile_data["owner_name"] == "K. Venkateswara Rao"
            assert profile_data["phone"] == "9997770001"
            print("[PASS] 11. GET /api/v1/shops/my returns own profile for created SO")

            # 12. Verify dealer_code is completely absent from model, schema, and response
            assert not hasattr(ShopOwner, "dealer_code"), "ShopOwner model must NOT define dealer_code"
            assert "dealer_code" not in profile_data, "ShopOut schema response must NOT return dealer_code"
            assert "dealer_code" not in [c.name for c in ShopOwner.__table__.columns], "ShopOwner table mapping must NOT have dealer_code"
            print("[PASS] 12. Verified dealer_code is completely absent from model, schema, and API response")

            # 13. Verify transactional integrity and rollback handling on database failure
            from unittest.mock import patch
            with patch("sqlalchemy.orm.Session.commit", side_effect=Exception("Simulated DB commit error")):
                fail_res = await client.post("/api/v1/shops", json={
                    "shop_name": "Rollback Test Shop",
                    "owner_name": "Rollback Owner",
                    "phone": "9997770003",
                    "username": "so_test_003",
                    "market_location": "Rollback City",
                    "address": "456 Rollback Rd"
                }, headers=admin_headers)
                assert fail_res.status_code == 500, f"Expected 500 on DB failure, got {fail_res.status_code}"
                assert "Database error creating shop" in fail_res.json().get("detail", "")
                # Verify rollback ensured no orphan User was committed
                orphan_user = db.query(User).filter(User.username == "so_test_003").first()
                assert orphan_user is None, "Orphaned user must NOT exist after database transaction rollback"
            print("[PASS] 13. Transactional rollback verified: no orphaned User created upon database failure")

        finally:
            cleanup_test_records()

    print("\n=== ALL 13 SHOP OWNER CREATION & AUTHENTICATION TESTS PASSED ===\n")

if __name__ == "__main__":
    asyncio.run(run_shop_owner_tests())
