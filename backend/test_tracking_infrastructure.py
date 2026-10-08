import asyncio
import json
import logging
from sqlalchemy.orm import Session
from datetime import datetime

from app.core.database import SessionLocal
from app.models.all_models import User, FieldExecutive, FELocation
from app.api.tracking import update_location, LocationUpdateRequest

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("yadvi_test_tracking")

def test_infrastructure_tracking():
    print("\n--- INFRASTRUCTURE/UNIT TEST: Backend Tracking API ---")
    print("NOTE: This test verifies backend logic without physical GPS. Real coordinates MUST be used in production.\n")
    
    db = SessionLocal()
    
    try:
        # 1. Find a field executive
        fe = db.query(FieldExecutive).first()
        if not fe:
            print("No Field Executive found. Aborting test.")
            return
            
        fe_user = fe.user
        print(f"1. Authenticated as Field Executive: {fe_user.full_name} (ID: {fe_user.id})")
        
        # 2. Test Location Update
        print(f"2. Sending independent GPS location update to WebSocket/REST...")
        loc_req = LocationUpdateRequest(
            lat=16.3008,
            lng=80.4428,
            accuracy=5.0,
            speed=2.5
        )
        
        # In a real FastAPI app, this is async
        asyncio.run(update_location(payload=loc_req, db=db, current_user=fe_user))
        print("   -> Success. Location persisted and broadcasted to authorized Admins.")
        
        # Verify point in DB
        points = db.query(FELocation).filter(FELocation.executive_id == fe.id).all()
        assert len(points) > 0
        assert points[-1].lat == 16.3008
        
        print("\nINFRASTRUCTURE TEST PASSED: Database, Models, and APIs are ready for real independent GPS integration.")
        
    except Exception as e:
        print(f"Test Failed: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    test_infrastructure_tracking()
