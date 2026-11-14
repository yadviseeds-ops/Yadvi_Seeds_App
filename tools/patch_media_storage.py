with open('backend/app/core/media_storage.py', 'r', encoding='utf-8') as f:
    content = f.read()

target = """    backend_mode = (getattr(settings, "STORAGE_BACKEND", None) or "local").strip().lower()

    if backend_mode == "gcs":"""

replacement = """    bucket = getattr(settings, "GCS_MEDIA_BUCKET", None)
    raw_backend = getattr(settings, "STORAGE_BACKEND", None)
    if (not raw_backend or raw_backend.strip().lower() == "local") and bucket and str(bucket).strip():
        backend_mode = "gcs"
    else:
        backend_mode = (raw_backend or "local").strip().lower()

    if backend_mode == "gcs":"""

norm_content = content.replace('\r\n', '\n')
norm_target = target.replace('\r\n', '\n')
norm_replacement = replacement.replace('\r\n', '\n')

assert norm_target in norm_content, "Target not found"
new_content = norm_content.replace(norm_target, norm_replacement)
with open('backend/app/core/media_storage.py', 'w', encoding='utf-8', newline='\r\n') as f:
    f.write(new_content)
print("Updated media_storage.py")

