import urllib.request
import json
import uuid
import sys
import mimetypes
from app.core.security import create_access_token
from app.core.database import SessionLocal
from app.models.all_models import User, ShopOwner, FieldExecutive, Visit

db = SessionLocal()
suresh = db.query(User).filter(User.username == "FE001").first()
if not suresh:
    print("Suresh not found")
    sys.exit(1)
suresh_exec = db.query(FieldExecutive).filter(FieldExecutive.user_id == suresh.id).first()

# Find a pending visit for Suresh
visit = db.query(Visit).filter(Visit.executive_id == suresh_exec.id, Visit.status == "Pending").first()
if not visit:
    print("No pending visit found")
    sys.exit(1)

# Generate a fake image file content
image_content = b"fake_image_bytes"
boundary = uuid.uuid4().hex
headers = {
    "Authorization": f"Bearer {create_access_token({'sub': str(suresh.id), 'role': 'field_executive'})}",
    "Content-Type": f"multipart/form-data; boundary={boundary}"
}

# Construct multipart body
body = bytearray()
def add_field(name, value):
    body.extend(f"--{boundary}\r\n".encode('utf-8'))
    body.extend(f'Content-Disposition: form-data; name="{name}"\r\n\r\n'.encode('utf-8'))
    body.extend(f'{value}\r\n'.encode('utf-8'))

def add_file(name, filename, content):
    body.extend(f"--{boundary}\r\n".encode('utf-8'))
    body.extend(f'Content-Disposition: form-data; name="{name}"; filename="{filename}"\r\n'.encode('utf-8'))
    body.extend(f'Content-Type: image/jpeg\r\n\r\n'.encode('utf-8'))
    body.extend(content)
    body.extend(b'\r\n')

add_field("photo_lat", "16.5062")
add_field("photo_lng", "80.648")
add_field("notes", "Test notes")
add_file("file", "test_photo.jpg", image_content)
body.extend(f"--{boundary}--\r\n".encode('utf-8'))

req = urllib.request.Request(
    f"http://127.0.0.1:8000/api/v1/visits/{visit.id}/upload-photo",
    data=body,
    headers=headers,
    method="POST"
)

try:
    resp = urllib.request.urlopen(req)
    print("Upload Result:", resp.read().decode('utf-8'))
except urllib.error.HTTPError as e:
    print("HTTP Error:", e.code, e.read().decode('utf-8'))
