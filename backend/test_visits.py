import requests

login_url = "http://127.0.0.1:8000/api/v1/auth/login"
data = {"username": "YHS-EMP-002", "password": "password123"}
r = requests.post(login_url, data=data)
if r.status_code != 200:
    print("Login failed", r.text)
else:
    token = r.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    r2 = requests.get("http://127.0.0.1:8000/api/v1/visits", headers=headers)
    print(r2.status_code)
    print(r2.text)
