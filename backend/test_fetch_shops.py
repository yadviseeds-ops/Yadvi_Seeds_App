import urllib.request
import json
from app.core.security import create_access_token
from app.core.database import SessionLocal
from app.models.all_models import User

db = SessionLocal()
admin = db.query(User).filter(User.username == "ADMIN").first()
token = create_access_token({"sub": str(admin.id), "role": "administrator"})

req = urllib.request.Request("http://127.0.0.1:8000/api/v1/shops", headers={"Authorization": "Bearer " + token})
try:
    resp = urllib.request.urlopen(req).read().decode('utf-8')
    data = json.loads(resp)
    print(json.dumps(data[0], indent=2))
except Exception as e:
    print(e)
