import httpx

PROD_URL = "https://yadvi-day1-test-f5upp75xna-el.a.run.app"
with httpx.Client(base_url=PROD_URL, timeout=15.0) as client:
    res = client.post("/api/v1/auth/login", json={"username": "admin", "password": "admin123"})
    if res.status_code != 200:
        res = client.post("/api/v1/auth/login", json={"username": "admin", "password": "adminpassword123"})
    token = res.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    
    shops = client.get("/api/v1/shops", headers=headers).json()
    print("Shops in production:")
    for s in shops:
        print(s)

    employees = client.get("/api/v1/employees", headers=headers).json()
    print("\nEmployees in production:")
    for e in employees:
        print(e)

