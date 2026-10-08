import requests
from app.core.security import create_access_token
from app.models.all_models import User
from app.core.database import SessionLocal

db = SessionLocal()
user = db.query(User).filter_by(username="FE001").first()
token = create_access_token({"sub": str(user.id)})

headers = {"Authorization": f"Bearer {token}"}
r = requests.get("http://127.0.0.1:8000/api/v1/visits", headers=headers)
print("HTTP STATUS:", r.status_code)
if r.status_code != 200:
    print("RESPONSE:", r.text)
else:
    print("RESPONSE:", len(r.json()), "visits")
