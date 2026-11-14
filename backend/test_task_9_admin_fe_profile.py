import os
import sys
import asyncio
from datetime import datetime
import httpx

# Ensure backend directory is in path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.main import app
from app.core.database import SessionLocal, Base, engine
from app.models.all_models import User, Role, FieldExecutive, ShopOwner, Visit
from app.core.security import create_access_token

async def test_task_9_admin_fe_profile():
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    transport = httpx.ASGITransport(app=app)

    async with httpx.AsyncClient(transport=transport, base_url="http://testserver") as client:
        try:
            # 1. Setup Roles
            admin_role = db.query(Role).filter(Role.name == "administrator").first()
            fe_role = db.query(Role).filter(Role.name == "field_executive").first()
            so_role = db.query(Role).filter(Role.name == "shop_owner").first()

            assert admin_role, "Admin role missing"
            assert fe_role, "FE role missing"
            assert so_role, "SO role missing"

            # 2. Setup Admin User
            admin_user = db.query(User).filter(User.username == "test_admin_t9").first()
            if not admin_user:
                admin_user = User(
                    username="test_admin_t9",
                    phone="9999900009",
                    full_name="Test Admin T9",
                    role_id=admin_role.id,
                    hashed_password="hash",
                    is_active=True
                )
                db.add(admin_user)
                db.commit()
                db.refresh(admin_user)

            admin_token = create_access_token({"sub": str(admin_user.id), "role": "administrator"})
            admin_headers = {"Authorization": f"Bearer {admin_token}"}

            # 3. Setup FE User 1 (with shops & visits)
            fe1_user = db.query(User).filter(User.username == "test_fe1_t9").first()
            if not fe1_user:
                fe1_user = User(
                    username="test_fe1_t9",
                    phone="9999900010",
                    full_name="FE One T9",
                    role_id=fe_role.id,
                    hashed_password="hash",
                    is_active=True
                )
                db.add(fe1_user)
                db.commit()
                db.refresh(fe1_user)

            fe1_exec = db.query(FieldExecutive).filter(FieldExecutive.user_id == fe1_user.id).first()
            if not fe1_exec:
                fe1_exec = FieldExecutive(
                    user_id=fe1_user.id,
                    employee_code="FE-T9-001",
                    designation="Field Sales Officer",
                    assigned_territory="Guntur Territory"
                )
                db.add(fe1_exec)
                db.commit()
                db.refresh(fe1_exec)

            # 4. Setup FE User 2 (empty FE with 0 shops & 0 visits)
            fe2_user = db.query(User).filter(User.username == "test_fe2_t9").first()
            if not fe2_user:
                fe2_user = User(
                    username="test_fe2_t9",
                    phone="9999900011",
                    full_name="FE Two T9",
                    role_id=fe_role.id,
                    hashed_password="hash",
                    is_active=True
                )
                db.add(fe2_user)
                db.commit()
                db.refresh(fe2_user)

            fe2_exec = db.query(FieldExecutive).filter(FieldExecutive.user_id == fe2_user.id).first()
            if not fe2_exec:
                fe2_exec = FieldExecutive(
                    user_id=fe2_user.id,
                    employee_code="FE-T9-002",
                    designation="Field Sales Officer",
                    assigned_territory="Krishna Territory"
                )
                db.add(fe2_exec)
                db.commit()
                db.refresh(fe2_exec)

            # 5. Setup Shops for FE 1 and another FE
            # Shop A (assigned to FE 1)
            so_u_a = db.query(User).filter(User.username == "shop_a_t9_user").first()
            if not so_u_a:
                so_u_a = User(
                    username="shop_a_t9_user",
                    phone="9999900012",
                    full_name="Owner A",
                    role_id=so_role.id,
                    hashed_password="hash",
                    is_active=True
                )
                db.add(so_u_a)
                db.commit()
                db.refresh(so_u_a)

            shop_a = db.query(ShopOwner).filter(ShopOwner.user_id == so_u_a.id).first()
            if not shop_a:
                shop_a = ShopOwner(
                    user_id=so_u_a.id,
                    shop_name="Alpha Agri Seeds",
                    market_location="Guntur Market Yard",
                    address="Plot 10, Main Road, Guntur",
                    assigned_executive_id=fe1_exec.id,
                    status="Active"
                )
                db.add(shop_a)
                db.commit()
                db.refresh(shop_a)
            else:
                shop_a.assigned_executive_id = fe1_exec.id
                db.commit()

            # Shop B (assigned to FE 1)
            so_u_b = db.query(User).filter(User.username == "shop_b_t9_user").first()
            if not so_u_b:
                so_u_b = User(
                    username="shop_b_t9_user",
                    phone="9999900013",
                    full_name="Owner B",
                    role_id=so_role.id,
                    hashed_password="hash",
                    is_active=True
                )
                db.add(so_u_b)
                db.commit()
                db.refresh(so_u_b)

            shop_b = db.query(ShopOwner).filter(ShopOwner.user_id == so_u_b.id).first()
            if not shop_b:
                shop_b = ShopOwner(
                    user_id=so_u_b.id,
                    shop_name="Beta Fertilizers",
                    market_location="Tenali Market",
                    address="Near RTC Bus Stand, Tenali",
                    assigned_executive_id=fe1_exec.id,
                    status="Active"
                )
                db.add(shop_b)
                db.commit()
                db.refresh(shop_b)
            else:
                shop_b.assigned_executive_id = fe1_exec.id
                db.commit()

            # Shop C (NOT assigned to FE 1)
            so_u_c = db.query(User).filter(User.username == "shop_c_t9_user").first()
            if not so_u_c:
                so_u_c = User(
                    username="shop_c_t9_user",
                    phone="9999900014",
                    full_name="Owner C",
                    role_id=so_role.id,
                    hashed_password="hash",
                    is_active=True
                )
                db.add(so_u_c)
                db.commit()
                db.refresh(so_u_c)

            shop_c = db.query(ShopOwner).filter(ShopOwner.user_id == so_u_c.id).first()
            if not shop_c:
                shop_c = ShopOwner(
                    user_id=so_u_c.id,
                    shop_name="Gamma Seeds Store",
                    market_location="Vijayawada Market",
                    address="Bunder Road, Vijayawada",
                    assigned_executive_id=None,
                    status="Active"
                )
                db.add(shop_c)
                db.commit()
                db.refresh(shop_c)
            else:
                shop_c.assigned_executive_id = None
                db.commit()

            # 6. Setup Visits for FE 1
            db.query(Visit).filter(Visit.executive_id == fe1_exec.id).delete()
            db.commit()

            # Completed Visit 1 (status = 'Visited')
            v1 = Visit(
                executive_id=fe1_exec.id,
                shop_id=shop_a.id,
                purpose="Stock Verification",
                status="Visited",
                visited_at=datetime.utcnow()
            )
            # Completed Visit 2 (status = 'Completed')
            v2 = Visit(
                executive_id=fe1_exec.id,
                shop_id=shop_b.id,
                purpose="Dealer Audit",
                status="Completed",
                visited_at=datetime.utcnow()
            )
            # Pending Visit 1 (status = 'Pending')
            v3 = Visit(
                executive_id=fe1_exec.id,
                shop_id=shop_a.id,
                purpose="Order Booking",
                status="Pending"
            )
            # Pending Visit 2 (status = 'Scheduled')
            v4 = Visit(
                executive_id=fe1_exec.id,
                shop_id=shop_b.id,
                purpose="Payment Followup",
                status="Scheduled"
            )
            # Cancelled Visit (should NOT be counted in completed or pending)
            v5 = Visit(
                executive_id=fe1_exec.id,
                shop_id=shop_a.id,
                purpose="Demo",
                status="Cancelled"
            )
            db.add_all([v1, v2, v3, v4, v5])
            db.commit()

            print("[TEST] Running Admin FE Profile retrieval for FE 1...")
            res = await client.get(f"/api/v1/employees/{fe1_exec.id}", headers=admin_headers)
            assert res.status_code == 200, f"Expected 200, got {res.status_code}: {res.text}"
            data = res.json()

            # Verify FE Identity
            assert data["id"] == fe1_exec.id
            assert data["full_name"] == "FE One T9"
            assert data["employee_code"] == "FE-T9-001"
            assert data["username"] == "test_fe1_t9"

            # Verify Assigned Shops
            assert "assigned_shops" in data
            assert data["total_assigned_shops"] == 2
            assert len(data["assigned_shops"]) == 2
            shop_names = [s["shop_name"] for s in data["assigned_shops"]]
            assert "Alpha Agri Seeds" in shop_names
            assert "Beta Fertilizers" in shop_names
            assert "Gamma Seeds Store" not in shop_names, "Unassigned shop should not appear"

            # Verify Shop details
            alpha_shop = next(s for s in data["assigned_shops"] if s["shop_name"] == "Alpha Agri Seeds")
            assert alpha_shop["market_location"] == "Guntur Market Yard"
            assert alpha_shop["address"] == "Plot 10, Main Road, Guntur"
            assert alpha_shop["status"] == "Active"

            # Verify Completed and Pending Visits counts
            assert data["completed_visits"] == 2, f"Expected 2 completed visits, got {data['completed_visits']}"
            assert data["pending_visits"] == 2, f"Expected 2 pending visits, got {data['pending_visits']}"

            print("[TEST] Verified FE 1: total_assigned_shops=2, completed_visits=2, pending_visits=2")

            # 7. Verify FE 2 with 0 shops & 0 visits
            print("[TEST] Running Admin FE Profile retrieval for FE 2 (empty)...")
            res2 = await client.get(f"/api/v1/employees/{fe2_exec.id}", headers=admin_headers)
            assert res2.status_code == 200
            data2 = res2.json()
            assert data2["total_assigned_shops"] == 0
            assert data2["assigned_shops"] == []
            assert data2["completed_visits"] == 0
            assert data2["pending_visits"] == 0
            print("[TEST] Verified FE 2: total_assigned_shops=0, completed_visits=0, pending_visits=0")

            # 8. Test alias endpoint /management-details
            res_mgmt = await client.get(f"/api/v1/employees/{fe1_exec.id}/management-details", headers=admin_headers)
            assert res_mgmt.status_code == 200
            assert res_mgmt.json()["total_assigned_shops"] == 2

            # 9. Test Authorization: FE cannot access admin endpoint for another FE
            fe_token = create_access_token({"sub": str(fe1_user.id), "role": "field_executive"})
            fe_headers = {"Authorization": f"Bearer {fe_token}"}
            res_fe = await client.get(f"/api/v1/employees/{fe2_exec.id}", headers=fe_headers)
            assert res_fe.status_code == 403, f"FE accessing admin endpoint should return 403, got {res_fe.status_code}"

            # 10. Test Non-existent FE returns 404
            res_404 = await client.get("/api/v1/employees/999999", headers=admin_headers)
            assert res_404.status_code == 404

            print("\n[TEST] ALL 10 assertions passed successfully for Task 9 Backend API!\n")

        finally:
            db.close()

if __name__ == "__main__":
    asyncio.run(test_task_9_admin_fe_profile())
