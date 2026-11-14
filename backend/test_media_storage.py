"""
Offline Unit Test Suite for Yadvi Hybrid Seeds Media Storage Abstraction.
Tests:
1. Image validation (magic bytes, MIME type detection, active scripting/SVG rejection).
2. Safe filename generation and directory traversal prevention.
3. LocalStorageBackend operations (save, exists, get_url, delete).
4. GCSStorageBackend operations with mocked Google Cloud Storage client (V4 signed URLs, upload_from_string).
5. Storage factory switching (local vs GCS).
6. Security enforcement (size limits, unauthorized visit photo access prevention).
"""

import os
import io
import tempfile
import pytest
from unittest.mock import MagicMock, patch
from datetime import timedelta
from fastapi import HTTPException

from app.core.media_storage import (
    validate_image_content,
    generate_safe_filename,
    LocalStorageBackend,
    GCSStorageBackend,
    get_media_storage,
    reset_media_storage_for_testing,
    IMAGE_SIGNATURES,
)
from app.core.config import Settings


class TestImageValidation:
    """Tests file signature inspection, MIME validation, and security sanitization."""

    def test_valid_jpeg_signature_accepted(self):
        jpeg_data = b"\xff\xd8\xff\xe0\x00\x10JFIF" + b"\x00" * 64
        ext, mime = validate_image_content(jpeg_data, max_size_bytes=1024 * 1024)
        assert ext == "jpg"
        assert mime == "image/jpeg"

    def test_valid_png_signature_accepted(self):
        png_data = b"\x89PNG\r\n\x1a\n" + b"\x00" * 64
        ext, mime = validate_image_content(png_data, max_size_bytes=1024 * 1024)
        assert ext == "png"
        assert mime == "image/png"

    def test_valid_webp_signature_accepted(self):
        webp_data = b"RIFF\x24\x00\x00\x00WEBPVP8 " + b"\x00" * 64
        ext, mime = validate_image_content(webp_data, max_size_bytes=1024 * 1024)
        assert ext == "webp"
        assert mime == "image/webp"

    def test_empty_content_rejected(self):
        with pytest.raises(HTTPException) as exc_info:
            validate_image_content(b"")
        assert exc_info.value.status_code == 400
        assert "Empty file" in exc_info.value.detail

    def test_oversized_content_rejected(self):
        oversized = b"\xff\xd8\xff" + b"X" * (1024 * 1024 + 1)
        with pytest.raises(HTTPException) as exc_info:
            validate_image_content(oversized, max_size_bytes=1024 * 1024)
        assert exc_info.value.status_code == 400
        assert "exceeds maximum allowed size" in exc_info.value.detail

    def test_corrupted_or_arbitrary_binary_rejected(self):
        bad_data = b"MZ\x90\x00\x03\x00\x00\x00" + b"\x00" * 64  # EXE header
        with pytest.raises(HTTPException) as exc_info:
            validate_image_content(bad_data)
        assert exc_info.value.status_code == 400
        assert "Invalid image format" in exc_info.value.detail

    def test_svg_active_content_rejected(self):
        svg_payload = b"<svg xmlns='http://www.w3.org/2000/svg'><script>alert(1)</script></svg>"
        with pytest.raises(HTTPException) as exc_info:
            validate_image_content(svg_payload)
        assert exc_info.value.status_code == 400
        assert "active content" in exc_info.value.detail

    def test_html_script_injection_rejected(self):
        html_payload = b"<html><script>document.cookie</script></html>"
        with pytest.raises(HTTPException) as exc_info:
            validate_image_content(html_payload)
        assert exc_info.value.status_code == 400
        assert "active content" in exc_info.value.detail

    def test_safe_filename_generation(self):
        fn = generate_safe_filename(prefix="visit_42", extension="jpg")
        assert fn.startswith("visit_42_")
        assert fn.endswith(".jpg")
        assert "/" not in fn
        assert "\\" not in fn
        assert ".." not in fn

    def test_safe_filename_sanitizes_prefix_and_extension(self):
        # Prefix with dangerous characters
        fn = generate_safe_filename(prefix="../../etc/passwd", extension=".exe")
        assert ".." not in fn
        assert "/" not in fn
        # Disallowed extension falls back to safe .jpg
        assert fn.endswith(".jpg")


class TestLocalStorageBackend:
    """Tests local filesystem storage backend isolated in temporary directory."""

    def test_save_and_retrieve_local_file(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            backend = LocalStorageBackend(base_dir=tmp_dir)
            content = b"\xff\xd8\xff" + b"test-jpeg-content"

            url_path = backend.save(content, "product_123.jpg", "image/jpeg", folder="products")
            assert url_path == "/public/products/product_123.jpg"
            assert backend.exists(url_path) is True
            assert backend.exists("/public/products/non_existent.jpg") is False

            # Verify physical file exists in tmp_dir
            physical_file = os.path.join(tmp_dir, "products", "product_123.jpg")
            assert os.path.isfile(physical_file)
            with open(physical_file, "rb") as f:
                assert f.read() == content

            # Test delete
            assert backend.delete(url_path) is True
            assert backend.exists(url_path) is False

    def test_path_traversal_prevention(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            backend = LocalStorageBackend(base_dir=tmp_dir)
            with pytest.raises(HTTPException) as exc_info:
                backend._resolve_local_path("../../../windows/system32/cmd.exe")
            assert exc_info.value.status_code == 400
            assert "traversal" in exc_info.value.detail.lower()

    def test_open_stream_local_file(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            backend = LocalStorageBackend(base_dir=tmp_dir)
            content = b"\xff\xd8\xff\xe0" + b"test-stream-bytes-local"
            url_path = backend.save(content, "stream_test.jpg", "image/jpeg", folder="visits")

            stream, ctype, clen = backend.open_stream(url_path)
            assert ctype == "image/jpeg"
            assert clen == len(content)
            stream_data = stream.read()
            stream.close()
            assert stream_data == content

            # Non-existent file raises 404
            with pytest.raises(HTTPException) as exc_info:
                backend.open_stream("/public/visits/missing.jpg")
            assert exc_info.value.status_code == 404


class TestGCSStorageBackend:
    """Tests Google Cloud Storage backend using mocked google-cloud-storage SDK."""

    @patch("google.cloud.storage.Client")
    def test_save_uploads_blob_with_content_type(self, mock_client_cls):
        mock_client = MagicMock()
        mock_bucket = MagicMock()
        mock_blob = MagicMock()

        mock_client_cls.return_value = mock_client
        mock_client.bucket.return_value = mock_bucket
        mock_bucket.blob.return_value = mock_blob

        backend = GCSStorageBackend(bucket_name="test-bucket", project_id="test-project")
        content = b"\x89PNG\r\n\x1a\n" + b"test-png-content"

        saved_path = backend.save(content, "img_456.png", content_type="image/png", folder="products")

        # Must return canonical relative URL for backward compatibility
        assert saved_path == "/public/products/img_456.png"
        mock_bucket.blob.assert_called_once_with("products/img_456.png")
        mock_blob.upload_from_string.assert_called_once_with(content, content_type="image/png")

    @patch("google.cloud.storage.Client")
    def test_generate_v4_signed_url_for_private_visits(self, mock_client_cls):
        mock_client = MagicMock()
        mock_bucket = MagicMock()
        mock_blob = MagicMock()

        mock_client_cls.return_value = mock_client
        mock_client.bucket.return_value = mock_bucket
        mock_bucket.blob.return_value = mock_blob
        mock_blob.generate_signed_url.return_value = "https://storage.googleapis.com/test-bucket/visits/visit_1.jpg?X-Goog-Signature=mock"

        backend = GCSStorageBackend(bucket_name="test-bucket", project_id="test-project")
        signed_url = backend.generate_signed_url("/public/visits/visit_1.jpg", expires_in=1800)

        assert "X-Goog-Signature" in signed_url
        mock_bucket.blob.assert_called_with("visits/visit_1.jpg")
        mock_blob.generate_signed_url.assert_called_once_with(
            version="v4",
            expiration=timedelta(seconds=1800),
            method="GET",
        )

    @patch("google.cloud.storage.Client")
    def test_gcs_exists_and_delete(self, mock_client_cls):
        mock_client = MagicMock()
        mock_bucket = MagicMock()
        mock_blob = MagicMock()

        mock_client_cls.return_value = mock_client
        mock_client.bucket.return_value = mock_bucket
        mock_bucket.blob.return_value = mock_blob
        mock_blob.exists.return_value = True

        backend = GCSStorageBackend(bucket_name="test-bucket", project_id="test-project")
        assert backend.exists("products/item.jpg") is True
        assert backend.delete("products/item.jpg") is True
        mock_blob.delete.assert_called_once()

    @patch("google.cloud.storage.Client")
    def test_open_stream_gcs_blob(self, mock_client_cls):
        mock_client = MagicMock()
        mock_bucket = MagicMock()
        mock_blob = MagicMock()

        mock_client_cls.return_value = mock_client
        mock_client.bucket.return_value = mock_bucket
        mock_bucket.blob.return_value = mock_blob

        raw_bytes = b"\x89PNG\r\n\x1a\n" + b"gcs-stream-payload"
        mock_blob.open.return_value = io.BytesIO(raw_bytes)
        mock_blob.content_type = "image/png"
        mock_blob.size = len(raw_bytes)

        backend = GCSStorageBackend(bucket_name="test-bucket", project_id="test-project")
        stream, ctype, clen = backend.open_stream("visits/proof.png")

        assert ctype == "image/png"
        assert clen == len(raw_bytes)
        assert stream.read() == raw_bytes

        # Missing blob raises 404
        mock_blob.reload.side_effect = Exception("Not found")
        mock_blob.exists.return_value = False
        with pytest.raises(HTTPException) as exc_info:
            backend.open_stream("visits/non_existent.png")
        assert exc_info.value.status_code == 404


class TestStorageFactory:
    """Verifies environment-based switching between local and GCS storage, fail-closed validation, and lifecycle."""

    def teardown_method(self):
        reset_media_storage_for_testing(None)

    def test_explicit_local_storage_selection(self):
        reset_media_storage_for_testing(None)
        with patch("app.core.config.settings.STORAGE_BACKEND", "local"):
            storage = get_media_storage()
            assert isinstance(storage, LocalStorageBackend)

    def test_default_empty_backend_selects_local_storage(self):
        reset_media_storage_for_testing(None)
        with patch("app.core.config.settings.STORAGE_BACKEND", ""):
            storage = get_media_storage()
            assert isinstance(storage, LocalStorageBackend)

    @patch("google.cloud.storage.Client")
    def test_switches_to_gcs_when_configured(self, mock_client_cls):
        reset_media_storage_for_testing(None)
        with patch("app.core.config.settings.STORAGE_BACKEND", "gcs"), \
             patch("app.core.config.settings.GCS_MEDIA_BUCKET", "yadvi-prod-bucket"), \
             patch("app.core.config.settings.GCS_PROJECT_ID", "yadvi-seed-app-5f306"):
            storage = get_media_storage()
            assert isinstance(storage, GCSStorageBackend)
            assert storage.bucket_name == "yadvi-prod-bucket"
            assert storage.project_id == "yadvi-seed-app-5f306"

    @pytest.mark.parametrize("empty_bucket", [None, "", "   "])
    def test_gcs_fails_closed_when_bucket_missing_or_empty(self, empty_bucket):
        reset_media_storage_for_testing(None)
        with patch("app.core.config.settings.STORAGE_BACKEND", "gcs"), \
             patch("app.core.config.settings.GCS_MEDIA_BUCKET", empty_bucket):
            with pytest.raises(RuntimeError) as exc_info:
                get_media_storage()
            assert "GCS_MEDIA_BUCKET is missing or empty" in str(exc_info.value)

    @pytest.mark.parametrize("invalid_backend", ["s3", "azure", "minio", "ftp"])
    def test_unsupported_storage_backend_raises_error(self, invalid_backend):
        reset_media_storage_for_testing(None)
        with patch("app.core.config.settings.STORAGE_BACKEND", invalid_backend):
            with pytest.raises(ValueError) as exc_info:
                get_media_storage()
            assert f"Unsupported STORAGE_BACKEND '{invalid_backend}'" in str(exc_info.value)
            assert "Supported storage backends are 'local' or 'gcs'" in str(exc_info.value)

    def test_repeated_initialization_singleton_and_reset_behavior(self):
        reset_media_storage_for_testing(None)
        with patch("app.core.config.settings.STORAGE_BACKEND", "local"):
            storage1 = get_media_storage()
            storage2 = get_media_storage()
            # Must return exact same singleton instance
            assert storage1 is storage2

        # After reset, a fresh instance is initialized
        reset_media_storage_for_testing(None)
        with patch("app.core.config.settings.STORAGE_BACKEND", "local"):
            storage3 = get_media_storage()
            assert storage3 is not storage1
            assert isinstance(storage3, LocalStorageBackend)

        # Custom mock injection via reset helper
        mock_custom = MagicMock(spec=GCSStorageBackend)
        reset_media_storage_for_testing(mock_custom)
        assert get_media_storage() is mock_custom


class TestMediaEndpoints:
    """Verifies API route controllers, authorization checks, and content limits."""

    def teardown_method(self):
        reset_media_storage_for_testing(None)

    def test_product_upload_rejects_non_image(self):
        with pytest.raises(HTTPException) as exc_info:
            validate_image_content(b"Not an image at all!", 5 * 1024 * 1024, ["jpg", "jpeg", "png", "webp"])
        assert exc_info.value.status_code == 400
        assert "Invalid image format" in exc_info.value.detail

    def test_product_upload_accepts_valid_image(self):
        with tempfile.TemporaryDirectory() as tmp_dir:
            backend = LocalStorageBackend(base_dir=tmp_dir)
            valid_png = b"\x89PNG\r\n\x1a\n" + b"\x00" * 32
            detected_ext, detected_mime = validate_image_content(valid_png, 5 * 1024 * 1024, ["jpg", "jpeg", "png", "webp"])
            fname = generate_safe_filename(extension=detected_ext)
            image_url = backend.save(valid_png, fname, content_type=detected_mime, folder="products")
            assert image_url.startswith("/public/products/")
            assert image_url.endswith(".png")

    def test_visit_photo_upload_rejects_unassigned_executive(self):
        from fastapi import UploadFile
        from app.api.visits import upload_visit_photo
        from app.models.all_models import User, Role

        exec_user = User(id=10, full_name="Field Exec 1", phone="8888888888")
        exec_user.role = Role(id=2, name="field_executive")

        mock_db = MagicMock()
        mock_visit = MagicMock()
        mock_visit.id = 5
        mock_exec = MagicMock()
        mock_exec.user_id = 99  # Assigned to another executive
        mock_visit.executive = mock_exec

        mock_db.query.return_value.options.return_value.filter.return_value.first.return_value = mock_visit

        valid_jpeg = UploadFile(filename="proof.jpg", file=io.BytesIO(b"\xff\xd8\xff\xe0" + b"\x00" * 32))
        with pytest.raises(HTTPException) as exc_info:
            upload_visit_photo(
                visit_id=5,
                photo_lat=16.5,
                photo_lng=80.6,
                notes=None,
                file=valid_jpeg,
                db=mock_db,
                current_user=exec_user,
            )
        assert exc_info.value.status_code == 403
        assert "Not authorized" in exc_info.value.detail

    def test_visit_photo_upload_authorized_for_assigned_executive(self):
        from datetime import datetime
        from fastapi import UploadFile
        from app.api.visits import upload_visit_photo
        from app.models.all_models import User, Role, Visit, FieldExecutive, ShopOwner

        exec_user = User(id=10, full_name="Field Exec 1", phone="8888888888")
        exec_user.role = Role(id=2, name="field_executive")

        exec_profile = FieldExecutive(id=1, user_id=10, employee_code="EMP-10")
        exec_profile.user = exec_user

        shop_owner_user = User(id=20, full_name="Shop Owner", phone="7777777777")
        shop = ShopOwner(
            id=1,
            user_id=20,
            shop_name="Sri Rama Seeds",
            market_location="Vijayawada",
            address="Market St",
        )
        shop.user = shop_owner_user

        visit = Visit(
            id=5,
            executive_id=1,
            shop_id=1,
            purpose="Dealer Audit",
            status="Pending",
            scheduled_date=datetime.utcnow(),
            bags_ordered=0,
        )
        visit.executive = exec_profile
        visit.shop = shop

        mock_db = MagicMock()
        mock_db.query.return_value.options.return_value.filter.return_value.first.return_value = visit

        with tempfile.TemporaryDirectory() as tmp_dir:
            reset_media_storage_for_testing(LocalStorageBackend(base_dir=tmp_dir))
            valid_jpeg = UploadFile(filename="proof.jpg", file=io.BytesIO(b"\xff\xd8\xff\xe0" + b"\x00" * 32))
            res = upload_visit_photo(
                visit_id=5,
                photo_lat=16.5,
                photo_lng=80.6,
                notes="Dealer visited",
                file=valid_jpeg,
                db=mock_db,
                current_user=exec_user,
            )
            mock_db.commit.assert_called_once()
            assert visit.status == "Visited"
            assert visit.visit_photo_url.startswith("/public/visits/")
            assert res.status == "Visited"
            assert res.photo_url.startswith("/public/visits/")
