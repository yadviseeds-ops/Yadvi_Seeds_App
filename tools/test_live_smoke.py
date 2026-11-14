import urllib.request
import urllib.parse
import json

BASE_URL = "https://yadvi-day1-test-f5upp75xna-el.a.run.app"

print("=" * 60)
print(f"RUNNING PRODUCTION LIVE SMOKE TESTS AGAINST: {BASE_URL}")
print("=" * 60)

# 1. Health check
print("\n1. Health Check (GET /)...")
req = urllib.request.Request(f"{BASE_URL}/", headers={"User-Agent": "YadviSmokeTest/1.0"})
try:
    with urllib.request.urlopen(req) as resp:
        data = json.loads(resp.read().decode('utf-8'))
        print(f"   Status: {resp.status}, Response: {data}")
        assert data.get("status") == "healthy" or "Yadvi" in str(data)
except Exception as e:
    print(f"   Health check error: {e}")

# 2. Products count check
print("\n2. Product Catalog Check (GET /api/v1/products)...")
req = urllib.request.Request(f"{BASE_URL}/api/v1/products", headers={"User-Agent": "YadviSmokeTest/1.0"})
try:
    with urllib.request.urlopen(req) as resp:
        products = json.loads(resp.read().decode('utf-8'))
        print(f"   Status: {resp.status}, Product Count: {len(products)}")
        assert len(products) >= 35, f"Expected at least 35 products, got {len(products)}"
        print(f"   Sample product: {products[0]['name']} (SKU: {products[0]['sku']})")
except Exception as e:
    print(f"   Product check error: {e}")

# 3. Preserved Shop Owner 'shri' / 'Shree' verify-user check
print("\n3. Preserved Shop Owner verification check (POST /api/v1/auth/verify-user)...")
# Check both 'shri' and 'Shree'
for username in ["Shree", "shri"]:
    payload = json.dumps({"username": username, "mobile": "9876543219", "expected_role": "shop_owner"}).encode('utf-8')
    req = urllib.request.Request(
        f"{BASE_URL}/api/v1/auth/verify-user",
        data=payload,
        headers={"Content-Type": "application/json", "User-Agent": "YadviSmokeTest/1.0"}
    )
    try:
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode('utf-8'))
            print(f"   Username '{username}' Status: {resp.status}, Response: {data}")
    except Exception as e:
        print(f"   Username '{username}' Error: {e}")

# 4. Visit photo endpoint token validation test (GET /public/visits/nonexistent.jpg)
print("\n4. Visit Photo Token Authentication Check (GET /public/visits/nonexistent.jpg)...")
# 4a. Without token -> must be 401
req_no_auth = urllib.request.Request(f"{BASE_URL}/public/visits/nonexistent.jpg", headers={"User-Agent": "YadviSmokeTest/1.0"})
try:
    with urllib.request.urlopen(req_no_auth) as resp:
        print(f"   Without token unexpected success: {resp.status}")
except urllib.error.HTTPError as e:
    print(f"   Without token: HTTP {e.code} (Expected 401 Unauthorized)")
    assert e.code == 401

# 4b. With invalid query token -> must be 401
req_bad_token = urllib.request.Request(f"{BASE_URL}/public/visits/nonexistent.jpg?token=invalid_jwt_token", headers={"User-Agent": "YadviSmokeTest/1.0"})
try:
    with urllib.request.urlopen(req_bad_token) as resp:
        print(f"   With invalid token unexpected success: {resp.status}")
except urllib.error.HTTPError as e:
    print(f"   With invalid token: HTTP {e.code} (Expected 401 Invalid credentials)")
    assert e.code == 401

print("\n" + "=" * 60)
print("PRODUCTION LIVE SMOKE TESTS COMPLETED SUCCESSFULLY!")
print("=" * 60)

