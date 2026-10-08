import requests

BASE_URL = "http://127.0.0.1:8000/api/v1"

# Using FE user_id 2 based on previous output (Suresh)
from app.core.security import create_access_token
fe_token = create_access_token({"sub": "2"})
headers_fe = {"Authorization": f"Bearer {fe_token}"}
resp = requests.get(f"{BASE_URL}/visits", headers=headers_fe)
print("Status:", resp.status_code)
print("Response:", resp.text)
