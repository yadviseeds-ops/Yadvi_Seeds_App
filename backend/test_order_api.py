import urllib.request
import urllib.error
import json
from app.core.security import create_access_token
from app.core.database import SessionLocal
from app.models.all_models import ShopOwner, User

db = SessionLocal()
shop = db.query(ShopOwner).first()
user = shop.user

user_actual_role = user.role.name if user.role else ""
access_token = create_access_token(
    data={"sub": str(user.id), "role": user_actual_role, "name": user.full_name}
)

order_payload = {
    "items": [
        {
            "product_id": 1,
            "package_size": "1kg",
            "quantity_bags": 5
        }
    ],
    "delivery_notes": "",
    "source": "Shop Owner App"
}

try:
    req = urllib.request.Request(
        'http://127.0.0.1:8000/api/v1/orders',
        data=json.dumps(order_payload).encode('utf-8'),
        headers={'Authorization': 'Bearer ' + access_token, 'Content-Type': 'application/json'}
    )
    resp = urllib.request.urlopen(req).read().decode('utf-8')
    print("SUCCESS:", resp)
except urllib.error.HTTPError as e:
    print("HTTP ERROR:", e.code, e.read().decode('utf-8'))
except Exception as e:
    print("ERROR:", str(e))
