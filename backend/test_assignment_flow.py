import urllib.request
import json
from app.core.security import create_access_token
from app.core.database import SessionLocal
from app.models.all_models import User, ShopOwner, FieldExecutive

db = SessionLocal()
admin = db.query(User).filter(User.username == "ADMIN").first()
admin_token = create_access_token({"sub": str(admin.id), "role": "administrator"})

# Find Shop 1 and Suresh (YHS-EMP-002)
suresh = db.query(User).filter(User.username == "FE001").first()
suresh_exec = db.query(FieldExecutive).filter(FieldExecutive.user_id == suresh.id).first()
shop = db.query(ShopOwner).filter(ShopOwner.id == 1).first()

# Admin Assigns Suresh to Shop 1
req = urllib.request.Request(
    f"http://127.0.0.1:8000/api/v1/shops/{shop.id}/assign",
    data=json.dumps({"executive_id": suresh_exec.id}).encode('utf-8'),
    headers={"Authorization": "Bearer " + admin_token, "Content-Type": "application/json"},
    method="PUT"
)
resp = urllib.request.urlopen(req).read().decode('utf-8')
print("Assignment result:", resp)

# Suresh fetches visits
suresh_token = create_access_token({"sub": str(suresh.id), "role": "field_executive"})
req_v = urllib.request.Request(
    "http://127.0.0.1:8000/api/v1/visits",
    headers={"Authorization": "Bearer " + suresh_token}
)
resp_v = urllib.request.urlopen(req_v).read().decode('utf-8')
visits = json.loads(resp_v)
print("Suresh visits length:", len(visits))
for v in visits:
    print(v["shop_name"], "-", v["status"])
