#!/usr/bin/env python3
"""
Post-Migration Smoke Test Suite for Task C: Dedicated Cloud Run Service Account
Tests against live Cloud Run backend: https://yadvi-day1-test-f5upp75xna-el.a.run.app
"""

import sys
import time
import requests

BASE_URL = "https://yadvi-day1-test-f5upp75xna-el.a.run.app"

def run_suite():
    print("=" * 75)
    print("YADVI POST-MIGRATION VERIFICATION SUITE (REVISION 00010-7nn)")
    print(f"Target Service: {BASE_URL}")
    print("=" * 75)

    results = {}

    # TEST 1: GET / (Root Health Probe)
    print("\n[TEST 1] Probing Public Health Endpoint (GET /)...")
    try:
        r = requests.get(f"{BASE_URL}/", timeout=10)
        assert r.status_code == 200, f"Expected 200, got {r.status_code}"
        data = r.json()
        assert data.get("status") == "Online", f"Expected 'Online', got {data.get('status')}"
        print(f"  PASS: HTTP {r.status_code} | Status: '{data.get('status')}' | System: '{data.get('system')}'")
        results["test_1_root_health"] = "PASS"
    except Exception as e:
        print(f"  FAIL: {e}")
        results["test_1_root_health"] = f"FAIL: {e}"

    # TEST 2: Admin Password Authentication
    print("\n[TEST 2] Testing Admin Password Authentication (/api/v1/auth/login)...")
    admin_token = None
    admin_headers = {}
    try:
        r = requests.post(
            f"{BASE_URL}/api/v1/auth/login",
            json={"username": "ADMIN", "password": "admin123"},
            timeout=10
        )
        assert r.status_code == 200, f"Admin login failed: {r.status_code} {r.text}"
        admin_data = r.json()
        admin_token = admin_data["access_token"]
        admin_headers = {"Authorization": f"Bearer {admin_token}"}
        assert admin_data.get("role") == "administrator", f"Unexpected role: {admin_data.get('role')}"
        print(f"  PASS: Admin authenticated | Role: '{admin_data.get('role')}' | User ID: {admin_data.get('user_id')}")
        results["test_2_admin_auth"] = "PASS"
    except Exception as e:
        print(f"  FAIL: {e}")
        results["test_2_admin_auth"] = f"FAIL: {e}"

    # TEST 3: Cloud SQL Read Operations (Products, Shops, Employees)
    print("\n[TEST 3] Testing Cloud SQL Read Operations...")
    try:
        r_prod = requests.get(f"{BASE_URL}/api/v1/products", headers=admin_headers, timeout=10)
        assert r_prod.status_code == 200, f"Products read failed: {r_prod.status_code}"
        prod_count = len(r_prod.json())

        r_shops = requests.get(f"{BASE_URL}/api/v1/shops", headers=admin_headers, timeout=10)
        assert r_shops.status_code == 200, f"Shops read failed: {r_shops.status_code}"
        shops_count = len(r_shops.json())

        r_emps = requests.get(f"{BASE_URL}/api/v1/employees", headers=admin_headers, timeout=10)
        assert r_emps.status_code == 200, f"Employees read failed: {r_emps.status_code}"
        emps_count = len(r_emps.json())

        print(f"  PASS: Products={prod_count}, Shops={shops_count}, Employees={emps_count}")
        results["test_3_cloudsql_reads"] = "PASS"
    except Exception as e:
        print(f"  FAIL: {e}")
        results["test_3_cloudsql_reads"] = f"FAIL: {e}"

    # TEST 4: Create Dedicated Test Shop Owner & Dedicated Test Field Executive
    print("\n[TEST 4] Testing Safe Write: Creating Dedicated Test SO and FE...")
    ts = int(time.time()) % 100000
    test_so_id = None
    test_fe_id = None
    so_username = f"smoke_so_{ts}"
    fe_username = f"smoke_fe_{ts}"
    so_password = "shop123"
    fe_password = "field123"

    try:
        so_payload = {
            "shop_name": f"Smoke Test Shop {ts}",
            "owner_name": "Smoke Test SO",
            "phone": f"9002{ts:06d}",
            "username": so_username,
            "password": so_password,
            "address": "Smoke Test Address",
            "city": "Hyderabad",
            "state": "Telangana",
            "pincode": "500001"
        }
        r_so = requests.post(f"{BASE_URL}/api/v1/shops", json=so_payload, headers=admin_headers, timeout=10)
        assert r_so.status_code == 200, f"Create SO failed: {r_so.status_code} {r_so.text}"
        test_so_id = r_so.json()["id"]
        print(f"  Created Test Shop Owner: ID={test_so_id}, Username='{so_username}'")

        fe_payload = {
            "full_name": f"Smoke Test FE {ts}",
            "employee_code": f"FE_SMK_{ts}",
            "phone": f"9003{ts:06d}",
            "username": fe_username,
            "password": fe_password,
            "address": "Smoke Test Address 2",
            "city": "Hyderabad",
            "state": "Telangana",
            "pincode": "500001"
        }
        r_fe = requests.post(f"{BASE_URL}/api/v1/employees", json=fe_payload, headers=admin_headers, timeout=10)
        assert r_fe.status_code == 200, f"Create FE failed: {r_fe.status_code} {r_fe.text}"
        test_fe_id = r_fe.json()["id"]
        print(f"  Created Test Field Executive: ID={test_fe_id}, Username='{fe_username}'")
        results["test_4_safe_write_create"] = "PASS"
    except Exception as e:
        print(f"  FAIL: {e}")
        results["test_4_safe_write_create"] = f"FAIL: {e}"

    # TEST 5: SO and FE Authentication with Issued Passwords
    print("\n[TEST 5] Testing SO and FE Authentication (/api/v1/auth/login)...")
    so_token = None
    so_headers = {}
    fe_token = None
    fe_headers = {}
    try:
        # Shop Owner Login
        r_so_login = requests.post(
            f"{BASE_URL}/api/v1/auth/login",
            json={"username": so_username, "password": so_password},
            timeout=10
        )
        assert r_so_login.status_code == 200, f"SO login failed: {r_so_login.status_code} {r_so_login.text}"
        so_data = r_so_login.json()
        assert so_data.get("role") == "shop_owner", f"Unexpected SO role: {so_data.get('role')}"
        so_token = so_data["access_token"]
        so_headers = {"Authorization": f"Bearer {so_token}"}
        print(f"  PASS: Shop Owner authenticated | Role: '{so_data.get('role')}' | Shop ID: {so_data.get('metadata', {}).get('shop_id')}")

        # Field Executive Login
        r_fe_login = requests.post(
            f"{BASE_URL}/api/v1/auth/login",
            json={"username": fe_username, "password": fe_password},
            timeout=10
        )
        assert r_fe_login.status_code == 200, f"FE login failed: {r_fe_login.status_code} {r_fe_login.text}"
        fe_data = r_fe_login.json()
        assert fe_data.get("role") == "field_executive", f"Unexpected FE role: {fe_data.get('role')}"
        fe_token = fe_data["access_token"]
        fe_headers = {"Authorization": f"Bearer {fe_token}"}
        print(f"  PASS: Field Executive authenticated | Role: '{fe_data.get('role')}' | Code: {fe_data.get('metadata', {}).get('employee_code')}")
        results["test_5_so_fe_auth"] = "PASS"
    except Exception as e:
        print(f"  FAIL: {e}")
        results["test_5_so_fe_auth"] = f"FAIL: {e}"

    # TEST 6: Order Creation and Assignment Workflow
    print("\n[TEST 6] Testing Order Creation and Status Update Workflow...")
    created_order_id = None
    try:
        # 1. Place order as test Shop Owner
        order_payload = {
            "items": [
                {
                    "product_id": 1,
                    "package_size": "Standard",
                    "quantity": 1.0,
                    "unit": "kg"
                }
            ],
            "delivery_notes": f"Automated Task C smoke verification order {ts}",
            "source": "Shop Owner App"
        }
        r_order = requests.post(f"{BASE_URL}/api/v1/orders", json=order_payload, headers=so_headers, timeout=10)
        assert r_order.status_code == 200, f"Order placement failed: {r_order.status_code} {r_order.text}"
        order_data = r_order.json()
        created_order_id = order_data["id"]
        order_num = order_data["order_number"]
        print(f"  PASS: Order placed | ID: {created_order_id} | Number: '{order_num}' | Status: '{order_data['status']}'")

        # 2. Update status as Admin (e.g. Dispatched with LR)
        status_payload = {
            "status": "Dispatched",
            "lr_number": f"LR-{ts}",
            "transporter_name": "Test Express Logistics"
        }
        r_status = requests.put(
            f"{BASE_URL}/api/v1/orders/{created_order_id}/status",
            json=status_payload,
            headers=admin_headers,
            timeout=10
        )
        assert r_status.status_code == 200, f"Status update failed: {r_status.status_code} {r_status.text}"
        print(f"  PASS: Order status updated to 'Dispatched' | LR: 'LR-{ts}'")
        results["test_6_order_workflow"] = "PASS"
    except Exception as e:
        print(f"  FAIL: {e}")
        results["test_6_order_workflow"] = f"FAIL: {e}"

    # TEST 7: Clean Up Test Records (Safe Delete)
    print("\n[TEST 7] Testing Safe Deletion Constraints & Cleaning Up...")
    try:
        # Shop with orders refuses deletion (HTTP 400) - verifies data integrity constraint
        r_del_so_fail = requests.delete(f"{BASE_URL}/api/v1/shops/{test_so_id}", headers=admin_headers, timeout=10)
        assert r_del_so_fail.status_code == 400, f"Expected 400 for shop with orders, got {r_del_so_fail.status_code}"
        print(f"  PASS: Safety rule enforced: Shop Owner {test_so_id} with active order cannot be deleted (HTTP 400).")

        # FE has no visits/attendance yet, should be cleanly deletable
        r_del_fe = requests.delete(f"{BASE_URL}/api/v1/employees/{test_fe_id}", headers=admin_headers, timeout=10)
        assert r_del_fe.status_code == 200, f"Expected 200 for clean FE delete, got {r_del_fe.status_code}"
        print(f"  PASS: Test Field Executive {test_fe_id} deleted successfully (HTTP 200).")
        results["test_7_safe_cleanup"] = "PASS"
    except Exception as e:
        print(f"  FAIL: {e}")
        results["test_7_safe_cleanup"] = f"FAIL: {e}"

    # Summary
    print("\n" + "=" * 75)
    print("SMOKE TEST SUMMARY")
    print("=" * 75)
    all_passed = True
    for test, res in results.items():
        print(f"  {test:<30}: {res}")
        if res != "PASS":
            all_passed = False

    return all_passed

if __name__ == "__main__":
    success = run_suite()
    sys.exit(0 if success else 1)
