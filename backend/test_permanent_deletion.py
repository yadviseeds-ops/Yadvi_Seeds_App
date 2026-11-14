"""
Automated Test Suite for Safe Permanent Deletion:
- Field Executives (FE): DELETE /api/v1/employees/{employee_id}
- Shop Owners (SO): DELETE /api/v1/shops/{shop_id}
- Products: DELETE /api/v1/products/{product_id}

Covers:
1. Authorization checks: 401 Unauthorized (unauthenticated), 403 Forbidden (non-admin).
2. Missing IDs: 404 Not Found.
3. Eligible permanent deletion with database verification (records completely removed).
4. Dependent historical business records rejection: 400 Bad Request (orders, visits, attendance, EOD, order items).
5. Ephemeral data cleanup (telemetry locations, FCM tokens, inventory staging batches).
6. Dependent shop assignment unlinking on FE deletion.
7. Rollback behavior on exception.
8. Execution against an isolated SQLite test database.
"""
import os
import sys
import asyncio
import httpx
from datetime import datetime
from unittest.mock import patch

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.main import app
from app.core.database import Base, get_db
from app.core.security import create_access_token, get_password_hash
from app.models.all_models import (
    Role, User, FieldExecutive, ShopOwner, Product, Inventory,
    Order, OrderItem, Visit, Attendance, EODReport, FELocation, FCMDeviceToken
)

TEST_DB_FILE = "test_deletion_isolated.db"
TEST_DB_URL = f"sqlite:///{TEST_DB_FILE}"

test_engine = create_engine(TEST_DB_URL, connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=test_engine)

def override_get_db():
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


async def run_permanent_deletion_tests():
    print("\n========================================================")
    print("STARTING SAFE PERMANENT DELETION TEST SUITE (ISOLATED DB)")
    print("========================================================\n")

    # 1. Initialize isolated database schema
    Base.metadata.drop_all(bind=test_engine)
    Base.metadata.create_all(bind=test_engine)

    app.dependency_overrides[get_db] = override_get_db

    # 2. Seed Roles and Seed Users in initial session
    with TestingSessionLocal() as db:
        admin_role = Role(name="administrator", description="Admin")
        fe_role = Role(name="field_executive", description="FE")
        so_role = Role(name="shop_owner", description="SO")
        db.add_all([admin_role, fe_role, so_role])
        db.commit()

        admin_role_id = admin_role.id
        fe_role_id = fe_role.id
        so_role_id = so_role.id

        admin_user = User(
            full_name="Admin Test User",
            phone="9000000001",
            username="admin_test",
            role_id=admin_role_id,
            hashed_password=get_password_hash("adminpass123"),
            is_active=True
        )
        non_admin_user = User(
            full_name="FE Test NonAdmin",
            phone="9000000002",
            username="fe_test_nonadmin",
            role_id=fe_role_id,
            hashed_password=get_password_hash("fepass123"),
            is_active=True
        )
        db.add_all([admin_user, non_admin_user])
        db.commit()

        admin_user_id = admin_user.id
        admin_user_name = admin_user.full_name
        non_admin_id = non_admin_user.id
        non_admin_name = non_admin_user.full_name

    admin_token = create_access_token(data={"sub": str(admin_user_id), "role": "administrator", "name": admin_user_name})
    fe_token = create_access_token(data={"sub": str(non_admin_id), "role": "field_executive", "name": non_admin_name})

    admin_headers = {"Authorization": f"Bearer {admin_token}", "Content-Type": "application/json"}
    non_admin_headers = {"Authorization": f"Bearer {fe_token}", "Content-Type": "application/json"}

    transport = httpx.ASGITransport(app=app)
    async with httpx.AsyncClient(transport=transport, base_url="http://testserver") as client:

        # -----------------------------------------------------------------
        # TEST GROUP 1: AUTHORIZATION CHECKS (401 & 403)
        # -----------------------------------------------------------------
        print("--- 1. AUTHORIZATION CHECKS ---")

        # 1.1 Unauthenticated requests rejected (401)
        for path in ["/api/v1/employees/1", "/api/v1/shops/1", "/api/v1/products/1"]:
            res = await client.delete(path)
            assert res.status_code == 401, f"Expected 401 for unauthenticated {path}, got {res.status_code}"
        print("[PASS] 1.1 Unauthenticated requests rejected with 401 Unauthorized for FE, SO, and Products")

        # 1.2 Non-admin requests rejected (403)
        for path in ["/api/v1/employees/1", "/api/v1/shops/1", "/api/v1/products/1"]:
            res = await client.delete(path, headers=non_admin_headers)
            assert res.status_code == 403, f"Expected 403 for non-admin {path}, got {res.status_code}"
        print("[PASS] 1.2 Non-admin requests rejected with 403 Forbidden for FE, SO, and Products")

        # -----------------------------------------------------------------
        # TEST GROUP 2: MISSING RECORD IDENTIFIERS (404)
        # -----------------------------------------------------------------
        print("\n--- 2. MISSING IDENTIFIERS (404 NOT FOUND) ---")

        res_fe_404 = await client.delete("/api/v1/employees/9999", headers=admin_headers)
        assert res_fe_404.status_code == 404
        assert "Field executive not found" in res_fe_404.json()["detail"]

        res_so_404 = await client.delete("/api/v1/shops/9999", headers=admin_headers)
        assert res_so_404.status_code == 404
        assert "Shop owner not found" in res_so_404.json()["detail"]

        res_prod_404 = await client.delete("/api/v1/products/9999", headers=admin_headers)
        assert res_prod_404.status_code == 404
        assert "Product not found" in res_prod_404.json()["detail"]

        print("[PASS] 2.1 Missing IDs return 404 Not Found with clear detail message")

        # -----------------------------------------------------------------
        # TEST GROUP 3: FIELD EXECUTIVE DELETION
        # -----------------------------------------------------------------
        print("\n--- 3. FIELD EXECUTIVE DELETION ---")

        # 3.1 Eligible FE Permanent Deletion
        with TestingSessionLocal() as db:
            u_fe = User(full_name="Ramesh FE", phone="9111111101", username="fe_ramesh", role_id=fe_role_id, is_active=True)
            db.add(u_fe)
            db.commit()
            fe_obj = FieldExecutive(user_id=u_fe.id, employee_code="EMP-RAMESH-1", assigned_territory="Guntur")
            db.add(fe_obj)
            db.commit()

            fe_id = fe_obj.id
            u_fe_id = u_fe.id

            # Add ephemeral location, device token, and assigned shop
            fe_loc = FELocation(executive_id=fe_id, lat=16.3, lng=80.4)
            fe_tok = FCMDeviceToken(user_id=u_fe_id, device_token="token_ramesh_123")
            u_shop = User(full_name="Dealer 1", phone="9222222201", username="dealer_1", role_id=so_role_id, is_active=True)
            db.add_all([fe_loc, fe_tok, u_shop])
            db.commit()

            shop_obj = ShopOwner(
                user_id=u_shop.id, shop_name="Dealer Agro", market_location="Guntur",
                address="Main Rd", assigned_executive_id=fe_id
            )
            db.add(shop_obj)
            db.commit()
            shop_id_val = shop_obj.id

        del_fe_res = await client.delete(f"/api/v1/employees/{fe_id}", headers=admin_headers)
        assert del_fe_res.status_code == 200, f"Expected 200, got {del_fe_res.status_code}: {del_fe_res.text}"
        assert del_fe_res.json()["success"] is True

        # Database-level verification
        with TestingSessionLocal() as db:
            assert db.query(FieldExecutive).filter(FieldExecutive.id == fe_id).first() is None, "FE record must be permanently removed"
            assert db.query(User).filter(User.id == u_fe_id).first() is None, "Associated User record must be permanently removed"
            assert db.query(FELocation).filter(FELocation.executive_id == fe_id).all() == [], "Telemetry locations must be deleted"
            assert db.query(FCMDeviceToken).filter(FCMDeviceToken.user_id == u_fe_id).all() == [], "Device token must be deleted"
            
            reloaded_shop = db.query(ShopOwner).filter(ShopOwner.id == shop_id_val).first()
            assert reloaded_shop is not None
            assert reloaded_shop.assigned_executive_id is None, "Shop assignment must be unlinked to None"
        print("[PASS] 3.1 Eligible FE permanently deleted from SQL DB, telemetry/tokens cleaned, assigned shop unlinked")

        # 3.2 Ineligible FE: Has Visits -> Rejected (400)
        with TestingSessionLocal() as db:
            u_fe2 = User(full_name="Suresh FE", phone="9111111102", username="fe_suresh", role_id=fe_role_id, is_active=True)
            db.add(u_fe2)
            db.commit()
            fe_obj2 = FieldExecutive(user_id=u_fe2.id, employee_code="EMP-SURESH-2", assigned_territory="Vijayawada")
            db.add(fe_obj2)
            db.commit()
            fe_id2 = fe_obj2.id
            u_fe_id2 = u_fe2.id

            visit_record = Visit(executive_id=fe_id2, shop_id=shop_id_val, notes="Field visit")
            db.add(visit_record)
            db.commit()
            visit_id = visit_record.id

        rej_fe_res = await client.delete(f"/api/v1/employees/{fe_id2}", headers=admin_headers)
        assert rej_fe_res.status_code == 400
        assert "historical visit records must be preserved" in rej_fe_res.json()["detail"].lower()

        with TestingSessionLocal() as db:
            assert db.query(FieldExecutive).filter(FieldExecutive.id == fe_id2).first() is not None
            assert db.query(User).filter(User.id == u_fe_id2).first() is not None
            assert db.query(Visit).filter(Visit.id == visit_id).first() is not None
        print("[PASS] 3.2 FE deletion rejected (400) when historical visits exist; DB records preserved")

        # 3.3 Ineligible FE: Has Attendance -> Rejected (400)
        with TestingSessionLocal() as db:
            v_to_del = db.query(Visit).filter(Visit.id == visit_id).first()
            if v_to_del:
                db.delete(v_to_del)
            att_record = Attendance(executive_id=fe_id2, status="Present")
            db.add(att_record)
            db.commit()
            att_id = att_record.id

        rej_att_res = await client.delete(f"/api/v1/employees/{fe_id2}", headers=admin_headers)
        assert rej_att_res.status_code == 400
        assert "attendance history must be preserved" in rej_att_res.json()["detail"].lower()
        with TestingSessionLocal() as db:
            assert db.query(FieldExecutive).filter(FieldExecutive.id == fe_id2).first() is not None
            assert db.query(Attendance).filter(Attendance.id == att_id).first() is not None
        print("[PASS] 3.3 FE deletion rejected (400) when historical attendance exists; DB records preserved")

        # 3.4 Ineligible FE: Has EOD Reports -> Rejected (400)
        with TestingSessionLocal() as db:
            a_to_del = db.query(Attendance).filter(Attendance.id == att_id).first()
            if a_to_del:
                db.delete(a_to_del)
            eod_record = EODReport(executive_id=fe_id2, completed_visits=5)
            db.add(eod_record)
            db.commit()
            eod_id = eod_record.id

        rej_eod_res = await client.delete(f"/api/v1/employees/{fe_id2}", headers=admin_headers)
        assert rej_eod_res.status_code == 400
        assert "daily reports must be preserved" in rej_eod_res.json()["detail"].lower()
        with TestingSessionLocal() as db:
            assert db.query(FieldExecutive).filter(FieldExecutive.id == fe_id2).first() is not None
            assert db.query(EODReport).filter(EODReport.id == eod_id).first() is not None
        print("[PASS] 3.4 FE deletion rejected (400) when historical EOD report exists; DB records preserved")

        # 3.5 Ineligible FE: Has Orders -> Rejected (400)
        with TestingSessionLocal() as db:
            e_to_del = db.query(EODReport).filter(EODReport.id == eod_id).first()
            if e_to_del:
                db.delete(e_to_del)
            order_fe = Order(order_number="ORD-FE-TEST", shop_id=shop_id_val, assigned_executive_id=fe_id2, total_items_count=1)
            db.add(order_fe)
            db.commit()
            order_fe_id = order_fe.id

        rej_ord_res = await client.delete(f"/api/v1/employees/{fe_id2}", headers=admin_headers)
        assert rej_ord_res.status_code == 400
        assert "order assignment history must be preserved" in rej_ord_res.json()["detail"].lower()
        with TestingSessionLocal() as db:
            assert db.query(FieldExecutive).filter(FieldExecutive.id == fe_id2).first() is not None
            assert db.query(Order).filter(Order.id == order_fe_id).first() is not None
        print("[PASS] 3.5 FE deletion rejected (400) when assigned orders exist; DB records preserved")

        # -----------------------------------------------------------------
        # TEST GROUP 4: SHOP OWNER DELETION
        # -----------------------------------------------------------------
        print("\n--- 4. SHOP OWNER DELETION ---")

        # 4.1 Eligible SO Permanent Deletion
        with TestingSessionLocal() as db:
            u_so_del = User(full_name="Dealer Deletable", phone="9222222202", username="dealer_del", role_id=so_role_id, is_active=True)
            db.add(u_so_del)
            db.commit()
            so_obj_del = ShopOwner(
                user_id=u_so_del.id, shop_name="Deletable Agro", market_location="Tenali",
                address="Tenali Bazaar"
            )
            so_tok = FCMDeviceToken(user_id=u_so_del.id, device_token="token_so_del_123")
            db.add_all([so_obj_del, so_tok])
            db.commit()
            so_del_id = so_obj_del.id
            u_so_del_id = u_so_del.id

        del_so_res = await client.delete(f"/api/v1/shops/{so_del_id}", headers=admin_headers)
        assert del_so_res.status_code == 200, f"Expected 200, got {del_so_res.status_code}: {del_so_res.text}"
        assert del_so_res.json()["success"] is True

        with TestingSessionLocal() as db:
            assert db.query(ShopOwner).filter(ShopOwner.id == so_del_id).first() is None, "ShopOwner record must be permanently removed"
            assert db.query(User).filter(User.id == u_so_del_id).first() is None, "Associated User record must be permanently removed"
            assert db.query(FCMDeviceToken).filter(FCMDeviceToken.user_id == u_so_del_id).all() == [], "Device token must be deleted"
        print("[PASS] 4.1 Eligible SO permanently deleted from SQL DB, user account & device token deleted")

        # 4.2 Ineligible SO: Has Orders -> Rejected (400)
        with TestingSessionLocal() as db:
            u_so_keep = User(full_name="Dealer With Orders", phone="9222222203", username="dealer_orders", role_id=so_role_id, is_active=True)
            db.add(u_so_keep)
            db.commit()
            so_obj_keep = ShopOwner(
                user_id=u_so_keep.id, shop_name="Orders Agro", market_location="Guntur",
                address="Guntur Market"
            )
            db.add(so_obj_keep)
            db.commit()
            so_keep_id = so_obj_keep.id
            u_so_keep_id = u_so_keep.id

            so_order = Order(order_number="ORD-SO-HIST", shop_id=so_keep_id, total_items_count=2)
            db.add(so_order)
            db.commit()
            so_order_id = so_order.id

        rej_so_res = await client.delete(f"/api/v1/shops/{so_keep_id}", headers=admin_headers)
        assert rej_so_res.status_code == 400
        assert "historical order records must be preserved" in rej_so_res.json()["detail"].lower()

        with TestingSessionLocal() as db:
            assert db.query(ShopOwner).filter(ShopOwner.id == so_keep_id).first() is not None
            assert db.query(User).filter(User.id == u_so_keep_id).first() is not None
            assert db.query(Order).filter(Order.id == so_order_id).first() is not None
        print("[PASS] 4.2 SO deletion rejected (400) when orders exist; DB records preserved")

        # 4.3 Ineligible SO: Has Field Visits -> Rejected (400)
        with TestingSessionLocal() as db:
            o_to_del = db.query(Order).filter(Order.id == so_order_id).first()
            if o_to_del:
                db.delete(o_to_del)
            so_visit = Visit(executive_id=fe_id2, shop_id=so_keep_id, notes="Inspection")
            db.add(so_visit)
            db.commit()
            so_visit_id = so_visit.id

        rej_so_vis_res = await client.delete(f"/api/v1/shops/{so_keep_id}", headers=admin_headers)
        assert rej_so_vis_res.status_code == 400
        assert "historical visit records must be preserved" in rej_so_vis_res.json()["detail"].lower()

        with TestingSessionLocal() as db:
            assert db.query(ShopOwner).filter(ShopOwner.id == so_keep_id).first() is not None
            assert db.query(Visit).filter(Visit.id == so_visit_id).first() is not None
        print("[PASS] 4.3 SO deletion rejected (400) when visits exist; DB records preserved")

        # -----------------------------------------------------------------
        # TEST GROUP 5: PRODUCT DELETION
        # -----------------------------------------------------------------
        print("\n--- 5. PRODUCT DELETION ---")

        # 5.1 Eligible Product Permanent Deletion
        with TestingSessionLocal() as db:
            prod_del = Product(
                name="Yadvi Test Chilli F1", variety_type="Hot Pepper", sku="SKU-CHILLI-DEL",
                category="Chilli", image_url="https://storage/chilli.jpg"
            )
            db.add(prod_del)
            db.commit()
            inv_del = Inventory(product_id=prod_del.id, batch_number="B-DEL-01", total_bags=100)
            db.add(inv_del)
            db.commit()
            prod_del_id = prod_del.id

        del_prod_res = await client.delete(f"/api/v1/products/{prod_del_id}", headers=admin_headers)
        assert del_prod_res.status_code == 200, f"Expected 200, got {del_prod_res.status_code}: {del_prod_res.text}"
        assert del_prod_res.json()["success"] is True

        with TestingSessionLocal() as db:
            assert db.query(Product).filter(Product.id == prod_del_id).first() is None, "Product record must be permanently removed"
            assert db.query(Inventory).filter(Inventory.product_id == prod_del_id).all() == [], "Inventory batches must be removed"
        print("[PASS] 5.1 Eligible Product permanently deleted from SQL DB, inventory staging batches deleted")

        # 5.2 Ineligible Product: Has Order Items -> Rejected (400)
        with TestingSessionLocal() as db:
            prod_keep = Product(
                name="Yadvi Tomato Super", variety_type="Tomato", sku="SKU-TOMATO-KEEP",
                category="Vegetables", image_url="https://storage/tomato.jpg"
            )
            db.add(prod_keep)
            db.commit()
            prod_keep_id = prod_keep.id

            dummy_order = Order(order_number="ORD-PROD-TEST", shop_id=so_keep_id, total_items_count=1)
            db.add(dummy_order)
            db.commit()

            order_item = OrderItem(order_id=dummy_order.id, product_id=prod_keep_id, package_size="100g", quantity_bags=10, quantity=1.0)
            db.add(order_item)
            db.commit()
            order_item_id = order_item.id

        rej_prod_res = await client.delete(f"/api/v1/products/{prod_keep_id}", headers=admin_headers)
        assert rej_prod_res.status_code == 400
        assert "order history must be preserved" in rej_prod_res.json()["detail"].lower()

        with TestingSessionLocal() as db:
            assert db.query(Product).filter(Product.id == prod_keep_id).first() is not None
            assert db.query(OrderItem).filter(OrderItem.id == order_item_id).first() is not None
        print("[PASS] 5.2 Product deletion rejected (400) when order items exist; DB records preserved")

        # -----------------------------------------------------------------
        # TEST GROUP 6: ROLLBACK BEHAVIOR ON EXCEPTION
        # -----------------------------------------------------------------
        print("\n--- 6. ROLLBACK ON EXCEPTION ---")

        with TestingSessionLocal() as db:
            prod_rb = Product(
                name="Yadvi Rollback Test", variety_type="Okra", sku="SKU-OKRA-RB",
                category="Okra", image_url="https://storage/okra.jpg"
            )
            db.add(prod_rb)
            db.commit()
            prod_rb_id = prod_rb.id

        # Mock db.commit to raise an exception during delete_product
        with patch("sqlalchemy.orm.Session.commit", side_effect=Exception("Simulated DB Disk Failure")):
            rb_res = await client.delete(f"/api/v1/products/{prod_rb_id}", headers=admin_headers)
            assert rb_res.status_code == 500, f"Expected 500, got {rb_res.status_code}"
            assert "Database error" in rb_res.json()["detail"]

        with TestingSessionLocal() as db:
            assert db.query(Product).filter(Product.id == prod_rb_id).first() is not None, "Product must remain after rollback"
        # -----------------------------------------------------------------
        # TEST GROUP 7: FE & SO DELETION CONSISTENCY WITH PRODUCTS PATTERN
        # -----------------------------------------------------------------
        print("\n--- 7. FE & SO DELETION CONSISTENCY WITH PRODUCTS PATTERN ---")

        # 7.1 Verify FE deletion leaves zero orphan user records
        with TestingSessionLocal() as db:
            fe_user = User(
                full_name="Consistency FE", phone="9000000088", username="fe_consist",
                role_id=fe_role_id, is_active=True
            )
            db.add(fe_user)
            db.commit()
            fe_prof = FieldExecutive(
                user_id=fe_user.id, employee_code="YHS-EMP-998", assigned_territory="Guntur"
            )
            db.add(fe_prof)
            db.commit()
            fe_prof_id = fe_prof.id
            fe_user_id = fe_user.id

        fe_del_res = await client.delete(f"/api/v1/employees/{fe_prof_id}", headers=admin_headers)
        assert fe_del_res.status_code == 200, f"Expected 200, got {fe_del_res.status_code}: {fe_del_res.text}"
        assert fe_del_res.json()["success"] is True

        with TestingSessionLocal() as db:
            assert db.query(FieldExecutive).filter(FieldExecutive.id == fe_prof_id).first() is None
            assert db.query(User).filter(User.id == fe_user_id).first() is None
        print("[PASS] 7.1 FE deletion cleanly removed executive and user records matching Products pattern")

        # 7.2 Verify SO deletion leaves zero orphan user records
        with TestingSessionLocal() as db:
            so_user = User(
                full_name="Consistency SO", phone="9000000089", username="so_consist",
                role_id=so_role_id, is_active=True
            )
            db.add(so_user)
            db.commit()
            so_prof = ShopOwner(
                user_id=so_user.id, shop_name="Consistency Seeds", market_location="Tenali", address="Main Rd"
            )
            db.add(so_prof)
            db.commit()
            so_prof_id = so_prof.id
            so_user_id = so_user.id

        so_del_res = await client.delete(f"/api/v1/shops/{so_prof_id}", headers=admin_headers)
        assert so_del_res.status_code == 200, f"Expected 200, got {so_del_res.status_code}: {so_del_res.text}"
        assert so_del_res.json()["success"] is True

        with TestingSessionLocal() as db:
            assert db.query(ShopOwner).filter(ShopOwner.id == so_prof_id).first() is None
            assert db.query(User).filter(User.id == so_user_id).first() is None
        print("[PASS] 7.2 SO deletion cleanly removed shop and user records matching Products pattern")

    print("\n========================================================")
    print("ALL PERMANENT DELETION TESTS PASSED SUCCESSFULLY! (100%)")
    print("========================================================\n")

    app.dependency_overrides.clear()
    test_engine.dispose()
    if os.path.exists(TEST_DB_FILE):
        try:
            os.remove(TEST_DB_FILE)
        except Exception:
            pass


if __name__ == "__main__":
    asyncio.run(run_permanent_deletion_tests())
