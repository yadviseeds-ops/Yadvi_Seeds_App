"""
Automated Validation Suite for Tasks 4, 6, and 8:
- Task 4: EOD Date-Wise Filtering (GET /api/v1/eod?date=YYYY-MM-DD)
- Task 6: Shop Owner Creation with Optional Owner Full Name (POST /api/v1/shops)
- Task 8: FE Profile Editing (PUT /api/v1/employees/me) & SO Profile Editing (PUT /api/v1/shops/my)
"""
import sys
import asyncio
from datetime import datetime, date, timedelta
import httpx
from app.main import app
from app.core.database import SessionLocal, Base, engine
from app.models.all_models import User, Role, ShopOwner, FieldExecutive, EODReport
from app.core.security import create_access_token

async def run_validation_suite():
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    transport = httpx.ASGITransport(app=app)

    async with httpx.AsyncClient(transport=transport, base_url="http://testserver") as client:
        print("\n=== STARTING VALIDATION TESTS FOR TASKS 4, 6, 8 ===\n")

        admin_user = db.query(User).filter(User.role.has(name="administrator")).first()
        fe_user = db.query(User).filter(User.role.has(name="field_executive")).first()
        so_user = db.query(User).filter(User.role.has(name="shop_owner")).first()

        assert admin_user is not None, "Admin user must exist"
        assert fe_user is not None, "FE user must exist"
        assert so_user is not None, "SO user must exist"

        admin_token = create_access_token(data={"sub": str(admin_user.id), "role": "administrator", "name": admin_user.full_name})
        fe_token = create_access_token(data={"sub": str(fe_user.id), "role": "field_executive", "name": fe_user.full_name})
        so_token = create_access_token(data={"sub": str(so_user.id), "role": "shop_owner", "name": so_user.full_name})

        admin_headers = {"Authorization": f"Bearer {admin_token}", "Content-Type": "application/json"}
        fe_headers = {"Authorization": f"Bearer {fe_token}", "Content-Type": "application/json"}
        so_headers = {"Authorization": f"Bearer {so_token}", "Content-Type": "application/json"}

        # --- TASK 4: EOD DATE-WISE FILTERING ---
        print("--- Testing Task 4: Admin EOD Date-Wise Filtering ---")
        exec_profile = fe_user.field_profile

        # Create or verify an EOD report for a specific test date
        test_date_1 = date(2026, 10, 25)
        test_date_2 = date(2026, 10, 28)

        # Clear existing test EOD reports if any
        db.query(EODReport).filter(EODReport.executive_id == exec_profile.id, EODReport.notes == "Task 4 Test EOD").delete()
        db.commit()

        eod1 = EODReport(
            executive_id=exec_profile.id,
            report_date=datetime(2026, 10, 25, 18, 30, 0),
            completed_visits=5,
            pending_visits=1,
            total_bags_ordered=120,
            notes="Task 4 Test EOD",
            created_at=datetime(2026, 10, 25, 18, 30, 0)
        )
        eod2 = EODReport(
            executive_id=exec_profile.id,
            report_date=datetime(2026, 10, 28, 19, 0, 0),
            completed_visits=8,
            pending_visits=0,
            total_bags_ordered=250,
            notes="Task 4 Test EOD",
            created_at=datetime(2026, 10, 28, 19, 0, 0)
        )
        db.add_all([eod1, eod2])
        db.commit()

        # 1. Fetch without date filter returns both
        res_all = await client.get("/api/v1/eod", headers=admin_headers)
        assert res_all.status_code == 200, f"Expected 200, got {res_all.status_code}"
        all_reports = res_all.json()
        assert len(all_reports) >= 2, "Expected at least 2 EOD reports without filter"
        print("[PASS] 1. Unfiltered EOD request returns all reports")

        # 2. Fetch with date=2026-10-25 returns only reports from that date
        res_25 = await client.get("/api/v1/eod?date=2026-10-25", headers=admin_headers)
        assert res_25.status_code == 200
        reports_25 = res_25.json()
        assert len(reports_25) >= 1
        for r in reports_25:
            r_dt = datetime.fromisoformat(r["report_date"]).date()
            c_dt = datetime.fromisoformat(r["created_at"]).date()
            assert r_dt == test_date_1 or c_dt == test_date_1, f"Report date {r_dt} should match {test_date_1}"
        print("[PASS] 2. Filtered EOD request by date=2026-10-25 returns only matching date reports")

        # 3. Fetch with date=2026-10-28 returns only 2026-10-28
        res_28 = await client.get("/api/v1/eod?date=2026-10-28", headers=admin_headers)
        assert res_28.status_code == 200
        reports_28 = res_28.json()
        assert len(reports_28) >= 1
        for r in reports_28:
            r_dt = datetime.fromisoformat(r["report_date"]).date()
            c_dt = datetime.fromisoformat(r["created_at"]).date()
            assert r_dt == test_date_2 or c_dt == test_date_2, f"Report date {r_dt} should match {test_date_2}"
        print("[PASS] 3. Filtered EOD request by date=2026-10-28 returns only matching date reports")

        # 4. Fetch with date with no reports returns empty list
        res_empty = await client.get("/api/v1/eod?date=2022-01-01", headers=admin_headers)
        assert res_empty.status_code == 200
        assert res_empty.json() == []
        print("[PASS] 4. Filtered EOD request for empty date returns empty list []")

        # 5. Invalid date format returns 400 Bad Request
        res_invalid = await client.get("/api/v1/eod?date=not-a-date", headers=admin_headers)
        assert res_invalid.status_code == 400
        print("[PASS] 5. Invalid date query string returns 400 Bad Request")

        # --- TASK 6: OPTIONAL OWNER FULL NAME ---
        print("\n--- Testing Task 6: Shop Owner Registration with Optional Owner Full Name ---")
        test_so_phone_no_name = "9988776655"
        test_so_user_no_name = "so_no_name_test"

        # Cleanup test SO
        u = db.query(User).filter(User.phone == test_so_phone_no_name).first()
        if u:
            db.query(ShopOwner).filter(ShopOwner.user_id == u.id).delete()
            db.delete(u)
            db.commit()

        # Register shop owner WITHOUT owner_name field
        payload_no_owner = {
            "shop_name": "Kisan Agri Traders",
            "phone": test_so_phone_no_name,
            "username": test_so_user_no_name,
            "market_location": "Nuzvid Market",
            "address": "Opposite Substation, Nuzvid, AP",
        }
        res_create_no_owner = await client.post("/api/v1/shops", json=payload_no_owner, headers=admin_headers)
        assert res_create_no_owner.status_code == 200, f"Expected 200 for optional owner_name, got {res_create_no_owner.status_code}: {res_create_no_owner.text}"
        data_created = res_create_no_owner.json()
        assert data_created["shop_name"] == "Kisan Agri Traders"
        assert data_created["phone"] == test_so_phone_no_name
        assert data_created["owner_name"] is None or data_created["owner_name"] == ""
        print("[PASS] 6. Shop Owner registered successfully without owner_name")

        # Register shop owner with empty string owner_name
        test_so_phone_empty_name = "9988776656"
        test_so_user_empty_name = "so_empty_name_test"
        u2 = db.query(User).filter(User.phone == test_so_phone_empty_name).first()
        if u2:
            db.query(ShopOwner).filter(ShopOwner.user_id == u2.id).delete()
            db.delete(u2)
            db.commit()

        payload_empty_owner = {
            "owner_name": "   ",
            "shop_name": "Green Fields Seeds",
            "phone": test_so_phone_empty_name,
            "username": test_so_user_empty_name,
            "market_location": "Vijayawada Road",
            "address": "Plot 14, Commercial Hub",
        }
        res_create_empty_owner = await client.post("/api/v1/shops", json=payload_empty_owner, headers=admin_headers)
        assert res_create_empty_owner.status_code == 200, f"Expected 200 for whitespace owner_name, got {res_create_empty_owner.status_code}: {res_create_empty_owner.text}"
        print("[PASS] 7. Shop Owner registered successfully with blank/whitespace owner_name")

        # --- TASK 8: FE & SO PROFILE EDITING ---
        print("\n--- Testing Task 8: FE & Shop Owner Profile Editing ---")
        # 1. FE updates full_name and email
        fe_orig_phone = fe_user.phone
        fe_orig_username = fe_user.username

        fe_update_payload = {
            "full_name": "Suresh Babu Updated",
            "email": "suresh.updated@yadvi.com"
        }
        res_fe_update = await client.put("/api/v1/employees/me", json=fe_update_payload, headers=fe_headers)
        assert res_fe_update.status_code == 200, f"Expected 200 for FE profile update, got {res_fe_update.status_code}: {res_fe_update.text}"
        fe_updated_data = res_fe_update.json()
        assert fe_updated_data["full_name"] == "Suresh Babu Updated"
        assert fe_updated_data["email"] == "suresh.updated@yadvi.com"
        # Verify phone & username were NOT modified
        assert fe_updated_data["phone"] == fe_orig_phone
        db.refresh(fe_user)
        assert fe_user.username == fe_orig_username
        print("[PASS] 8. FE profile updated successfully (full_name and email); phone and username preserved")

        # 2. FE cannot access PUT /api/v1/employees/me without auth or as shop owner
        res_fe_unauth = await client.put("/api/v1/employees/me", json=fe_update_payload, headers=so_headers)
        assert res_fe_unauth.status_code == 403
        print("[PASS] 9. Role-based isolation enforced for FE profile update (SO receives 403)")

        # 3. Shop Owner updates profile (owner_name, shop_name, email, address, market_location)
        so_orig_phone = so_user.phone
        so_orig_username = so_user.username

        so_update_payload = {
            "owner_name": "Venkat Rao Updated",
            "shop_name": "Sri Venkateswara Seeds & Fertilisers",
            "email": "venkat.updated@yadvi.com",
            "address": "Main Bazaar, Opp Clock Tower, Guntur",
            "market_location": "Guntur Market Yard"
        }
        res_so_update = await client.put("/api/v1/shops/my", json=so_update_payload, headers=so_headers)
        assert res_so_update.status_code == 200, f"Expected 200 for SO profile update, got {res_so_update.status_code}: {res_so_update.text}"
        so_updated_data = res_so_update.json()
        assert so_updated_data["owner_name"] == "Venkat Rao Updated"
        assert so_updated_data["shop_name"] == "Sri Venkateswara Seeds & Fertilisers"
        assert so_updated_data["email"] == "venkat.updated@yadvi.com"
        assert so_updated_data["address"] == "Main Bazaar, Opp Clock Tower, Guntur"
        assert so_updated_data["market_location"] == "Guntur Market Yard"
        # Verify phone & username are immutable
        assert so_updated_data["phone"] == so_orig_phone
        db.refresh(so_user)
        assert so_user.username == so_orig_username
        print("[PASS] 10. SO profile updated successfully; phone and username immutable")

        # 4. Cleanup test created shop owners
        db.query(ShopOwner).filter(ShopOwner.user_id.in_([u.id if u else 0, u2.id if u2 else 0])).delete()
        for test_u in db.query(User).filter(User.phone.in_([test_so_phone_no_name, test_so_phone_empty_name])).all():
            db.query(ShopOwner).filter(ShopOwner.user_id == test_u.id).delete()
            db.delete(test_u)
        db.commit()

        print("\n=== ALL 10 TESTS FOR TASKS 4, 6, AND 8 PASSED SUCCESSFULLY! ===\n")

if __name__ == "__main__":
    asyncio.run(run_validation_suite())
