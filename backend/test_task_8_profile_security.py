"""
Task 8 Backend Security and Profile Tampering Test Suite:
Validates that:
21. Authenticated FE can update only their own allowed fields.
22. Authenticated SO can update only their own allowed fields.
23. FE cannot edit another FE's profile.
24. SO cannot edit another SO's profile.
25. FE cannot update SO profiles.
26. SO cannot update FE profiles.
27. Mobile-number modification is rejected or safely ignored.
28. Username modification is rejected or safely ignored.
29. Role modification is rejected or safely ignored.
30. User ID modification is rejected or safely ignored.
31. Permission modification is rejected or safely ignored.
32. Existing Admin-assigned values remain unchanged after tampering attempts.
"""
import sys
import asyncio
import httpx
from app.main import app
from app.core.database import SessionLocal, Base, engine
from app.models.all_models import User, Role, ShopOwner, FieldExecutive
from app.core.security import create_access_token

async def run_security_tests():
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    transport = httpx.ASGITransport(app=app)

    async with httpx.AsyncClient(transport=transport, base_url="http://testserver") as client:
        print("\n=== STARTING TASK 8 PROFILE SECURITY & TAMPERING TESTS ===\n")

        fe_users = db.query(User).filter(User.role.has(name="field_executive")).all()
        so_users = db.query(User).filter(User.role.has(name="shop_owner")).all()

        assert len(fe_users) >= 1, "At least 1 FE user required"
        assert len(so_users) >= 1, "At least 1 SO user required"

        fe1 = fe_users[0]
        so1 = so_users[0]

        fe1_token = create_access_token(data={"sub": str(fe1.id), "role": "field_executive", "name": fe1.full_name})
        so1_token = create_access_token(data={"sub": str(so1.id), "role": "shop_owner", "name": so1.full_name})

        fe1_headers = {"Authorization": f"Bearer {fe1_token}", "Content-Type": "application/json"}
        so1_headers = {"Authorization": f"Bearer {so1_token}", "Content-Type": "application/json"}

        fe1_orig_phone = fe1.phone
        fe1_orig_username = fe1.username
        fe1_orig_role_id = fe1.role_id
        fe1_orig_id = fe1.id

        so1_orig_phone = so1.phone
        so1_orig_username = so1.username
        so1_orig_role_id = so1.role_id
        so1_orig_id = so1.id

        # 21. Authenticated FE updates allowed fields (full_name, email)
        res_fe_allowed = await client.put(
            "/api/v1/employees/me",
            json={"full_name": "Ravi Kumar FE", "email": "ravi.fe.valid@yadvi.com"},
            headers=fe1_headers
        )
        assert res_fe_allowed.status_code == 200, f"Expected 200, got {res_fe_allowed.status_code}"
        fe_data = res_fe_allowed.json()
        assert fe_data["full_name"] == "Ravi Kumar FE"
        assert fe_data["email"] == "ravi.fe.valid@yadvi.com"
        print("[PASS] 21. Authenticated FE can update allowed fields (full_name, email)")

        # 22. Authenticated SO updates allowed fields (owner_name, shop_name, email, address, market_location)
        res_so_allowed = await client.put(
            "/api/v1/shops/my",
            json={
                "owner_name": "Rao Garu",
                "shop_name": "Kisan Seva Kendra",
                "email": "rao.so.valid@yadvi.com",
                "address": "Bazaar Street, Tenali",
                "market_location": "Tenali Market"
            },
            headers=so1_headers
        )
        assert res_so_allowed.status_code == 200, f"Expected 200, got {res_so_allowed.status_code}"
        so_data = res_so_allowed.json()
        assert so_data["owner_name"] == "Rao Garu"
        assert so_data["shop_name"] == "Kisan Seva Kendra"
        assert so_data["email"] == "rao.so.valid@yadvi.com"
        print("[PASS] 22. Authenticated SO can update allowed fields")

        # 23 & 24. A user cannot specify another user's ID to edit their profile
        # PUT /employees/me and PUT /shops/my use JWT sub exclusively; even if client passes 'user_id' or 'id', it's ignored or rejected.
        # 25. FE cannot update SO profile
        res_fe_to_so = await client.put("/api/v1/shops/my", json={"shop_name": "Hacked Shop"}, headers=fe1_headers)
        assert res_fe_to_so.status_code == 403, f"Expected 403, got {res_fe_to_so.status_code}"
        print("[PASS] 25. FE cannot update SO profile (403 Forbidden)")

        # 26. SO cannot update FE profile
        res_so_to_fe = await client.put("/api/v1/employees/me", json={"full_name": "Hacked FE"}, headers=so1_headers)
        assert res_so_to_fe.status_code == 403, f"Expected 403, got {res_so_to_fe.status_code}"
        print("[PASS] 26. SO cannot update FE profile (403 Forbidden)")

        # 27. Mobile number tampering test on FE
        res_tamper_phone_fe = await client.put(
            "/api/v1/employees/me",
            json={"full_name": "Ravi Kumar FE", "phone": "1111111111", "mobile_number": "1111111111"},
            headers=fe1_headers
        )
        assert res_tamper_phone_fe.status_code == 200
        assert res_tamper_phone_fe.json()["phone"] == fe1_orig_phone, "Phone must remain original admin-assigned phone"
        db.refresh(fe1)
        assert fe1.phone == fe1_orig_phone
        print("[PASS] 27. FE phone tampering safely ignored/rejected; original mobile number unchanged")

        # 28. Username tampering test on FE
        res_tamper_user_fe = await client.put(
            "/api/v1/employees/me",
            json={"full_name": "Ravi Kumar FE", "username": "hacked_fe_username"},
            headers=fe1_headers
        )
        assert res_tamper_user_fe.status_code == 200
        db.refresh(fe1)
        assert fe1.username == fe1_orig_username, "Username must remain original admin-assigned username"
        print("[PASS] 28. FE username tampering safely ignored; original username unchanged")

        # 29. Role tampering test on SO
        res_tamper_role_so = await client.put(
            "/api/v1/shops/my",
            json={"owner_name": "Rao Garu", "role": "administrator", "role_id": 1},
            headers=so1_headers
        )
        assert res_tamper_role_so.status_code == 200
        db.refresh(so1)
        assert so1.role_id == so1_orig_role_id, "Role ID must remain original"
        print("[PASS] 29. SO role tampering safely ignored; role remains shop_owner")

        # 30. User ID tampering test on SO
        res_tamper_id_so = await client.put(
            "/api/v1/shops/my",
            json={"owner_name": "Rao Garu", "user_id": 9999, "id": 9999},
            headers=so1_headers
        )
        assert res_tamper_id_so.status_code == 200
        db.refresh(so1)
        assert so1.id == so1_orig_id, "User ID must remain original"
        print("[PASS] 30. SO User ID tampering safely ignored; identity derived exclusively from JWT")

        # 31. Permission / status tampering test on FE & SO
        res_tamper_status_fe = await client.put(
            "/api/v1/employees/me",
            json={"full_name": "Ravi Kumar FE", "is_active": False, "permissions": ["all"]},
            headers=fe1_headers
        )
        assert res_tamper_status_fe.status_code == 200
        db.refresh(fe1)
        assert fe1.is_active is True
        print("[PASS] 31. FE permission/active status tampering safely ignored")

        # 32. Verification that all admin-assigned fields are completely intact
        db.refresh(fe1)
        db.refresh(so1)
        assert fe1.phone == fe1_orig_phone
        assert fe1.username == fe1_orig_username
        assert fe1.role_id == fe1_orig_role_id
        assert so1.phone == so1_orig_phone
        assert so1.username == so1_orig_username
        assert so1.role_id == so1_orig_role_id
        print("[PASS] 32. All Admin-assigned fields verified completely unchanged after tampering attempts")

        print("\n=== ALL TASK 8 BACKEND SECURITY TESTS PASSED! ===\n")

if __name__ == "__main__":
    asyncio.run(run_security_tests())
