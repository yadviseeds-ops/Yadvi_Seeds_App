with open('backend/app/core/media_storage.py', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Patch GCSStorageBackend.__init__
old_init = '''class GCSStorageBackend(MediaStorage):
    """Google Cloud Storage backend for production Cloud Run deployment."""

    def __init__(self, bucket_name: str, project_id: Optional[str] = None):
        self.bucket_name = bucket_name
        self.project_id = project_id
        self._client = None
        self._bucket = None'''

new_init = '''class GCSStorageBackend(MediaStorage):
    """Google Cloud Storage backend for production Cloud Run deployment."""

    def __init__(self, bucket_name: str, project_id: Optional[str] = None):
        # Sanitize bucket name defensively against trailing options or spaces
        cleaned = str(bucket_name).strip().split()[0].split(",")[0].strip()
        self.bucket_name = cleaned
        self.project_id = project_id
        self._client = None
        self._bucket = None'''

assert old_init in content, 'old_init not found'
content = content.replace(old_init, new_init)

# 2. Patch get_media_storage()
old_get_storage = '''def get_media_storage() -> MediaStorage:
    """Returns the singleton MediaStorage backend configured for current environment."""
    global _storage_instance
    if _storage_instance is not None:
        return _storage_instance

    from app.core.config import settings

    bucket = getattr(settings, "GCS_MEDIA_BUCKET", None)
    raw_backend = getattr(settings, "STORAGE_BACKEND", None)
    if (not raw_backend or raw_backend.strip().lower() == "local") and bucket and str(bucket).strip():
        backend_mode = "gcs"
    else:
        backend_mode = (raw_backend or "local").strip().lower()

    if backend_mode == "gcs":
        bucket = getattr(settings, "GCS_MEDIA_BUCKET", None)
        if not bucket or not str(bucket).strip():
            raise RuntimeError(
                "Invalid media storage configuration: STORAGE_BACKEND is set to 'gcs', "
                "but GCS_MEDIA_BUCKET is missing or empty."
            )
        logger.info(f"Initializing GCS Media Storage Backend (bucket={bucket})")
        _storage_instance = GCSStorageBackend(
            bucket_name=bucket.strip(),
            project_id=getattr(settings, "GCS_PROJECT_ID", None),
        )'''

new_get_storage = '''def get_media_storage() -> MediaStorage:
    """Returns the singleton MediaStorage backend configured for current environment."""
    global _storage_instance
    if _storage_instance is not None:
        return _storage_instance

    from app.core.config import settings

    raw_bucket = getattr(settings, "GCS_MEDIA_BUCKET", None)
    raw_backend = getattr(settings, "STORAGE_BACKEND", None)

    bucket = None
    if raw_bucket and str(raw_bucket).strip():
        cleaned_token = str(raw_bucket).strip().split()[0].split(",")[0].strip()
        if cleaned_token:
            bucket = cleaned_token

    if (not raw_backend or raw_backend.strip().lower() == "local") and bucket:
        backend_mode = "gcs"
    else:
        backend_mode = (raw_backend or "local").strip().lower()

    if backend_mode == "gcs":
        if not bucket:
            raise RuntimeError(
                "Invalid media storage configuration: STORAGE_BACKEND is set to 'gcs', "
                "but GCS_MEDIA_BUCKET is missing or empty."
            )
        logger.info(f"Initializing GCS Media Storage Backend (bucket={bucket})")
        _storage_instance = GCSStorageBackend(
            bucket_name=bucket,
            project_id=getattr(settings, "GCS_PROJECT_ID", None),
        )'''

assert old_get_storage in content, 'old_get_storage not found'
content = content.replace(old_get_storage, new_get_storage)

with open('backend/app/core/media_storage.py', 'w', encoding='utf-8', newline='') as f:
    f.write(content)
print('Successfully patched backend/app/core/media_storage.py')

