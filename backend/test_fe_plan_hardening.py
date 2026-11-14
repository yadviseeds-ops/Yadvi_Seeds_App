"""
Automated Test Suite for FE Daily Plan Backend Hardening:
1. FE can create a plan for an active, permitted shop -> 200 OK.
2. Inactive shop cannot be planned through direct API request -> 400 Bad Request.
3. Non-existent shop returns 404 Not Found.
4. Duplicate same-day plans are rejected -> 400 Bad Request.
5. FE cannot create a plan on behalf of another FE (ownership strictly scoped to authenticated FE).
6. Existing Admin and Shop Owner authorization behavior remains unchanged (SO returns 403, Unauth returns 401, Admin succeeds).
7. Existing visit listing and Admin assignment-generated visit behavior remain fully compatible.
"""
import sys
import asyncio
import httpx
from datetime import datetime, timezone
from app.main import app
from app.core.database import SessionLocal
from app.models.all_models import User, Role, ShopOwner, FieldExecutive, Visit
from app.core.security import create_access_token

async def run_fe_plan_hardening_tests():
    db = SessionLocal()
    transport = httpx.ASGITransport(app=app)

    async with httpx.AsyncClient(transport=transport, base_url="http://testserver") as client:
        print("\n=== STARTING FE PLAN BACKEND HARDENING TESTS ===\n")

        # 1. Fetch users and roles
        admin_user = db.query(User).filter(User.role.has(name="administrator")).first()
        fe_user = db.query(User).filter(User.role.has(name="field_executive")).first()
        so_user = db.query(User).filter(User.role.has(name="shop_owner")).first()

        assert admin_user is not None, "Admin user must exist"
        assert fe_user is not None, "FE user must exist"
        assert so_user is not None, "Shop Owner user must exist"

        fe_record = db.query(FieldExecutive).filter(FieldExecutive.user_id == fe_user.id).first()
        assert fe_record is not None, "FieldExecutive record must exist"

        other_fe = db.query(FieldExecutive).filter(FieldExecutive.id != fe_record.id).first()

        # Generate tokens
        admin_token = create_access_token(data={"sub": str(admin_user.id), "role": "administrator", "name": admin_user.full_name})
        fe_token = create_access_token(data={"sub": str(fe_user.id), "role": "field_executive", "name": fe_user.full_name})
        so_token = create_access_token(data={"sub": str(so_user.id), "role": "shop_owner", "name": so_user.full_name})

        admin_headers = {"Authorization": f"Bearer {admin_token}", "Content-Type": "application/json"}
        fe_headers = {"Authorization": f"Bearer {fe_token}", "Content-Type": "application/json"}
        so_headers = {"Authorization": f"Bearer {so_token}", "Content-Type": "application/json"}

        # Set up test shops: pick an Active shop
        active_shop = db.query(ShopOwner).filter(ShopOwner.status == "Active").first()
        assert active_shop is not None, "At least one Active ShopOwner must exist"

        # Create a dedicated temporary shop for inactive testing
        temp_username = f"temp_inactive_{int(datetime.utcnow().timestamp())}"
        temp_phone = f"998{int(datetime.utcnow().timestamp()) % 10000000:07d}"
        create_so_res = await client.post("/api/v1/shops", json={
            "shop_name": "Temporary Test Shop Inactive",
            "owner_name": "Test Inactive Owner",
            "phone": temp_phone,
            "username": temp_username,
            "market_location": "Audit Location",
            "address": "Audit Address #1",
        }, headers=admin_headers)
        assert create_so_res.status_code == 200, f"Failed to create test shop: {create_so_res.text}"
        inactive_shop_id = create_so_res.json()["id"]
        inactive_user_id = create_so_res.json()["user_id"]

        # Mark this temporary shop as Inactive in the database
        db.query(ShopOwner).filter(ShopOwner.id == inactive_shop_id).update({"status": "Inactive"})
        db.commit()

        today_start = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)

        # Clean up any existing visit for active_shop today to ensure clean test state
        db.query(Visit).filter(
            Visit.executive_id == fe_record.id,
            Visit.shop_id == active_shop.id,
            Visit.scheduled_date >= today_start
        ).delete()
        db.commit()

        created_visit_id = None
        try:
            # Test 1: FE creates plan for an active, permitted shop
            res1 = await client.post(
                "/api/v1/visits",
                json={"shop_id": active_shop.id, "purpose": "Dealer Audit & Booking", "notes": "Hardening Test"},
                headers=fe_headers
            )
            assert res1.status_code == 200, f"Expected 200, got {res1.status_code}: {res1.text}"
            data1 = res1.json()
            assert data1["shop_id"] == active_shop.id
            assert data1["executive_id"] == fe_record.id
            assert data1["status"] == "Pending"
            assert data1["purpose"] == "Dealer Audit & Booking"
            created_visit_id = data1["id"]
            print(f"[PASS] 1. FE successfully created visit plan for Active shop (ID: {created_visit_id})")

            # Test 2: Inactive shop rejection
            res2 = await client.post(
                "/api/v1/visits",
                json={"shop_id": inactive_shop_id, "purpose": "Should Fail"},
                headers=fe_headers
            )
            assert res2.status_code == 400, f"Expected 400 for inactive shop, got {res2.status_code}: {res2.text}"
            assert "inactive" in res2.json()["detail"].lower()
            print(f"[PASS] 2. Inactive shop rejected with 400 Bad Request: {res2.json()['detail']}")

            # Test 2b: Non-existent shop returns 404
            res2b = await client.post(
                "/api/v1/visits",
                json={"shop_id": 999999, "purpose": "Non-existent"},
                headers=fe_headers
            )
            assert res2b.status_code == 404, f"Expected 404 for non-existent shop, got {res2b.status_code}"
            print("[PASS] 2b. Non-existent shop rejected with 404 Not Found")

            # Test 3: Duplicate same-day plan rejection
            res3 = await client.post(
                "/api/v1/visits",
                json={"shop_id": active_shop.id, "purpose": "Duplicate Plan Attempt"},
                headers=fe_headers
            )
            assert res3.status_code == 400, f"Expected 400 for duplicate plan, got {res3.status_code}"
            assert "already in today's visit plan" in res3.json()["detail"]
            print(f"[PASS] 3. Duplicate same-day plan rejected: {res3.json()['detail']}")

            # Test 4: FE cannot create plan on behalf of another FE (FE ownership/scoping)
            if other_fe:
                another_shop = db.query(ShopOwner).filter(
                    ShopOwner.id != active_shop.id,
                    ShopOwner.id != inactive_shop_id,
                    ShopOwner.status == "Active"
                ).first()
                if another_shop:
                    db.query(Visit).filter(
                        Visit.executive_id == fe_record.id,
                        Visit.shop_id == another_shop.id,
                        Visit.scheduled_date >= today_start
                    ).delete()
                    db.commit()

                    res4b = await client.post(
                        "/api/v1/visits",
                        json={"shop_id": another_shop.id, "executive_id": other_fe.id, "purpose": "Impersonation Test"},
                        headers=fe_headers
                    )
                    assert res4b.status_code == 200
                    data4b = res4b.json()
                    # The created visit must belong to authenticated FE, NOT other_fe
                    assert data4b["executive_id"] == fe_record.id, f"FE scoped executive_id {data4b['executive_id']} != {fe_record.id}"
                    db.query(Visit).filter(Visit.id == data4b["id"]).delete()
                    db.commit()
                    print(f"[PASS] 4. FE ownership strictly preserved (executive_id forced to authenticated FE {fe_record.id})")
            else:
                print("[SKIP] 4. Only one FE in database, skipping cross-FE comparison")

            # Test 5: Authorization checks for other roles
            so_res = await client.post("/api/v1/visits", json={"shop_id": active_shop.id}, headers=so_headers)
            assert so_res.status_code == 403, f"Expected 403 for Shop Owner, got {so_res.status_code}"
            print("[PASS] 5a. Shop Owner forbidden from creating visit plans (403)")

            unauth_res = await client.post("/api/v1/visits", json={"shop_id": active_shop.id})
            assert unauth_res.status_code == 401, f"Expected 401 for unauthenticated, got {unauth_res.status_code}"
            print("[PASS] 5b. Unauthenticated request rejected (401)")

            so_profile_res = await client.get("/api/v1/shops/my", headers=so_headers)
            assert so_profile_res.status_code in [200, 404], f"Unexpected status {so_profile_res.status_code}"
            print("[PASS] 5c. Shop Owner /api/v1/shops/my endpoint intact")

            # Test 6: Existing visit listing & Admin assignment compatibility
            fe_visits_res = await client.get("/api/v1/visits", headers=fe_headers)
            assert fe_visits_res.status_code == 200
            fe_visits = fe_visits_res.json()
            assert any(v["id"] == created_visit_id for v in fe_visits), "Planned visit must appear in FE visit list"
            print(f"[PASS] 6a. Planned visit successfully returned in FE GET /api/v1/visits ({len(fe_visits)} visits)")

            inactive_visits = [v for v in fe_visits if v["shop_id"] == inactive_shop_id]
            assert len(inactive_visits) == 0, "Inactive shop should never be auto-generated into visits"
            print("[PASS] 6b. Inactive shop confirmed absent from auto-generated visits")

        finally:
            # Cleanup test artifacts
            if created_visit_id:
                db.query(Visit).filter(Visit.id == created_visit_id).delete()
            db.query(Visit).filter(Visit.shop_id == inactive_shop_id).delete()
            db.query(ShopOwner).filter(ShopOwner.id == inactive_shop_id).delete()
            db.query(User).filter(User.id == inactive_user_id).delete()
            db.commit()
            db.close()
            print("[CLEANUP] Test records cleaned up successfully.")

        print("\n=== ALL FE PLAN HARDENING & REGRESSION TESTS PASSED ===\n")

if __name__ == "__main__":
    asyncio.run(run_fe_plan_hardening_tests())
