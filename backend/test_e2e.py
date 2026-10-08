import urllib.request
import json
import sys
from app.core.security import create_access_token
from app.core.database import SessionLocal
from app.models.all_models import User, ShopOwner, FieldExecutive, Product, Order

db = SessionLocal()

admin = db.query(User).filter(User.username == "ADMIN").first()
shop_user = db.query(User).filter(User.username == "SHOP001").first()
fe_user = db.query(User).filter(User.username == "FE001").first()

if not all([admin, shop_user, fe_user]):
    print("Missing base users")
    sys.exit(1)

admin_token = create_access_token({"sub": str(admin.id), "role": "administrator"})
shop_token = create_access_token({"sub": str(shop_user.id), "role": "shop_owner"})
fe_token = create_access_token({"sub": str(fe_user.id), "role": "field_executive"})

product = db.query(Product).first()

# 1. Place Order as Shop Owner
order_payload = {
    "items": [{"product_id": product.id, "package_size": "2 KG", "quantity_bags": 10}],
    "source": "E2E Test Script"
}
req = urllib.request.Request(
    "http://127.0.0.1:8000/api/v1/orders",
    data=json.dumps(order_payload).encode("utf-8"),
    headers={"Authorization": f"Bearer {shop_token}", "Content-Type": "application/json"},
    method="POST"
)
resp = urllib.request.urlopen(req)
order = json.loads(resp.read().decode())
print("Placed Order:", order["order_number"])
order_id = order["id"]

# 2. Update LR as Admin (Advance to Dispatched)
lr_payload = {
    "status": "Dispatched",
    "lr_number": "LR-E2E-9999",
    "transporter_name": "E2E Transporter"
}
req = urllib.request.Request(
    f"http://127.0.0.1:8000/api/v1/orders/{order_id}/status",
    data=json.dumps(lr_payload).encode("utf-8"),
    headers={"Authorization": f"Bearer {admin_token}", "Content-Type": "application/json"},
    method="PUT"
)
resp = urllib.request.urlopen(req)
print("Admin updated LR:", json.loads(resp.read().decode()))

# 3. Verify FE can see the order with LR
req = urllib.request.Request(
    "http://127.0.0.1:8000/api/v1/orders",
    headers={"Authorization": f"Bearer {fe_token}"},
    method="GET"
)
resp = urllib.request.urlopen(req)
fe_orders = json.loads(resp.read().decode())
found = next((o for o in fe_orders if o["id"] == order_id), None)
if found:
    print(f"FE sees Order {found['order_number']} with LR: {found['lr_number']}")
else:
    print("FE does NOT see the order!")
    sys.exit(1)
