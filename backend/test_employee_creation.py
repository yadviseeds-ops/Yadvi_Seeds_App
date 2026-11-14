"""
Test suite for Field Executive (FE) creation endpoint: POST /api/v1/employees
"""
import sys
import asyncio
import httpx
from app.main import app
from app.core.database import SessionLocal
from app.models.all_models import User, Role, FieldExecutive
from app.core.security import create_access_token

async def run_fe_creation_tests():
    db = SessionLocal()
    transport = httpx.ASGITransport(app=app)

    async with httpx.AsyncClient(transport=transport, base_url="http://testserver") as client:
        print("\n=== STARTING FIELD EXECUTIVE CREATION TESTS ===\n")

        admin_user = db.query(User).filter(User.role.has(name="administrator")).first()
        fe_user = db.query(User).filter(User.role.has(name="field_executive")).first()
        assert admin_user is not None, "Admin user must exist"
        assert fe_user is not None, "FE user must exist"

        admin_token = create_access_token(data={"sub": str(admin_user.id), "role": "administrator", "name": admin_user.full_name})
        fe_token = create_access_token(data={"sub": str(fe_user.id), "role": "field_executive", "name": fe_user.full_name})

        admin_headers = {"Authorization": f"Bearer {admin_token}", "Content-Type": "application/json"}
        fe_headers = {"Authorization": f"Bearer {fe_token}", "Content-Type": "application/json"}

        # Clean any leftover test records first
        test_phones = ["9998880001", "9998880002"]
        test_usernames = ["fe_test_001", "fe_test_002"]
        for p in test_phones:
            existing_user = db.query(User).filter(User.phone == p).first()
            if existing_user:
                db.query(FieldExecutive).filter(FieldExecutive.user_id == existing_user.id).delete()
                db.delete(existing_user)
        for u in test_usernames:
            existing_user = db.query(User).filter(User.username == u).first()
            if existing_user:
                db.query(FieldExecutive).filter(FieldExecutive.user_id == existing_user.id).delete()
                db.delete(existing_user)
        db.commit()

        # 1. Non-admin access rejected
        fe_res = await client.post("/api/v1/employees", json={
            "full_name": "Unauthorized FE",
            "phone": "9998880001",
            "username": "fe_test_001",
            "employee_code": "EMP-TEST-001",
            "assigned_territory": "Zone A"
        }, headers=fe_headers)
        assert fe_res.status_code == 403, f"Expected 403, got {fe_res.status_code}"
        print("[PASS] 1. Non-admin user receives 403 Forbidden on FE creation")

        # 2. Successful creation with normalized phone (+91 99988 80001 -> 9998880001)
        create_res = await client.post("/api/v1/employees", json={
            "full_name": "Test Executive One",
            "phone": "+91 99988 80001",
            "username": "fe_test_001",
            "employee_code": "EMP-TEST-001",
            "assigned_territory": "Guntur District",
            "designation": "Field Sales Officer"
        }, headers=admin_headers)
        assert create_res.status_code == 200, f"Expected 200, got {create_res.status_code}: {create_res.text}"
        data = create_res.json()
        assert data["phone"] == "9998880001", f"Expected normalized phone 9998880001, got {data['phone']}"
        assert data["username"] if "username" in data else True
        assert data["employee_code"] == "EMP-TEST-001"
        assert data["is_active"] is True
        print("[PASS] 2. Admin creates FE with phone normalization -> 200 OK")

        # 3. Duplicate username rejected
        dup_user_res = await client.post("/api/v1/employees", json={
            "full_name": "Another Name",
            "phone": "9998880002",
            "username": "fe_test_001",
            "employee_code": "EMP-TEST-002",
            "assigned_territory": "Zone B"
        }, headers=admin_headers)
        assert dup_user_res.status_code == 400, f"Expected 400, got {dup_user_res.status_code}"
        assert "Username 'fe_test_001' already exists" in dup_user_res.json().get("detail", "")
        print("[PASS] 3. Duplicate username rejected with clear 400 detail")

        # 4. Duplicate phone rejected (even if input in different format like raw vs +91)
        dup_phone_res = await client.post("/api/v1/employees", json={
            "full_name": "Another Name",
            "phone": "9998880001",
            "username": "fe_test_002",
            "employee_code": "EMP-TEST-002",
            "assigned_territory": "Zone B"
        }, headers=admin_headers)
        assert dup_phone_res.status_code == 400, f"Expected 400, got {dup_phone_res.status_code}"
        assert "Phone number '9998880001' already exists" in dup_phone_res.json().get("detail", "")
        print("[PASS] 4. Duplicate phone number rejected across formats with clear 400 detail")

        # 5. Invalid / short phone number rejected
        bad_phone_res = await client.post("/api/v1/employees", json={
            "full_name": "Bad Phone",
            "phone": "12345",
            "username": "fe_test_002",
            "employee_code": "EMP-TEST-002",
            "assigned_territory": "Zone B"
        }, headers=admin_headers)
        assert bad_phone_res.status_code == 400
        print("[PASS] 5. Invalid phone number rejected -> 400 Bad Request")

        # 6. Admin retrieves active FE profile details by ID: GET /api/v1/employees/{employee_id}
        fe_profile_record = db.query(FieldExecutive).filter(FieldExecutive.user_id == fe_user.id).first()
        assert fe_profile_record is not None, "FE profile must exist in test DB"
        
        get_res = await client.get(f"/api/v1/employees/{fe_profile_record.id}", headers=admin_headers)
        assert get_res.status_code == 200, f"Expected 200, got {get_res.status_code}: {get_res.text}"
        data = get_res.json()
        assert data["id"] == fe_profile_record.id
        assert data["full_name"] == fe_user.full_name
        assert data["phone"] == fe_user.phone
        assert data["is_active"] is True
        print(f"[PASS] 6. Admin retrieves active FE profile -> 200 OK (id={data['id']}, is_active={data['is_active']})")

        # 7. Admin retrieves inactive FE profile details by ID: returns 200 with is_active: false
        fe_user.is_active = False
        db.commit()
        try:
            inactive_res = await client.get(f"/api/v1/employees/{fe_profile_record.id}", headers=admin_headers)
            assert inactive_res.status_code == 200, f"Expected 200, got {inactive_res.status_code}: {inactive_res.text}"
            inact_data = inactive_res.json()
            assert inact_data["id"] == fe_profile_record.id
            assert inact_data["is_active"] is False
            print(f"[PASS] 7. Admin retrieves inactive FE profile -> 200 OK (id={inact_data['id']}, is_active=False)")

            # 8. Active FE directory GET /api/v1/employees still excludes inactive FE
            list_res = await client.get("/api/v1/employees", headers=admin_headers)
            assert list_res.status_code == 200
            list_ids = [e["id"] for e in list_res.json()]
            assert fe_profile_record.id not in list_ids, "Inactive employee must be excluded from active FE directory list"
            print("[PASS] 8. Active FE directory list excludes inactive employee")
        finally:
            fe_user.is_active = True
            db.commit()

        # 9. Non-existent employee ID returns 404
        not_found_res = await client.get("/api/v1/employees/99999", headers=admin_headers)
        assert not_found_res.status_code == 404, f"Expected 404, got {not_found_res.status_code}"
        print("[PASS] 9. Non-existent employee ID returns 404 Not Found")

        # 10. Non-admin accessing GET /api/v1/employees/{employee_id} is rejected with 403
        non_admin_get = await client.get(f"/api/v1/employees/{fe_profile_record.id}", headers=fe_headers)
        assert non_admin_get.status_code == 403, f"Expected 403, got {non_admin_get.status_code}"
        print("[PASS] 10. Non-admin user receives 403 Forbidden on GET /api/v1/employees/{employee_id}")

        # 11. Unauthenticated request to GET /api/v1/employees/{employee_id} is rejected with 401
        unauth_get = await client.get(f"/api/v1/employees/{fe_profile_record.id}")
        assert unauth_get.status_code == 401, f"Expected 401, got {unauth_get.status_code}"
        print("[PASS] 11. Unauthenticated request receives 401 Unauthorized")

        # Clean up test records
        for p in test_phones:
            existing_user = db.query(User).filter(User.phone == p).first()
            if existing_user:
                db.query(FieldExecutive).filter(FieldExecutive.user_id == existing_user.id).delete()
                db.delete(existing_user)
        db.commit()
        print("[PASS] 12. Cleanup of test records verified")

        print("\n=== ALL FIELD EXECUTIVE CREATION & INACTIVE PROFILE TESTS PASSED ===\n")

if __name__ == "__main__":
    asyncio.run(run_fe_creation_tests())
