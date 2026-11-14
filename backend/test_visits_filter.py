"""
Test suite for GET /api/v1/visits endpoint with executive_id filter and role-based scoping.
"""
import asyncio
import httpx
from datetime import datetime, timezone
from app.main import app
from app.core.database import SessionLocal
from app.models.all_models import User, Role, FieldExecutive, ShopOwner, Visit
from app.core.security import create_access_token

async def run_visits_filter_tests():
    db = SessionLocal()
    transport = httpx.ASGITransport(app=app)

    async with httpx.AsyncClient(transport=transport, base_url="http://testserver") as client:
        print("\n=== STARTING VISITS FILTER & SECURITY TESTS ===\n")

        admin_user = db.query(User).filter(User.role.has(name="administrator")).first()
        fe_user = db.query(User).filter(User.role.has(name="field_executive")).first()
        assert admin_user is not None, "Admin user must exist"
        assert fe_user is not None, "FE user must exist"

        admin_token = create_access_token(data={"sub": str(admin_user.id), "role": "administrator", "name": admin_user.full_name})
        fe_token = create_access_token(data={"sub": str(fe_user.id), "role": "field_executive", "name": fe_user.full_name})

        admin_headers = {"Authorization": f"Bearer {admin_token}", "Content-Type": "application/json"}
        fe_headers = {"Authorization": f"Bearer {fe_token}", "Content-Type": "application/json"}

        # 1. Unauthenticated rejected
        unauth_res = await client.get("/api/v1/visits")
        assert unauth_res.status_code == 401, f"Expected 401, got {unauth_res.status_code}"
        print("[PASS] 1. Unauthenticated request to /api/v1/visits returns 401")

        # 2. Admin can fetch all visits
        admin_all_res = await client.get("/api/v1/visits", headers=admin_headers)
        assert admin_all_res.status_code == 200, f"Expected 200, got {admin_all_res.status_code}"
        all_visits = admin_all_res.json()
        print(f"[PASS] 2. Admin fetches all visits ({len(all_visits)} visits found)")

        # Create 2 test visits for test FE and another FE if needed
        fe_record = db.query(FieldExecutive).filter(FieldExecutive.user_id == fe_user.id).first()
        assert fe_record is not None, "FieldExecutive record for FE user must exist"

        test_shop = db.query(ShopOwner).first()
        assert test_shop is not None, "At least one ShopOwner must exist for visit tests"

        v1 = Visit(
            executive_id=fe_record.id,
            shop_id=test_shop.id,
            status="Visited",
            purpose="Routine Check",
            notes="Completed routine visit with test shop",
            scheduled_date=datetime.now(timezone.utc),
            visited_at=datetime.now(timezone.utc),
        )
        v2 = Visit(
            executive_id=fe_record.id,
            shop_id=test_shop.id,
            status="Pending",
            purpose="Payment Collection",
            notes="Pending payment follow up",
            scheduled_date=datetime.now(timezone.utc),
        )
        # Dummy visit with a non-existent / other executive_id (e.g. 99999)
        v_other = Visit(
            executive_id=99999,
            shop_id=test_shop.id,
            status="Visited",
            purpose="Other Exec Visit",
            notes="Belongs to different FE",
            scheduled_date=datetime.now(timezone.utc),
        )

        db.add_all([v1, v2, v_other])
        db.commit()
        db.refresh(v1)
        db.refresh(v2)
        db.refresh(v_other)

        try:
            # 3. Admin filtered by executive_id
            admin_fe_res = await client.get(f"/api/v1/visits?executive_id={fe_record.id}", headers=admin_headers)
            assert admin_fe_res.status_code == 200
            fe_visits = admin_fe_res.json()
            assert len(fe_visits) >= 2, f"Expected at least 2 visits for FE {fe_record.id}"
            for v in fe_visits:
                assert v["executive_id"] == fe_record.id, f"Visit {v['id']} executive_id {v['executive_id']} != {fe_record.id}"
                assert "shop_name" in v
                assert v["shop_name"] is not None
            print(f"[PASS] 3. Admin filter ?executive_id={fe_record.id} returns only FE's visits with shop_name included")

            # 4. Filter for executive_id 99999 returns only v_other
            other_res = await client.get("/api/v1/visits?executive_id=99999", headers=admin_headers)
            assert other_res.status_code == 200
            other_visits = other_res.json()
            assert len(other_visits) == 1
            assert other_visits[0]["id"] == v_other.id
            assert other_visits[0]["executive_id"] == 99999
            print("[PASS] 4. Filtering by another executive_id isolates only that executive's visits")

            # 5. Field Executive requesting visits cannot access another executive's visits
            fe_scoped_res = await client.get("/api/v1/visits?executive_id=99999", headers=fe_headers)
            assert fe_scoped_res.status_code == 200
            fe_data = fe_scoped_res.json()
            # FE must only see their own visits regardless of the query param
            for v in fe_data:
                assert v["executive_id"] == fe_record.id
                assert v["id"] != v_other.id
            print("[PASS] 5. Field Executive is strictly scoped to their own visits and cannot see other FE visits")

            # 6. Verify Completed and Pending visit data fields
            completed_match = next((v for v in fe_visits if v["id"] == v1.id), None)
            pending_match = next((v for v in fe_visits if v["id"] == v2.id), None)
            assert completed_match is not None
            assert pending_match is not None
            assert completed_match["status"] == "Visited"
            assert completed_match["shop_id"] == test_shop.id
            assert completed_match["shop_name"] == test_shop.shop_name
            assert completed_match["visited_at"] is not None
            assert pending_match["status"] == "Pending"
            assert pending_match["shop_id"] == test_shop.id
            assert pending_match["shop_name"] == test_shop.shop_name
            print("[PASS] 6. Completed and Pending visits accurately include shop_name, shop_id, and timestamps")

        finally:
            # Clean up test visits
            db.delete(v1)
            db.delete(v2)
            db.delete(v_other)
            db.commit()
            db.close()

        print("\n=== ALL VISITS FILTER & SECURITY TESTS PASSED ===\n")

if __name__ == "__main__":
    asyncio.run(run_visits_filter_tests())
