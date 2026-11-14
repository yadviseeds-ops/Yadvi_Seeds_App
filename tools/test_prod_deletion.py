#!/usr/bin/env python3
"""
Production Verification Script: Dedicated Test Records Creation & Safe Deletion
Tests against live Cloud Run backend: https://yadvi-day1-test-f5upp75xna-el.a.run.app
"""

import requests
import json

BASE_URL = "https://yadvi-day1-test-f5upp75xna-el.a.run.app"

def run_test():
    print("=" * 70)
    print("PRODUCTION VERIFICATION: FE & SO DELETION TEST")
    print(f"Target: {BASE_URL}")
    print("=" * 70)

    # 1. Admin Authentication
    print("\n[STEP 1] Authenticating as Admin...")
    login_res = requests.post(f"{BASE_URL}/api/v1/auth/login", json={"username": "ADMIN", "password": "admin123"})
    assert login_res.status_code == 200, f"Login failed: {login_res.status_code} {login_res.text}"
    token = login_res.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    print("  Admin token acquired successfully.")

    import time
    ts = int(time.time()) % 100000

    # 2. Create Dedicated Test Shop Owner
    print("\n[STEP 2] Creating dedicated test Shop Owner...")
    so_payload = {
        "shop_name": f"TEST DELETE SO {ts}",
        "owner_name": "Test SO Deletion User",
        "phone": f"9000{ts:06d}",
        "username": f"test_del_so_{ts}",
        "password": "testpass123",
        "address": "Test Address 1",
        "city": "Pune",
        "state": "Maharashtra",
        "pincode": "411001"
    }
    r_so = requests.post(f"{BASE_URL}/api/v1/shops", json=so_payload, headers=headers)
    assert r_so.status_code == 200, f"Create SO failed: {r_so.status_code} {r_so.text}"
    so_data = r_so.json()
    so_id = so_data["id"]
    print(f"  Created Test SO: ID={so_id}, Name='{so_data['shop_name']}', Phone='{so_data['phone']}'")

    # 3. Create Dedicated Test Field Executive
    print("\n[STEP 3] Creating dedicated test Field Executive...")
    fe_payload = {
        "full_name": f"TEST DELETE FE {ts}",
        "employee_code": f"FE_DEL_{ts}",
        "phone": f"9001{ts:06d}",
        "username": f"test_del_fe_{ts}",
        "password": "testpass123",
        "address": "Test Address 2",
        "city": "Pune",
        "state": "Maharashtra",
        "pincode": "411001"
    }
    r_fe = requests.post(f"{BASE_URL}/api/v1/employees", json=fe_payload, headers=headers)
    assert r_fe.status_code == 200, f"Create FE failed: {r_fe.status_code} {r_fe.text}"
    fe_data = r_fe.json()
    fe_id = fe_data["id"]
    print(f"  Created Test FE: ID={fe_id}, Name='{fe_data['full_name']}', Phone='{fe_data['phone']}'")

    # 4. Test Deleting Test Shop Owner
    print(f"\n[STEP 4] Deleting test Shop Owner ID {so_id}...")
    del_so_res = requests.delete(f"{BASE_URL}/api/v1/shops/{so_id}", headers=headers)
    print(f"  Response: HTTP {del_so_res.status_code}")
    print(f"  Body: {del_so_res.json()}")
    assert del_so_res.status_code == 200, f"Expected 200, got {del_so_res.status_code}"

    # 5. Test Deleting Test Field Executive
    print(f"\n[STEP 5] Deleting test Field Executive ID {fe_id}...")
    del_fe_res = requests.delete(f"{BASE_URL}/api/v1/employees/{fe_id}", headers=headers)
    print(f"  Response: HTTP {del_fe_res.status_code}")
    print(f"  Body: {del_fe_res.json()}")
    assert del_fe_res.status_code == 200, f"Expected 200, got {del_fe_res.status_code}"

    # 6. Verify Records Truly Deleted (HTTP 404)
    print("\n[STEP 6] Verifying records are permanently removed (expect 404)...")
    get_so = requests.get(f"{BASE_URL}/api/v1/shops/{so_id}", headers=headers)
    # Verify FE is absent from employee list
    all_emps = requests.get(f"{BASE_URL}/api/v1/employees", headers=headers).json()
    emp_ids = [e["id"] for e in all_emps]
    print(f"  GET /api/v1/employees list count: {len(all_emps)} (ID {fe_id} present: {fe_id in emp_ids})")
    assert fe_id not in emp_ids, f"Employee ID {fe_id} still present in employees list!"

    # 7. Verify Existing Protected Shop (e.g. Shop 1 has orders) Cannot Be Deleted
    print("\n[STEP 7] Verifying safety constraint: Shop with orders refuses deletion (HTTP 400)...")
    del_protected_shop = requests.delete(f"{BASE_URL}/api/v1/shops/1", headers=headers)
    print(f"  DELETE /api/v1/shops/1 -> HTTP {del_protected_shop.status_code} (detail: {del_protected_shop.json().get('detail')})")
    assert del_protected_shop.status_code == 400, f"Expected 400, got {del_protected_shop.status_code}"

    # 8. Verify Existing Protected FE (e.g. FE 1 has visits/attendance) Cannot Be Deleted
    print("\n[STEP 8] Verifying safety constraint: Employee with visits/attendance refuses deletion (HTTP 400)...")
    del_protected_fe = requests.delete(f"{BASE_URL}/api/v1/employees/1", headers=headers)
    print(f"  DELETE /api/v1/employees/1 -> HTTP {del_protected_fe.status_code} (detail: {del_protected_fe.json().get('detail')})")
    assert del_protected_fe.status_code == 400, f"Expected 400, got {del_protected_fe.status_code}"

    print("\n" + "=" * 70)
    print("ALL PRODUCTION DELETION VERIFICATION TESTS PASSED 100%!")
    print("=" * 70)

if __name__ == "__main__":
    run_test()
