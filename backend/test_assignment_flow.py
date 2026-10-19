import requests
import sqlite3
import json

BASE_URL = "http://127.0.0.1:8000/api/v1"
DB_PATH = "yadvi_seeds.db"

def run_tests():
    print("=== STARTING SHOP OWNER -> FE ASSIGNMENT VERIFICATION ===")

    # 1. Login as Admin
    admin_login = requests.post(f"{BASE_URL}/auth/login", json={"username": "ADMIN", "password": "admin123"}).json()
    assert "access_token" in admin_login, f"Admin login failed: {admin_login}"
    admin_token = admin_login["access_token"]
    admin_headers = {"Authorization": f"Bearer {admin_token}"}
    print("[PASS] 1. Admin login successful")

    # 2. Fetch Employees to identify Field Executives
    employees_res = requests.get(f"{BASE_URL}/employees", headers=admin_headers)
    assert employees_res.status_code == 200, f"Get employees failed: {employees_res.text}"
    employees = employees_res.json()
    assert len(employees) >= 2, f"Need at least 2 employees, found {len(employees)}"
    fe1 = employees[0]
    fe2 = employees[1]
    print(f"[PASS] 2. Identified FE1 (ID={fe1['id']}, Code={fe1['employee_code']}, Name={fe1['full_name']}) and FE2 (ID={fe2['id']}, Code={fe2['employee_code']}, Name={fe2['full_name']})")

    # 3. Fetch Shops
    shops_res = requests.get(f"{BASE_URL}/shops", headers=admin_headers)
    assert shops_res.status_code == 200, f"Get shops failed: {shops_res.text}"
    shops = shops_res.json()
    assert len(shops) >= 1, "No shops found"
    target_shop = shops[0]
    shop_id = target_shop["id"]
    print(f"[PASS] 3. Target Shop selected: ID={shop_id}, Name='{target_shop['shop_name']}', Previous FE='{target_shop.get('assigned_executive_name')}'")

    # 4. Assign Target Shop to FE1
    assign_res = requests.put(f"{BASE_URL}/shops/{shop_id}/assign", json={"executive_id": fe1["id"]}, headers=admin_headers)
    assert assign_res.status_code == 200, f"Assign to FE1 failed: {assign_res.text}"
    assign_data = assign_res.json()
    print("Assign Response:", json.dumps(assign_data, indent=2))
    assert assign_data.get("success") is True
    assert assign_data.get("assigned_executive_id") == fe1["id"], f"Expected {fe1['id']}, got {assign_data.get('assigned_executive_id')}"
    assert assign_data.get("assigned_executive_name") == fe1["full_name"], f"Expected {fe1['full_name']}, got {assign_data.get('assigned_executive_name')}"
    print(f"[PASS] 4. Assigned Shop {shop_id} to FE1 ({fe1['full_name']}) via API")

    # 5. Verify direct SQLite database persistence
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute("SELECT id, shop_name, assigned_executive_id FROM shop_owners WHERE id = ?", (shop_id,))
    db_row = cur.fetchone()
    print("DB Row after FE1 assignment:", db_row)
    assert db_row is not None and db_row[2] == fe1["id"], f"DB value mismatch: expected {fe1['id']}, found {db_row[2]}"
    conn.close()
    print(f"[PASS] 5. Database record confirmed: shop_owners.assigned_executive_id = {db_row[2]} matches FE1 ID")

    # 6. Re-fetch Shops as Admin and verify assigned executive fields
    shops_after_res = requests.get(f"{BASE_URL}/shops", headers=admin_headers)
    assert shops_after_res.status_code == 200
    shop_after = next(s for s in shops_after_res.json() if s["id"] == shop_id)
    assert shop_after.get("assigned_executive_id") == fe1["id"]
    assert shop_after.get("assigned_executive_name") == fe1["full_name"]
    print(f"[PASS] 6. GET /shops returns assigned FE ID={shop_after['assigned_executive_id']} and Name='{shop_after['assigned_executive_name']}'")

    # 7. Verify FE1 Panel view
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute("SELECT username FROM users WHERE id = ?", (fe1["user_id"],))
    fe1_username = cur.fetchone()[0]
    conn.close()

    fe1_login = requests.post(f"{BASE_URL}/auth/login", json={"username": fe1_username, "password": "field123"}).json()
    assert "access_token" in fe1_login, f"FE1 login failed: {fe1_login}"
    fe1_token = fe1_login["access_token"]
    fe1_headers = {"Authorization": f"Bearer {fe1_token}"}
    fe1_shops = requests.get(f"{BASE_URL}/shops", headers=fe1_headers).json()
    fe1_shop_ids = [s["id"] for s in fe1_shops]
    assert shop_id in fe1_shop_ids, f"Shop {shop_id} not visible in FE1's shops list: {fe1_shop_ids}"
    print(f"[PASS] 7. FE1 panel can view assigned Shop {shop_id}")

    fe1_visits = requests.get(f"{BASE_URL}/visits", headers=fe1_headers).json()
    fe1_visit_shop_ids = [v["shop_id"] for v in fe1_visits]
    assert shop_id in fe1_visit_shop_ids, f"Shop {shop_id} not in FE1 visits list: {fe1_visit_shop_ids}"
    print(f"[PASS] 7b. FE1 visits contains pending visit for Shop {shop_id}")

    # 8. Re-assign Target Shop to FE2
    assign2_res = requests.put(f"{BASE_URL}/shops/{shop_id}/assign", json={"executive_id": fe2["id"]}, headers=admin_headers)
    assert assign2_res.status_code == 200, f"Assign to FE2 failed: {assign2_res.text}"
    assign2_data = assign2_res.json()
    assert assign2_data.get("assigned_executive_id") == fe2["id"]
    assert assign2_data.get("assigned_executive_name") == fe2["full_name"]
    print(f"[PASS] 8. Re-assigned Shop {shop_id} to FE2 ({fe2['full_name']})")

    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute("SELECT id, shop_name, assigned_executive_id FROM shop_owners WHERE id = ?", (shop_id,))
    db_row = cur.fetchone()
    assert db_row[2] == fe2["id"]
    conn.close()
    print("[PASS] 8b. DB verified: ShopOwner.assigned_executive_id updated to FE2")

    # 9. Explicitly unassign Shop
    unassign_res = requests.put(f"{BASE_URL}/shops/{shop_id}/assign", json={"executive_id": None}, headers=admin_headers)
    assert unassign_res.status_code == 200, f"Unassign failed: {unassign_res.text}"
    unassign_data = unassign_res.json()
    assert unassign_data.get("assigned_executive_id") is None
    assert unassign_data.get("assigned_executive_name") == "Unassigned"
    print(f"[PASS] 9. Explicit unassign response: {unassign_data}")

    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute("SELECT id, shop_name, assigned_executive_id FROM shop_owners WHERE id = ?", (shop_id,))
    db_row = cur.fetchone()
    assert db_row[2] is None, f"Expected None in DB, got {db_row[2]}"
    conn.close()
    print("[PASS] 9b. DB verified: ShopOwner.assigned_executive_id is NULL after unassignment")

    shops_after_unassign = requests.get(f"{BASE_URL}/shops", headers=admin_headers).json()
    shop_unassigned = next(s for s in shops_after_unassign if s["id"] == shop_id)
    assert shop_unassigned.get("assigned_executive_id") is None
    assert shop_unassigned.get("assigned_executive_name") is None  # Defaults to "Unassigned" in UI
    print("[PASS] 9c. GET /shops confirms shop is unassigned (fields are None)")

    # 10. Test error handling for non-existent FE
    invalid_fe_res = requests.put(f"{BASE_URL}/shops/{shop_id}/assign", json={"executive_id": 999999}, headers=admin_headers)
    assert invalid_fe_res.status_code == 404, f"Expected 404, got {invalid_fe_res.status_code}"
    print("[PASS] 10. Non-existent FE returns 404 and does not falsely report success")

    # 11. Test authorization (non-admin cannot assign)
    so_login = requests.post(f"{BASE_URL}/auth/login", json={"username": "SHOP001", "password": "shop123"}).json()
    if "access_token" in so_login:
        so_token = so_login["access_token"]
        unauth_res = requests.put(f"{BASE_URL}/shops/{shop_id}/assign", json={"executive_id": fe1["id"]}, headers={"Authorization": f"Bearer {so_token}"})
        assert unauth_res.status_code in [401, 403], f"Expected 401/403, got {unauth_res.status_code}"
        print(f"[PASS] 11. Role-based authorization enforced: Shop Owner cannot assign (Status {unauth_res.status_code})")

    # 12. Restore assignment to FE1 for standard testing
    reassign_res = requests.put(f"{BASE_URL}/shops/{shop_id}/assign", json={"executive_id": fe1["id"]}, headers=admin_headers)
    assert reassign_res.status_code == 200
    print(f"[PASS] 12. Restored Shop {shop_id} assignment to FE1 ({fe1['full_name']})")

    print("\n=== ALL ASSIGNMENT TESTS PASSED SUCCESSFULLY! ===")

if __name__ == "__main__":
    run_tests()
