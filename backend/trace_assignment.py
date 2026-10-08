import requests
import sqlite3
import json

BASE_URL = "http://127.0.0.1:8000/api/v1"
DB_PATH = "C:/Users/Acer/.gemini/antigravity/scratch/yadvi-seeds-app/backend/yadvi_seeds.db"

def main():
    from app.core.security import create_access_token
    admin_token = create_access_token({"sub": "1"})
    
    print("STEP 1: ASSIGN SHOP 1 to FE 1")
    headers_admin = {"Authorization": f"Bearer {admin_token}", "Content-Type": "application/json"}
    resp = requests.put(f"{BASE_URL}/shops/1/assign", headers=headers_admin, json={"executive_id": 1})
    print("Status:", resp.status_code)
    print("Response:", resp.text)
    
    print("\nSTEP 2: CHECK DB")
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    c = conn.cursor()
    for row in c.execute("SELECT * FROM visits WHERE shop_id = 1 AND executive_id = 1 ORDER BY id DESC LIMIT 1"):
        print("VISIT CREATED:", dict(row))

if __name__ == "__main__":
    import sys
    sys.path.append("C:/Users/Acer/.gemini/antigravity/scratch/yadvi-seeds-app/backend")
    main()
