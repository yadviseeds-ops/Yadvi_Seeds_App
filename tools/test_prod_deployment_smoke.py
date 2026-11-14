import httpx

PROD_URL = "https://yadvi-day1-test-f5upp75xna-el.a.run.app"

def run_prod_smoke_tests():
    print("=" * 70)
    print("RUNNING POST-DEPLOYMENT PRODUCTION SMOKE TESTS")
    print(f"Target: {PROD_URL}")
    print("=" * 70)

    with httpx.Client(base_url=PROD_URL, timeout=25.0) as client:
        # 1. Health check endpoint (Root)
        print("\n1. Testing health / root endpoint...")
        res_health = client.get("/")
        print(f"   Root GET status: {res_health.status_code}")
        assert res_health.status_code == 200, f"Expected 200, got {res_health.status_code}"
        payload = res_health.json()
        print(f"   System: {payload.get('system')}")
        print(f"   Status: {payload.get('status')}")

        # 2. Unauthenticated requests are rejected
        print("\n2. Testing unauthenticated rejection on protected endpoints...")
        for ep in ["/api/v1/products", "/api/v1/eod", "/api/v1/dashboard/admin", "/api/v1/employees/1"]:
            r = client.get(ep)
            print(f"   Unauthenticated {ep} status: {r.status_code} (Expected 401)")
            assert r.status_code == 401, f"Expected 401 on {ep}, got {r.status_code}"

        # 3. Authenticate as Admin
        print("\n3. Authenticating as Admin (admin / adminpassword123)...")
        login_payload = {
            "username": "admin",
            "password": "adminpassword123"
        }
        res_login = client.post("/api/v1/auth/login", json=login_payload)
        if res_login.status_code != 200:
            login_payload["password"] = "admin123"
            res_login = client.post("/api/v1/auth/login", json=login_payload)

        print(f"   Admin login status: {res_login.status_code}")
        assert res_login.status_code == 200, f"Admin login failed: {res_login.text}"
        token_data = res_login.json()
        token = token_data.get("access_token")
        assert token, "Token missing in login response"
        admin_headers = {"Authorization": f"Bearer {token}"}
        print("   Admin token obtained successfully!")

        # 4. Authenticated products catalog retrieval
        print("\n4. Testing products catalog retrieval with token...")
        res_prod = client.get("/api/v1/products", headers=admin_headers)
        assert res_prod.status_code == 200, f"Products failed: {res_prod.text}"
        products = res_prod.json()
        print(f"   Active products in catalog: {len(products)}")
        assert len(products) > 0, "Expected at least 1 product"

        # 5. Admin Dashboard GET with live counts
        print("\n5. Testing Admin Dashboard endpoint (/api/v1/dashboard/admin)...")
        res_dash = client.get("/api/v1/dashboard/admin", headers=admin_headers)
        print(f"   Dashboard GET status: {res_dash.status_code}")
        assert res_dash.status_code == 200, f"Dashboard failed: {res_dash.text}"
        dash_data = res_dash.json()
        print(f"   Total Orders: {dash_data.get('total_orders')}, Pending: {dash_data.get('pending_orders')}")
        print(f"   Total Dealers: {dash_data.get('total_shops')}, Active FEs: {dash_data.get('total_executives')}")

        # 6. EOD date filtering on production
        print("\n6. Testing EOD report date filtering (/api/v1/eod?date=2026-10-25)...")
        res_eod = client.get("/api/v1/eod?date=2026-10-25", headers=admin_headers)
        print(f"   Filtered EOD status: {res_eod.status_code}")
        assert res_eod.status_code == 200, f"EOD filtered query failed: {res_eod.text}"
        eod_list = res_eod.json()
        print(f"   EOD reports returned for date 2026-10-25: {len(eod_list)}")

        # 7. FE Management / Detail endpoint for Task 9
        print("\n7. Testing Task 9 FE profile endpoint (/api/v1/employees)...")
        res_emps = client.get("/api/v1/employees", headers=admin_headers)
        assert res_emps.status_code == 200
        emp_list = res_emps.json()
        print(f"   Total field executives in production: {len(emp_list)}")
        assert len(emp_list) > 0, "Expected at least 1 FE in production"
        fe_id = emp_list[0]["id"]
        fe_name = emp_list[0]["full_name"]

        print(f"\n   Testing GET /api/v1/employees/{fe_id} for FE: {fe_name}...")
        res_fe_detail = client.get(f"/api/v1/employees/{fe_id}", headers=admin_headers)
        assert res_fe_detail.status_code == 200, f"FE detail failed: {res_fe_detail.text}"
        fe_data = res_fe_detail.json()
        print(f"   FE Name: {fe_data.get('full_name')}")
        print(f"   Employee Code: {fe_data.get('employee_code')}")
        print(f"   Total Assigned Shops: {fe_data.get('total_assigned_shops')}")
        print(f"   Assigned Shops List count: {len(fe_data.get('assigned_shops', []))}")
        print(f"   Completed Visits: {fe_data.get('completed_visits')}")
        print(f"   Pending Visits: {fe_data.get('pending_visits')}")

        assert "assigned_shops" in fe_data, "assigned_shops missing from response"
        assert "total_assigned_shops" in fe_data, "total_assigned_shops missing from response"
        assert "completed_visits" in fe_data, "completed_visits missing from response"
        assert "pending_visits" in fe_data, "pending_visits missing from response"

        # Also verify alias endpoint
        res_alias = client.get(f"/api/v1/employees/{fe_id}/management-details", headers=admin_headers)
        assert res_alias.status_code == 200, f"Alias endpoint failed: {res_alias.text}"
        assert res_alias.json()["total_assigned_shops"] == fe_data["total_assigned_shops"]

        # 8. Testing Admin FE Profile Update (Task 10)
        print(f"\n8. Testing Task 10 Admin Update FE endpoint (PUT /api/v1/employees/{fe_id})...")
        orig_fe_name = fe_data.get("full_name")
        update_fe_payload = {
            "full_name": orig_fe_name,
            "designation": fe_data.get("designation") or "Field Sales Officer",
            "assigned_territory": fe_data.get("assigned_territory") or "General Territory",
        }
        res_fe_update = client.put(f"/api/v1/employees/{fe_id}", json=update_fe_payload, headers=admin_headers)
        assert res_fe_update.status_code == 200, f"FE update failed: {res_fe_update.text}"
        updated_fe_data = res_fe_update.json()
        assert updated_fe_data["full_name"] == orig_fe_name
        print(f"   FE Profile successfully updated and verified in production!")

        # 9. Testing Admin Shop Owner Profile Update (Task 10)
        print("\n9. Testing Task 10 Admin Update Shop Owner endpoint (PUT /api/v1/shops)...")
        res_shops = client.get("/api/v1/shops", headers=admin_headers)
        assert res_shops.status_code == 200
        shops_list = res_shops.json()
        print(f"   Total shops in production: {len(shops_list)}")
        assert len(shops_list) > 0, "Expected at least 1 shop in production"
        target_shop = shops_list[0]
        shop_id = target_shop["id"]
        orig_shop_name = target_shop["shop_name"]
        update_shop_payload = {
            "shop_name": orig_shop_name,
            "owner_name": target_shop.get("owner_name") or "",
            "market_location": target_shop.get("market_location") or "Main Market",
            "address": target_shop.get("address") or "Main Road",
        }
        res_shop_update = client.put(f"/api/v1/shops/{shop_id}", json=update_shop_payload, headers=admin_headers)
        assert res_shop_update.status_code == 200, f"Shop update failed: {res_shop_update.text}"
        updated_shop_data = res_shop_update.json()
        assert updated_shop_data["shop_name"] == orig_shop_name
        print(f"   Shop Owner Profile successfully updated and verified in production!")

        # 10. Verify Unauthorized Modification Rejection
        print("\n10. Testing Unauthenticated/Unauthorized update rejection (Expected 401/403)...")
        res_unauth_fe = client.put(f"/api/v1/employees/{fe_id}", json={"full_name": "Tampered"})
        assert res_unauth_fe.status_code == 401, f"Expected 401, got {res_unauth_fe.status_code}"
        res_unauth_so = client.put(f"/api/v1/shops/{shop_id}", json={"shop_name": "Tampered"})
        assert res_unauth_so.status_code == 401, f"Expected 401, got {res_unauth_so.status_code}"
        print("   Unauthorized tampering safely rejected with HTTP 401 Unauthorized!")

        print("\n" + "=" * 70)
        print("ALL PRODUCTION SMOKE TESTS PASSED WITH 100% SUCCESS!")
        print("=" * 70 + "\n")

if __name__ == '__main__':
    run_prod_smoke_tests()
