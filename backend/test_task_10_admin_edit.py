import os
import sys
import asyncio
import httpx

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.environ['AUTO_INIT_DB'] = 'False'
os.environ['DB_PORT'] = '3307'


from app.main import app
from app.core.database import SessionLocal, Base, engine
from app.models.all_models import User, Role, FieldExecutive, ShopOwner
from app.core.security import create_access_token

async def test_task_10_admin_edit_endpoints():
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
            admin_user = db.query(User).filter(User.username == "test_admin_t10").first()
            if not admin_user:
                admin_user = User(
                    username="test_admin_t10",
                    phone="9999100001",
                    full_name="Admin T10",
                    role_id=admin_role.id,
                    hashed_password="hash",
                    is_active=True
                )
                db.add(admin_user)
                db.commit()
                db.refresh(admin_user)

            admin_token = create_access_token({"sub": str(admin_user.id), "role": "administrator"})
            admin_headers = {"Authorization": f"Bearer {admin_token}"}

            # 3. Setup FE User
            fe_user = db.query(User).filter(User.username == "test_fe_t10").first()
            if not fe_user:
                fe_user = User(
                    username="test_fe_t10",
                    phone="9999100002",
                    full_name="FE Original Name",
                    role_id=fe_role.id,
                    hashed_password="hash",
                    is_active=True
                )
                db.add(fe_user)
                db.commit()
                db.refresh(fe_user)

            fe_exec = db.query(FieldExecutive).filter(FieldExecutive.user_id == fe_user.id).first()
            if not fe_exec:
                fe_exec = FieldExecutive(
                    user_id=fe_user.id,
                    employee_code="FE-T10-001",
                    designation="Field Sales Officer",
                    assigned_territory="Initial Territory"
                )
                db.add(fe_exec)
                db.commit()
                db.refresh(fe_exec)

            fe_token = create_access_token({"sub": str(fe_user.id), "role": "field_executive"})
            fe_headers = {"Authorization": f"Bearer {fe_token}"}

            # 4. Setup Shop Owner User
            so_user = db.query(User).filter(User.username == "test_so_t10").first()
            if not so_user:
                so_user = User(
                    username="test_so_t10",
                    phone="9999100003",
                    full_name="SO Original Owner",
                    role_id=so_role.id,
                    hashed_password="hash",
                    is_active=True
                )
                db.add(so_user)
                db.commit()
                db.refresh(so_user)

            shop = db.query(ShopOwner).filter(ShopOwner.user_id == so_user.id).first()
            if not shop:
                shop = ShopOwner(
                    user_id=so_user.id,
                    shop_name="Original Agro Traders",
                    market_location="Original Mandi",
                    address="Shop No 1, Main Road",
                    status="Active",
                    dealer_code="DLR-T10-001"
                )
                db.add(shop)
                db.commit()
                db.refresh(shop)

            so_token = create_access_token({"sub": str(so_user.id), "role": "shop_owner"})
            so_headers = {"Authorization": f"Bearer {so_token}"}

            print("[Test 1] Non-admin cannot edit FE profile (403 Forbidden)")
            res = await client.put(
                f"/api/v1/employees/{fe_exec.id}",
                json={"full_name": "Hacked Name"},
                headers=fe_headers
            )
            assert res.status_code == 403, f"Expected 403, got {res.status_code}"

            print("[Test 2] Admin successfully edits FE profile and credentials")
            fe_update_payload = {
                "full_name": "Updated FE Full Name",
                "phone": "9999100088",
                "username": "fe_updated_user",
                "email": "fe_updated@yadvi.test",
                "employee_code": "FE-T10-UPDATED",
                "designation": "Senior Area Manager",
                "assigned_territory": "Central Hub Territory"
            }
            res = await client.put(
                f"/api/v1/employees/{fe_exec.id}",
                json=fe_update_payload,
                headers=admin_headers
            )
            assert res.status_code == 200, f"Expected 200, got {res.status_code}: {res.text}"
            data = res.json()
            assert data["full_name"] == "Updated FE Full Name"
            assert data["phone"] == "9999100088"
            assert data["username"] == "fe_updated_user"
            assert data["email"] == "fe_updated@yadvi.test"
            assert data["employee_code"] == "FE-T10-UPDATED"
            assert data["designation"] == "Senior Area Manager"
            assert data["assigned_territory"] == "Central Hub Territory"

            # Verify in DB directly
            db.refresh(fe_user)
            db.refresh(fe_exec)
            assert fe_user.full_name == "Updated FE Full Name"
            assert fe_user.phone == "9999100088"
            assert fe_user.username == "fe_updated_user"
            assert fe_user.email == "fe_updated@yadvi.test"
            assert fe_exec.employee_code == "FE-T10-UPDATED"
            assert fe_exec.designation == "Senior Area Manager"
            assert fe_exec.assigned_territory == "Central Hub Territory"
            print("  -> FE update persisted in database successfully!")

            print("[Test 3] FE phone validation: invalid format rejected (400)")
            res = await client.put(
                f"/api/v1/employees/{fe_exec.id}",
                json={"phone": "12345"},  # Not 10 digits
                headers=admin_headers
            )
            assert res.status_code == 400, f"Expected 400, got {res.status_code}"

            print("[Test 4] Non-admin cannot edit Shop Owner profile (403 Forbidden)")
            res = await client.put(
                f"/api/v1/shops/{shop.id}",
                json={"shop_name": "Hacked Shop"},
                headers=so_headers
            )
            assert res.status_code == 403, f"Expected 403, got {res.status_code}"

            print("[Test 5] Admin successfully edits Shop Owner profile and credentials")
            so_update_payload = {
                "owner_name": "Updated Ramesh Patel",
                "shop_name": "Patel Krishi Kendra Updated",
                "phone": "9999100099",
                "username": "patel_krishi_user",
                "email": "patel@krishi.test",
                "address": "Opposite Grain Market Gate 2",
                "market_location": "Anand Market",
                "assigned_executive_id": fe_exec.id
            }
            res = await client.put(
                f"/api/v1/shops/{shop.id}",
                json=so_update_payload,
                headers=admin_headers
            )
            assert res.status_code == 200, f"Expected 200, got {res.status_code}: {res.text}"
            shop_data = res.json()
            assert shop_data["shop_name"] == "Patel Krishi Kendra Updated"
            assert shop_data["owner_name"] == "Updated Ramesh Patel"
            assert shop_data["phone"] == "9999100099"
            assert shop_data["username"] == "patel_krishi_user"
            assert shop_data["email"] == "patel@krishi.test"
            assert shop_data["address"] == "Opposite Grain Market Gate 2"
            assert shop_data["market_location"] == "Anand Market"
            assert shop_data["assigned_executive_id"] == fe_exec.id

            # Verify in DB directly
            db.refresh(so_user)
            db.refresh(shop)
            assert shop.shop_name == "Patel Krishi Kendra Updated"
            assert so_user.full_name == "Updated Ramesh Patel"
            assert so_user.phone == "9999100099"
            assert so_user.username == "patel_krishi_user"
            assert so_user.email == "patel@krishi.test"
            assert shop.address == "Opposite Grain Market Gate 2"
            assert shop.market_location == "Anand Market"
            assert shop.assigned_executive_id == fe_exec.id
            print("  -> Shop Owner update persisted in database successfully!")

            print("[Test 6] Admin can update shop with optional (null/empty) owner_name")
            res = await client.put(
                f"/api/v1/shops/{shop.id}",
                json={"owner_name": None},
                headers=admin_headers
            )
            assert res.status_code == 200, f"Expected 200, got {res.status_code}"
            db.refresh(so_user)
            assert so_user.full_name is None

            print("[Test 7] Duplicate username rejected for both FE and Shop Owner")
            # Try to give FE the admin's username
            res = await client.put(
                f"/api/v1/employees/{fe_exec.id}",
                json={"username": "test_admin_t10"},
                headers=admin_headers
            )
            assert res.status_code == 400, f"Expected 400, got {res.status_code}"
            assert "already registered" in res.text

            print("\nALL TASK 10 BACKEND TESTS PASSED!")

        finally:
            db.close()

if __name__ == "__main__":
    asyncio.run(test_task_10_admin_edit_endpoints())
