import requests
import sqlite3
import json

BASE_URL = "http://127.0.0.1:8000/api/v1"
DB_PATH = "C:/Users/Acer/.gemini/antigravity/scratch/yadvi-seeds-app/backend/yadvi_seeds.db"

def main():
    print("STEP 1: Verify database directly")
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    c = conn.cursor()

    # Get users
    print("\n[USERS]")
    for row in c.execute("SELECT id, username, role_id FROM users WHERE username IN ('suresh', 'admin')"):
        print(dict(row))
        
    # Get FE
    print("\n[FIELD EXECUTIVES]")
    fe_user_id = None
    fe_id = None
    for row in c.execute("SELECT id, user_id, employee_code FROM field_executives"):
        print(dict(row))
        if row["employee_code"] == "FE001":
            fe_user_id = row["user_id"]
            fe_id = row["id"]

    # Get shops
    print("\n[SHOP OWNERS]")
    for row in c.execute("SELECT id, shop_name, assigned_executive_id FROM shop_owners LIMIT 5"):
        print(dict(row))
        
    # Get visits
    print("\n[VISITS]")
    for row in c.execute("SELECT id, shop_id, executive_id, status, scheduled_date FROM visits ORDER BY id DESC LIMIT 5"):
        print(dict(row))

    print("\nSTEP 2: Test API")
    from app.core.security import create_access_token
    
    admin_token = create_access_token({"sub": "1"}) # Assuming admin is ID 1
    fe_token = create_access_token({"sub": str(fe_user_id)})
    
    print("\n[FE VISITS API]")
    headers_fe = {"Authorization": f"Bearer {fe_token}"}
    resp = requests.get(f"{BASE_URL}/visits", headers=headers_fe)
    print("Status:", resp.status_code)
    try:
        visits = resp.json()
        print("Count:", len(visits))
        for v in visits[:3]:
            print(f"ID: {v['id']}, Shop: {v['shop_name']}, Status: {v['status']}, Scheduled: {v['scheduled_date']}")
    except:
        print("Error parsing JSON")

if __name__ == "__main__":
    import sys
    sys.path.append("C:/Users/Acer/.gemini/antigravity/scratch/yadvi-seeds-app/backend")
    main()
