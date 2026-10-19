import requests
import sys

BASE_URL = "http://127.0.0.1:8000"

def run_tests():
    print("=== Starting End-to-End Verification ===")

    # 1. Login as Admin
    print("\n--- 1. Authenticating Admin ---")
    res = requests.post(f"{BASE_URL}/api/v1/auth/login", json={"username": "ADMIN", "password": "admin123"})
    assert res.status_code == 200, f"Admin login failed: {res.text}"
    admin_token = res.json()["access_token"]
    admin_headers = {"Authorization": f"Bearer {admin_token}"}
    print("Admin login successful.")

    # 2. Login as Shop Owner
    print("\n--- 2. Authenticating Shop Owner ---")
    res = requests.post(f"{BASE_URL}/api/v1/auth/login", json={"username": "SHOP001", "password": "shop123"})
    assert res.status_code == 200, f"Shop Owner login failed: {res.text}"
    so_token = res.json()["access_token"]
    so_headers = {"Authorization": f"Bearer {so_token}"}
    print("Shop Owner login successful.")

    # 3. Test Shop Owner to FE Assignment & Display Persistence
    print("\n--- 3. Testing Shop Owner to FE Assignment & Persistence ---")
    res = requests.get(f"{BASE_URL}/api/v1/shops", headers=admin_headers)
    assert res.status_code == 200, f"List shops failed: {res.text}"
    shops = res.json()
    assert len(shops) > 0, "No shops found"
    target_shop = shops[0]
    shop_id = target_shop["id"]
    print(f"Target shop ID: {shop_id}, Name: {target_shop['shop_name']}")

    # Get Field Executives
    res = requests.get(f"{BASE_URL}/api/v1/employees", headers=admin_headers)
    assert res.status_code == 200, f"List executives failed: {res.text}"
    executives = res.json()
    assert len(executives) > 0, "No executives found"
    fe = executives[0]
    fe_id = fe["id"]
    fe_name = fe.get("full_name") or fe.get("name")
    print(f"Assigning to FE ID: {fe_id}, Name: {fe_name}")

    # Assign shop to FE
    res = requests.put(f"{BASE_URL}/api/v1/shops/{shop_id}/assign", json={"executive_id": fe_id}, headers=admin_headers)
    assert res.status_code == 200, f"Assign shop failed: {res.text}"
    assign_resp = res.json()
    print("Assign API response:", assign_resp)
    assert assign_resp.get("assigned_executive_id") == fe_id, "Response missing assigned_executive_id"
    assert assign_resp.get("assigned_executive_name") == fe_name, f"Response executive name mismatch: {assign_resp.get('assigned_executive_name')} vs {fe_name}"

    # Verify GET /shops returns assigned executive name immediately
    res = requests.get(f"{BASE_URL}/api/v1/shops", headers=admin_headers)
    assert res.status_code == 200
    updated_shops = res.json()
    matched_shop = next(s for s in updated_shops if s["id"] == shop_id)
    assert matched_shop["assigned_executive_id"] == fe_id, f"assigned_executive_id not updated in GET /shops: {matched_shop}"
    assert matched_shop["assigned_executive_name"] == fe_name, f"assigned_executive_name not updated in GET /shops: {matched_shop}"
    print(f"PASS: GET /shops correctly returns assigned_executive_name: '{matched_shop['assigned_executive_name']}'")

    # Test Unassigning
    print("Testing unassigning shop...")
    res = requests.put(f"{BASE_URL}/api/v1/shops/{shop_id}/assign", json={"executive_id": None}, headers=admin_headers)
    assert res.status_code == 200, f"Unassign failed: {res.text}"
    unassign_resp = res.json()
    print("Unassign response:", unassign_resp)
    assert unassign_resp.get("assigned_executive_id") is None
    assert unassign_resp.get("assigned_executive_name") == "Unassigned"

    # Verify GET /shops reflects Unassigned
    res = requests.get(f"{BASE_URL}/api/v1/shops", headers=admin_headers)
    matched_shop = next(s for s in res.json() if s["id"] == shop_id)
    assert matched_shop["assigned_executive_id"] is None
    assert matched_shop["assigned_executive_name"] is None or matched_shop["assigned_executive_name"] == "Unassigned"
    print("PASS: Unassigning works and persists.")

    # Re-assign for clean state
    res = requests.put(f"{BASE_URL}/api/v1/shops/{shop_id}/assign", json={"executive_id": fe_id}, headers=admin_headers)
    assert res.status_code == 200

    # 4. Product Weight Ordering (500 g and 1.5 kg)
    print("\n--- 4. Testing Weight Ordering in Grams (500 g) and Stock Deduction ---")
    res = requests.get(f"{BASE_URL}/api/v1/products", headers=so_headers)
    assert res.status_code == 200
    products = res.json()
    p = products[0]
    p_id = p["id"]
    initial_stock_kg = float(p.get("available_stock_kg") or 0.0)
    print(f"Product ID: {p_id}, Name: {p['name']}, Initial Stock: {initial_stock_kg} kg")

    # Place Order with 500 g
    order_payload_500g = {
        "items": [
            {
                "product_id": p_id,
                "package_size": "500g Pack",
                "quantity": 500.0,
                "unit": "g"
            }
        ],
        "delivery_notes": "Test order 500g"
    }
    res = requests.post(f"{BASE_URL}/api/v1/orders", json=order_payload_500g, headers=so_headers)
    assert res.status_code == 200, f"Order placement 500g failed: {res.text}"
    order_500g = res.json()
    print("500g Order placed successfully:", order_500g["order_number"])
    assert order_500g["total_quantity_kg"] == 0.5, f"Expected total_quantity_kg 0.5, got {order_500g['total_quantity_kg']}"
    assert len(order_500g["items"]) == 1
    assert order_500g["items"][0]["quantity"] == 500.0
    assert order_500g["items"][0]["unit"] == "g"

    # Verify stock deduction: initial - 0.5 kg
    res = requests.get(f"{BASE_URL}/api/v1/products/{p_id}", headers=so_headers)
    p_after_500g = res.json()
    expected_stock_500g = round(initial_stock_kg - 0.5, 3)
    actual_stock_500g = round(float(p_after_500g["available_stock_kg"]), 3)
    assert actual_stock_500g == expected_stock_500g, f"Stock deduction error: expected {expected_stock_500g}, got {actual_stock_500g}"
    print(f"PASS: 500g deducted exactly 0.5 kg from stock ({initial_stock_kg} -> {actual_stock_500g} kg)")

    # Place Order with 1.5 kg
    print("\n--- 5. Testing Weight Ordering in Kilograms (1.5 kg) and Stock Deduction ---")
    order_payload_1_5kg = {
        "items": [
            {
                "product_id": p_id,
                "package_size": "1kg Pack",
                "quantity": 1.5,
                "unit": "kg"
            }
        ],
        "delivery_notes": "Test order 1.5kg"
    }
    res = requests.post(f"{BASE_URL}/api/v1/orders", json=order_payload_1_5kg, headers=so_headers)
    assert res.status_code == 200, f"Order placement 1.5kg failed: {res.text}"
    order_1_5kg = res.json()
    print("1.5kg Order placed successfully:", order_1_5kg["order_number"])
    assert order_1_5kg["total_quantity_kg"] == 1.5, f"Expected total_quantity_kg 1.5, got {order_1_5kg['total_quantity_kg']}"
    assert len(order_1_5kg["items"]) == 1
    assert order_1_5kg["items"][0]["quantity"] == 1.5
    assert order_1_5kg["items"][0]["unit"] == "kg"

    # Verify stock deduction: actual_stock_500g - 1.5 kg
    res = requests.get(f"{BASE_URL}/api/v1/products/{p_id}", headers=so_headers)
    p_after_1_5kg = res.json()
    expected_stock_1_5kg = round(actual_stock_500g - 1.5, 3)
    actual_stock_1_5kg = round(float(p_after_1_5kg["available_stock_kg"]), 3)
    assert actual_stock_1_5kg == expected_stock_1_5kg, f"Stock deduction error: expected {expected_stock_1_5kg}, got {actual_stock_1_5kg}"
    print(f"PASS: 1.5kg deducted exactly 1.5 kg from stock ({actual_stock_500g} -> {actual_stock_1_5kg} kg)")

    # 6. Test Insufficient Stock Validation
    print("\n--- 6. Testing Insufficient Stock Validation ---")
    insufficient_qty = actual_stock_1_5kg + 5000.0
    order_excessive = {
        "items": [
            {
                "product_id": p_id,
                "package_size": "Standard",
                "quantity": insufficient_qty,
                "unit": "kg"
            }
        ]
    }
    res = requests.post(f"{BASE_URL}/api/v1/orders", json=order_excessive, headers=so_headers)
    assert res.status_code == 400, f"Expected 400 Bad Request for insufficient stock, got {res.status_code}: {res.text}"
    print(f"PASS: Insufficient stock rejected with 400: {res.json()['detail']}")

    # 7. Test Retrieval in Order History & Consistency
    print("\n--- 7. Verifying Order Retrieval and Cross-Panel Consistency ---")
    res = requests.get(f"{BASE_URL}/api/v1/orders", headers=so_headers)
    assert res.status_code == 200
    orders_list = res.json()
    assert len(orders_list) >= 2
    # Verify latest orders
    latest_order = orders_list[0]
    assert "total_quantity_kg" in latest_order
    assert latest_order["total_quantity_kg"] > 0
    print(f"Order #{latest_order['order_number']}: Total {latest_order['total_quantity_kg']} kg, Status: {latest_order['status']}")
    print(f"Items in order: {[{'product': i['product_name'], 'qty': i['quantity'], 'unit': i['unit']} for i in latest_order['items']]}")

    print("\n=== ALL END-TO-END TESTS PASSED SUCCESSFULLY! ===")

if __name__ == "__main__":
    try:
        run_tests()
    except Exception as e:
        print(f"\nTEST FAILED: {e}", file=sys.stderr)
        sys.exit(1)
