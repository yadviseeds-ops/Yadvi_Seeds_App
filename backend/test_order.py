from app.main import app
from app.core.database import SessionLocal
from app.models.all_models import ShopOwner, Product
from app.api.orders import create_order, OrderCreateRequest, OrderItemIn
import json

db = SessionLocal()

shop = db.query(ShopOwner).first()
if not shop:
    print("No shop owner found.")
    exit(1)

user = shop.user
product = db.query(Product).first()

payload = OrderCreateRequest(
    items=[
        OrderItemIn(
            product_id=product.id,
            package_size="1kg",
            quantity_bags=5
        )
    ],
    delivery_notes="Test Order directly",
    source="Shop Owner App"
)

try:
    response = create_order(payload=payload, db=db, current_user=user)
    print("Status: 200")
    print(response.model_dump_json(indent=2))
except Exception as e:
    import traceback
    print(f"Status: 500")
    traceback.print_exc()
