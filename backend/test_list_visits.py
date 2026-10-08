from fastapi import Depends
from app.core.database import SessionLocal
from app.api.visits import list_visits
from app.models.all_models import User

db = SessionLocal()
user = db.query(User).filter_by(username="YHS-EMP-002").first()

try:
    res = list_visits(db=db, current_user=user)
    print("Visits returned:", len(res))
except Exception as e:
    print("Exception occurred!")
    import traceback
    traceback.print_exc()
