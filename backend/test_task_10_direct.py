import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.environ["AUTO_INIT_DB"] = "False"

from app.core.database import SessionLocal, Base, engine
from app.models.all_models import User, Role, FieldExecutive, ShopOwner
from app.api.employees import update_employee, EmployeeAdminUpdate
from app.api.shops import update_shop, ShopUpdate
from fastapi import HTTPException

def run_tests():
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        # Cleanup any leftovers from previous test runs
        db.query(ShopOwner).filter(ShopOwner.shop_name.in_(['Original Agro Direct', 'Patel Seeds Updated'])).delete(synchronize_session=False)
        db.query(FieldExecutive).filter(FieldExecutive.employee_code.in_(['FE-DIR-001', 'FE-DIR-UPDATED'])).delete(synchronize_session=False)
        db.query(User).filter(User.username.in_(['test_admin_direct', 'test_fe_direct', 'fe_updated_direct', 'test_so_direct', 'patel_so_direct'])).delete(synchronize_session=False)
        db.commit()
        # 1. Setup Roles
        admin_role = db.query(Role).filter(Role.name == "administrator").first()
        fe_role = db.query(Role).filter(Role.name == "field_executive").first()
        so_role = db.query(Role).filter(Role.name == "shop_owner").first()

        assert admin_role and fe_role and so_role, "Roles must exist"

        # 2. Setup Admin User
        admin_user = db.query(User).filter(User.username == "test_admin_direct").first()
        if not admin_user:
            admin_user = User(
                username="test_admin_direct",
                phone="9999200001",
                full_name="Admin Direct",
                role_id=admin_role.id,
                hashed_password="hash",
                is_active=True
            )
            db.add(admin_user)
            db.commit()
            db.refresh(admin_user)

        # 3. Setup FE User
        fe_user = db.query(User).filter(User.username == "test_fe_direct").first()
        if not fe_user:
            fe_user = User(
                username="test_fe_direct",
                phone="9999200002",
                full_name="Original FE Name",
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
                employee_code="FE-DIR-001",
                designation="Field Executive",
                assigned_territory="Guntur Initial"
            )
            db.add(fe_exec)
            db.commit()
            db.refresh(fe_exec)

        # 4. Setup Shop Owner User
        so_user = db.query(User).filter(User.username == "test_so_direct").first()
        if not so_user:
            so_user = User(
                username="test_so_direct",
                phone="9999200003",
                full_name="Original SO Owner",
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
                shop_name="Original Agro Direct",
                market_location="Guntur Mandi",
                address="Plot 5, Main Rd",
                status="Active"
            )
            db.add(shop)
            db.commit()
            db.refresh(shop)

        # --- TEST 1: Non-Admin FE cannot update FE profile (403 Forbidden) ---
        print("[Test 1] Non-admin FE blocked from update_employee...", flush=True)
        try:
            update_employee(
                employee_id=fe_exec.id,
                payload=EmployeeAdminUpdate(full_name="Hacked Name"),
                db=db,
                current_user=fe_user
            )
            assert False, "Should have raised 403"
        except HTTPException as e:
            assert e.status_code == 403, f"Expected 403, got {e.status_code}"
            print("  -> Passed: Non-admin rejected with HTTP 403 Forbidden", flush=True)

        # --- TEST 2: Admin successfully updates FE profile and credentials ---
        print("[Test 2] Admin updates FE Full Name, Phone, Username, Email, Code, Designation, Territory...", flush=True)
        fe_payload = EmployeeAdminUpdate(
            full_name="Updated FE Name",
            phone="9999200088",
            username="fe_updated_direct",
            email="fe_dir@yadvi.com",
            employee_code="FE-DIR-UPDATED",
            designation="Area Sales Manager",
            assigned_territory="Vijayawada Hub"
        )
        res_fe = update_employee(
            employee_id=fe_exec.id,
            payload=fe_payload,
            db=db,
            current_user=admin_user
        )
        assert res_fe.full_name == "Updated FE Name"
        assert res_fe.phone == "9999200088"
        assert res_fe.username == "fe_updated_direct"
        assert res_fe.email == "fe_dir@yadvi.com"
        assert res_fe.employee_code == "FE-DIR-UPDATED"
        assert res_fe.designation == "Area Sales Manager"
        assert res_fe.assigned_territory == "Vijayawada Hub"

        # Verify DB persistence
        db.refresh(fe_user)
        db.refresh(fe_exec)
        assert fe_user.full_name == "Updated FE Name"
        assert fe_user.phone == "9999200088"
        assert fe_user.username == "fe_updated_direct"
        assert fe_user.email == "fe_dir@yadvi.com"
        assert fe_exec.employee_code == "FE-DIR-UPDATED"
        assert fe_exec.designation == "Area Sales Manager"
        assert fe_exec.assigned_territory == "Vijayawada Hub"
        print("  -> Passed: FE profile & credentials successfully updated and persisted in DB!", flush=True)

        # --- TEST 3: FE Phone validation (10 digits) ---
        print("[Test 3] FE Phone validation rejects invalid phone numbers...", flush=True)
        try:
            update_employee(
                employee_id=fe_exec.id,
                payload=EmployeeAdminUpdate(phone="12345"), # Invalid length
                db=db,
                current_user=admin_user
            )
            assert False, "Should have raised 400"
        except HTTPException as e:
            assert e.status_code == 400
            print("  -> Passed: Invalid phone rejected with HTTP 400", flush=True)

        # --- TEST 4: Non-Admin SO cannot update Shop Owner profile (403 Forbidden) ---
        print("[Test 4] Non-admin SO blocked from update_shop...", flush=True)
        try:
            update_shop(
                shop_id=shop.id,
                payload=ShopUpdate(shop_name="Hacked Shop"),
                db=db,
                current_user=so_user
            )
            assert False, "Should have raised 403"
        except HTTPException as e:
            assert e.status_code == 403
            print("  -> Passed: Non-admin rejected with HTTP 403 Forbidden", flush=True)

        # --- TEST 5: Admin successfully updates Shop Owner profile and credentials ---
        print("[Test 5] Admin updates SO Owner Name (optional), Shop Name, Phone, Username, Email, Address, Location, Assigned FE...", flush=True)
        so_payload = ShopUpdate(
            owner_name="Updated Owner Name",
            shop_name="Patel Seeds Updated",
            phone="9999200099",
            username="patel_so_direct",
            email="patel_direct@yadvi.com",
            market_location="Tenali Market",
            address="Near Clock Tower, Shop 4",
            assigned_executive_id=fe_exec.id
        )
        res_so = update_shop(
            shop_id=shop.id,
            payload=so_payload,
            db=db,
            current_user=admin_user
        )
        assert res_so.shop_name == "Patel Seeds Updated"
        assert res_so.owner_name == "Updated Owner Name"
        assert res_so.phone == "9999200099"
        assert res_so.username == "patel_so_direct"
        assert res_so.email == "patel_direct@yadvi.com"
        assert res_so.market_location == "Tenali Market"
        assert res_so.address == "Near Clock Tower, Shop 4"
        assert res_so.assigned_executive_id == fe_exec.id

        # Verify DB persistence
        db.refresh(so_user)
        db.refresh(shop)
        assert shop.shop_name == "Patel Seeds Updated"
        assert so_user.full_name == "Updated Owner Name"
        assert so_user.phone == "9999200099"
        assert so_user.username == "patel_so_direct"
        assert so_user.email == "patel_direct@yadvi.com"
        assert shop.market_location == "Tenali Market"
        assert shop.address == "Near Clock Tower, Shop 4"
        assert shop.assigned_executive_id == fe_exec.id
        print("  -> Passed: SO profile & credentials successfully updated and persisted in DB!", flush=True)

        # --- TEST 6: Owner Name is Optional ---
        print("[Test 6] Admin can update shop with empty owner_name...", flush=True)
        res_so_optional = update_shop(
            shop_id=shop.id,
            payload=ShopUpdate(owner_name=""),
            db=db,
            current_user=admin_user
        )
        db.refresh(so_user)
        assert so_user.full_name is None
        print("  -> Passed: Owner name is optional and nullable!", flush=True)

        # --- TEST 7: Duplicate username rejected ---
        print("[Test 7] Duplicate username rejected with 400...", flush=True)
        try:
            update_employee(
                employee_id=fe_exec.id,
                payload=EmployeeAdminUpdate(username="test_admin_direct"),
                db=db,
                current_user=admin_user
            )
            assert False, "Should have raised 400"
        except HTTPException as e:
            assert e.status_code == 400
            assert "already in use" in e.detail
            print("  -> Passed: Duplicate username rejected with HTTP 400", flush=True)

        print("\n=== ALL TASK 10 BACKEND TESTS PASSED SUCCESSFULLY! ===\n", flush=True)

    finally:
        db.close()

if __name__ == "__main__":
    run_tests()
