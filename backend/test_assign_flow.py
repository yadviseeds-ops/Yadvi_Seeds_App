import requests
from app.core.security import create_access_token
from app.models.all_models import User, FieldExecutive
from app.core.database import SessionLocal

BASE_URL = "http://127.0.0.1:8000/api/v1"
db = SessionLocal()

# 1. Login as admin
from app.models.all_models import Role
admin_role = db.query(Role).filter_by(name="administrator").first()
admin_user = db.query(User).filter_by(role_id=admin_role.id).first()
admin_token = create_access_token({"sub": str(admin_user.id)})
headers_admin = {"Authorization": f"Bearer {admin_token}"}

# 2. Create new shop
new_shop = {
    "owner_name": "New Owner",
    "phone": "9999999999",
    "username": "newshop_test",
    "shop_name": "Brand New Shop Test",
    "dealer_code": "DLR-9999",
    "market_location": "Test City",
    "address": "123 Test St"
}
resp = requests.post(f"{BASE_URL}/shops", json=new_shop, headers=headers_admin)
if resp.status_code == 200:
    shop_id = resp.json()["id"]
    print("Created new shop:", shop_id)
else:
    shops = requests.get(f"{BASE_URL}/shops", headers=headers_admin).json()
    shop_id = shops[-1]["id"]
    print("Using existing shop:", shop_id)


# 3. Get FE
employees = requests.get(f"{BASE_URL}/employees", headers=headers_admin).json()
suresh = next(e for e in employees if "Suresh" in e["full_name"])
fe_id = suresh["id"]
fe_user_id = suresh["user_id"]
print("Target FE:", fe_id, suresh["full_name"])

# 4. Assign shop
assign_resp = requests.put(f"{BASE_URL}/shops/{shop_id}/assign", json={"executive_id": fe_id}, headers=headers_admin)
print("Assign response:", assign_resp.json())

# 5. Get visits as FE
fe_token = create_access_token({"sub": str(fe_user_id)})
headers_fe = {"Authorization": f"Bearer {fe_token}"}
visits = requests.get(f"{BASE_URL}/visits", headers=headers_fe).json()
print(f"FE visits (count: {len(visits)}):")
for v in visits:
    print(f"  Shop: {v['shop_name']}, status: {v['status']}, scheduled: {v['scheduled_date']}")

