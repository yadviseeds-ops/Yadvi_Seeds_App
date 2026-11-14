"""
Yadvi Hybrid Seeds - Media Storage Abstraction
Supports local filesystem storage (development) and Google Cloud Storage (production).
Enforces MIME validation, file size limits, safe server-side filenames, and least-privilege signed URLs.
"""

import os
import re
import uuid
import logging
from abc import ABC, abstractmethod
from datetime import timedelta
from typing import Optional, Tuple, Any, BinaryIO
from fastapi import HTTPException, status

logger = logging.getLogger(__name__)

# Magic byte signatures for image validation
IMAGE_SIGNATURES = {
    "jpeg": b"\xff\xd8\xff",
    "png": b"\x89PNG\r\n\x1a\n",
    "webp_riff": b"RIFF",
    "webp_magic": b"WEBP",
}

MIME_TO_EXT = {
    "image/jpeg": "jpg",
    "image/png": "png",
    "image/webp": "webp",
}

EXT_TO_MIME = {
    "jpg": "image/jpeg",
    "jpeg": "image/jpeg",
    "png": "image/png",
    "webp": "image/webp",
}


def validate_image_content(
    content: bytes,
    max_size_bytes: int = 5 * 1024 * 1024,
    allowed_extensions: Optional[list[str]] = None,
) -> Tuple[str, str]:
    """
    Validates image binary content using file signatures (magic bytes).
    Rejects empty files, oversized files, invalid headers, and scripts/SVG.
    Returns: (detected_extension, detected_mime_type)
    """
    if not content or len(content) == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Empty file uploaded."
        )

    if len(content) > max_size_bytes:
        max_mb = max_size_bytes / (1024 * 1024)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"File exceeds maximum allowed size of {max_mb:.0f}MB."
        )

    # Reject active content / scripts (SVG, HTML, JS) embedded in binary
    header_sample = content[:1024].lower()
    if b"<svg" in header_sample or b"<html" in header_sample or b"<script" in header_sample:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File contains disallowed active content or scripting."
        )

    # Detect file type by magic bytes
    detected_ext = None
    detected_mime = None

    if content.startswith(IMAGE_SIGNATURES["jpeg"]):
        detected_ext = "jpg"
        detected_mime = "image/jpeg"
    elif content.startswith(IMAGE_SIGNATURES["png"]):
        detected_ext = "png"
        detected_mime = "image/png"
    elif content.startswith(IMAGE_SIGNATURES["webp_riff"]) and len(content) >= 12 and content[8:12] == IMAGE_SIGNATURES["webp_magic"]:
        detected_ext = "webp"
        detected_mime = "image/webp"

    if not detected_ext or not detected_mime:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid image format. Only JPEG, PNG, and WebP images are permitted."
        )

    allowed = allowed_extensions or ["jpg", "jpeg", "png", "webp"]
    if detected_ext not in allowed and (detected_ext == "jpg" and "jpeg" not in allowed):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Disallowed image extension. Permitted: {', '.join(allowed)}"
        )

    return detected_ext, detected_mime


def generate_safe_filename(prefix: str = "", extension: str = "jpg") -> str:
    """Generates a secure server-side UUIDv4 filename with sanitized extension."""
    clean_ext = extension.lstrip(".").lower()
    if clean_ext not in ("jpg", "jpeg", "png", "webp"):
        clean_ext = "jpg"
    safe_uuid = uuid.uuid4().hex
    if prefix:
        # Sanitize prefix to alphanumeric and underscores only
        clean_prefix = re.sub(r"[^a-zA-Z0-9_]", "", prefix)
        return f"{clean_prefix}_{safe_uuid}.{clean_ext}"
    return f"{safe_uuid}.{clean_ext}"


class MediaStorage(ABC):
    """Abstract interface for media storage backends."""

    @abstractmethod
    def save(self, content: bytes, filename: str, content_type: str, folder: str) -> str:
        """
        Persists media content and returns canonical relative URL path
        (e.g., '/public/products/{filename}').
        """
        pass

    @abstractmethod
    def get_url(self, file_path_or_key: str, expires_in: int = 1800) -> str:
        """Returns accessible URL (relative URL in dev, signed/public URL in GCS)."""
        pass

    @abstractmethod
    def exists(self, file_path_or_key: str) -> bool:
        """Checks if the object exists in storage."""
        pass

    @abstractmethod
    def delete(self, file_path_or_key: str) -> bool:
        """Deletes object from storage if it exists."""
        pass

    @abstractmethod
    def generate_signed_url(self, file_path_or_key: str, expires_in: int = 1800) -> str:
        """Generates short-lived signed access URL for private objects."""
        pass

    @abstractmethod
    def open_stream(self, file_path_or_key: str) -> Tuple[Any, str, int]:
        """
        Opens a readable binary stream for the specified media object without loading
        the entire object into memory.
        Returns: (stream_file_like, content_type, content_length)
        """
        pass


class LocalStorageBackend(MediaStorage):
    """Local filesystem storage backend for development and test environments."""

    def __init__(self, base_dir: Optional[str] = None):
        if base_dir:
            self.base_dir = os.path.abspath(base_dir)
        else:
            # Fallback to repo root public directory
            self.base_dir = os.path.abspath(
                os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(__file__)))), "public")
            )
        os.makedirs(self.base_dir, exist_ok=True)

    def _resolve_local_path(self, file_path_or_key: str) -> str:
        """Resolves canonical path avoiding directory traversal attacks."""
        cleaned = file_path_or_key.strip().lstrip("/")
        if cleaned.startswith("public/"):
            cleaned = cleaned[len("public/"):]
        target_path = os.path.abspath(os.path.join(self.base_dir, cleaned))
        if not target_path.startswith(self.base_dir):
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid storage path traversal.")
        return target_path

    def save(self, content: bytes, filename: str, content_type: str, folder: str) -> str:
        folder_clean = re.sub(r"[^a-zA-Z0-9_]", "", folder)
        target_dir = os.path.join(self.base_dir, folder_clean)
        os.makedirs(target_dir, exist_ok=True)

        target_file = os.path.join(target_dir, filename)
        with open(target_file, "wb") as f:
            f.write(content)

        return f"/public/{folder_clean}/{filename}"

    def get_url(self, file_path_or_key: str, expires_in: int = 1800) -> str:
        cleaned = file_path_or_key.strip()
        if not cleaned.startswith("/"):
            cleaned = f"/{cleaned}"
        return cleaned

    def exists(self, file_path_or_key: str) -> bool:
        try:
            path = self._resolve_local_path(file_path_or_key)
            return os.path.isfile(path)
        except Exception:
            return False

    def delete(self, file_path_or_key: str) -> bool:
        try:
            path = self._resolve_local_path(file_path_or_key)
            if os.path.isfile(path):
                os.remove(path)
                return True
        except Exception as e:
            logger.warning(f"Failed to delete local media file {file_path_or_key}: {e}")
        return False

    def generate_signed_url(self, file_path_or_key: str, expires_in: int = 1800) -> str:
        # For local dev, signed URLs map to local relative path
        return self.get_url(file_path_or_key, expires_in)

    def open_stream(self, file_path_or_key: str) -> Tuple[Any, str, int]:
        path = self._resolve_local_path(file_path_or_key)
        if not os.path.isfile(path):
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Media file not found.")
        ext = os.path.splitext(path)[1].lstrip(".").lower()
        content_type = EXT_TO_MIME.get(ext, "application/octet-stream")
        content_length = os.path.getsize(path)
        return open(path, "rb"), content_type, content_length


class GCSStorageBackend(MediaStorage):
    """Google Cloud Storage backend for production Cloud Run deployment."""

    def __init__(self, bucket_name: str, project_id: Optional[str] = None):
        # Sanitize bucket name defensively against trailing options or spaces
        cleaned = str(bucket_name).strip().split()[0].split(",")[0].strip()
        self.bucket_name = cleaned
        self.project_id = project_id
        self._client = None
        self._bucket = None

    @property
    def client(self):
        if self._client is None:
            from google.cloud import storage
            self._client = storage.Client(project=self.project_id)
        return self._client

    @property
    def bucket(self):
        if self._bucket is None:
            self._bucket = self.client.bucket(self.bucket_name)
        return self._bucket

    def _normalize_blob_key(self, file_path_or_key: str) -> str:
        """Strips leading slashes and '/public/' prefix for GCS object key."""
        cleaned = file_path_or_key.strip().lstrip("/")
        if cleaned.startswith("public/"):
            cleaned = cleaned[len("public/"):]
        return cleaned

    def save(self, content: bytes, filename: str, content_type: str, folder: str) -> str:
        folder_clean = re.sub(r"[^a-zA-Z0-9_]", "", folder)
        blob_key = f"{folder_clean}/{filename}"
        blob = self.bucket.blob(blob_key)
        blob.upload_from_string(content, content_type=content_type)
        return f"/public/{folder_clean}/{filename}"

    def get_url(self, file_path_or_key: str, expires_in: int = 1800) -> str:
        blob_key = self._normalize_blob_key(file_path_or_key)
        folder = blob_key.split("/")[0] if "/" in blob_key else ""
        if folder == "visits":
            # Visit photos are private; return signed URL
            return self.generate_signed_url(blob_key, expires_in=expires_in)
        # Products / seeds: return GCS URL or relative path
        return f"https://storage.googleapis.com/{self.bucket_name}/{blob_key}"

    def exists(self, file_path_or_key: str) -> bool:
        try:
            blob_key = self._normalize_blob_key(file_path_or_key)
            blob = self.bucket.blob(blob_key)
            return blob.exists()
        except Exception as e:
            logger.warning(f"GCS exists check failed for {file_path_or_key}: {e}")
            return False

    def delete(self, file_path_or_key: str) -> bool:
        try:
            blob_key = self._normalize_blob_key(file_path_or_key)
            blob = self.bucket.blob(blob_key)
            if blob.exists():
                blob.delete()
                return True
        except Exception as e:
            logger.warning(f"GCS delete failed for {file_path_or_key}: {e}")
        return False

    def generate_signed_url(self, file_path_or_key: str, expires_in: int = 1800) -> str:
        blob_key = self._normalize_blob_key(file_path_or_key)
        blob = self.bucket.blob(blob_key)
        # Generate V4 signed URL with requested expiration
        return blob.generate_signed_url(
            version="v4",
            expiration=timedelta(seconds=expires_in),
            method="GET",
        )

    def open_stream(self, file_path_or_key: str) -> Tuple[Any, str, int]:
        blob_key = self._normalize_blob_key(file_path_or_key)
        blob = self.bucket.blob(blob_key)
        try:
            if hasattr(blob, "reload"):
                blob.reload()
            elif not blob.exists():
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Media object not found.")
        except HTTPException:
            raise
        except Exception as e:
            logger.warning(f"GCS blob metadata check failed for {file_path_or_key}: {e}")
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Media object not found.")

        content_type = getattr(blob, "content_type", None) or "image/jpeg"
        content_length = getattr(blob, "size", 0) or 0
        if content_length > 10 * 1024 * 1024:
            raise HTTPException(
                status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                detail="Media object exceeds allowable stream size limit."
            )

        stream = blob.open("rb")
        return stream, content_type, content_length


_storage_instance: Optional[MediaStorage] = None


def get_media_storage() -> MediaStorage:
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
        )
    elif backend_mode == "local":
        logger.info("Initializing Local Filesystem Media Storage Backend")
        _storage_instance = LocalStorageBackend(base_dir=getattr(settings, "MEDIA_PUBLIC_DIR", None))
    else:
        raise ValueError(
            f"Unsupported STORAGE_BACKEND '{settings.STORAGE_BACKEND}'. "
            "Supported storage backends are 'local' or 'gcs'."
        )

    return _storage_instance


def reset_media_storage_for_testing(backend: Optional[MediaStorage] = None) -> None:
    """Helper to reset or inject storage backend during test suites."""
    global _storage_instance
    _storage_instance = backend
