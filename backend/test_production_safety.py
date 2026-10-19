"""
Offline Unit Test Suite for Production-Safety Hardening:
1. Configuration & Startup Safety (CR-02 & CR-03)
2. Firebase ADC & Local Degradation Support (CR-05)
3. Authenticated Private Visit-Photo Delivery & Memory-Bounded Streaming (CR-01 & CR-04)
"""

import os
import io
from datetime import datetime, timedelta
from unittest.mock import MagicMock, patch
import pytest
import httpx
import asyncio
from jose import jwt

class AppTestClient:
    """Robust ASGI test client wrapper compatible with httpx 0.28+."""
    def __init__(self, target_app):
        self.transport = httpx.ASGITransport(app=target_app)

    def get(self, url: str, headers=None, params=None):
        async def _run():
            async with httpx.AsyncClient(transport=self.transport, base_url="http://testserver") as client:
                return await client.get(url, headers=headers, params=params)
        return asyncio.run(_run())

from app.core.config import Settings, DEFAULT_DEV_SECRET_KEY, _resolve_default_auto_init_db
from app.core.firebase import init_firebase, is_firebase_initialized
from app.core.media_storage import (
    LocalStorageBackend,
    GCSStorageBackend,
    reset_media_storage_for_testing,
)
from app.seed_data import init_db
from app.main import app
from app.models.all_models import User, Role, Visit, FieldExecutive, ShopOwner
from app.core.database import get_db


# ==============================================================================
# Part A: Configuration & Startup Safety Tests (CR-02 & CR-03)
# ==============================================================================

class TestProductionConfigHardening:
    """Verifies that development defaults remain friendly and production fails closed."""

    def test_development_defaults_allow_auto_init_and_default_secret(self):
        with patch.dict(os.environ, {"ENVIRONMENT": "development"}, clear=False):
            os.environ.pop("AUTO_INIT_DB", None)
            os.environ.pop("SECRET_KEY", None)
            cfg = Settings(ENVIRONMENT="development", AUTO_INIT_DB=_resolve_default_auto_init_db())
            assert cfg.AUTO_INIT_DB is True
            assert cfg.SECRET_KEY == DEFAULT_DEV_SECRET_KEY

    def test_production_defaults_auto_init_db_to_false(self):
        with patch.dict(os.environ, {
            "ENVIRONMENT": "production",
            "SECRET_KEY": "prod-secure-random-secret-key-abcdef123456"
        }, clear=False):
            os.environ.pop("AUTO_INIT_DB", None)
            cfg = Settings(
                ENVIRONMENT="production",
                AUTO_INIT_DB=_resolve_default_auto_init_db(),
                SECRET_KEY="prod-secure-random-secret-key-abcdef123456"
            )
            assert cfg.AUTO_INIT_DB is False

    def test_staging_defaults_auto_init_db_to_false(self):
        with patch.dict(os.environ, {
            "ENVIRONMENT": "staging",
            "SECRET_KEY": "staging-secure-random-secret-key-abcdef123456"
        }, clear=False):
            os.environ.pop("AUTO_INIT_DB", None)
            cfg = Settings(
                ENVIRONMENT="staging",
                AUTO_INIT_DB=_resolve_default_auto_init_db(),
                SECRET_KEY="staging-secure-random-secret-key-abcdef123456"
            )
            assert cfg.AUTO_INIT_DB is False

    @pytest.mark.parametrize("env_name", ["production", "staging"])
    def test_production_and_staging_reject_explicit_auto_init_true(self, env_name):
        with patch.dict(os.environ, {
            "ENVIRONMENT": env_name,
            "AUTO_INIT_DB": "true",
            "SECRET_KEY": "some-valid-production-secret-998877"
        }, clear=False):
            with pytest.raises(RuntimeError) as exc_info:
                Settings(
                    ENVIRONMENT=env_name,
                    AUTO_INIT_DB=True,
                    SECRET_KEY="some-valid-production-secret-998877"
                )
            assert "AUTO_INIT_DB is enabled" in str(exc_info.value)
            assert f"'{env_name}' mode" in str(exc_info.value)
            assert "strictly forbidden" in str(exc_info.value)

    @pytest.mark.parametrize("env_name", ["production", "staging"])
    def test_production_rejects_default_or_empty_secret_key(self, env_name):
        with patch.dict(os.environ, {
            "ENVIRONMENT": env_name,
            "AUTO_INIT_DB": "false",
        }, clear=False):
            # Test default secret
            with pytest.raises(RuntimeError) as exc_info:
                Settings(
                    ENVIRONMENT=env_name,
                    AUTO_INIT_DB=False,
                    SECRET_KEY=DEFAULT_DEV_SECRET_KEY
                )
            assert "Insecure SECRET_KEY detected" in str(exc_info.value)
            assert DEFAULT_DEV_SECRET_KEY not in str(exc_info.value)  # Must not leak secret in message

            # Test empty secret
            with pytest.raises(RuntimeError) as exc_info2:
                Settings(
                    ENVIRONMENT=env_name,
                    AUTO_INIT_DB=False,
                    SECRET_KEY=""
                )
            assert "Insecure SECRET_KEY detected" in str(exc_info2.value)

    def test_init_db_guard_aborts_in_production(self):
        with patch("app.core.config.settings.ENVIRONMENT", "production"):
            with pytest.raises(RuntimeError) as exc_info:
                init_db()
            assert "strictly forbidden in 'production' mode" in str(exc_info.value)


# ==============================================================================
# Part B: Firebase ADC & Degradation Tests (CR-05)
# ==============================================================================

class TestFirebaseADCHardening:
    """Verifies Firebase certificate, ADC support, and safe degradation."""

    def test_firebase_skips_if_already_initialized(self):
        with patch("firebase_admin._apps", {"[DEFAULT]": MagicMock()}):
            assert is_firebase_initialized() is True
            assert init_firebase() is True

    @patch("firebase_admin._apps", {})
    @patch("firebase_admin.credentials.Certificate")
    @patch("firebase_admin.initialize_app")
    @patch("os.path.isfile", return_value=True)
    def test_firebase_initializes_from_valid_certificate(self, mock_isfile, mock_init, mock_cert):
        mock_cred_obj = MagicMock()
        mock_cert.return_value = mock_cred_obj

        with patch("app.core.config.settings.FIREBASE_CREDENTIALS_PATH", "/secrets/firebase.json"):
            res = init_firebase()
            assert res is True
            mock_cert.assert_called_once_with("/secrets/firebase.json")
            mock_init.assert_called_once_with(mock_cred_obj)

    @patch("firebase_admin._apps", {})
    @patch("firebase_admin.initialize_app")
    def test_firebase_initializes_with_adc_in_cloud_run(self, mock_init):
        with patch.dict(os.environ, {"K_SERVICE": "yadvi-backend"}, clear=False), \
             patch("app.core.config.settings.FIREBASE_CREDENTIALS_PATH", "/non_existent.json"), \
             patch("os.path.isfile", return_value=False):
            res = init_firebase()
            assert res is True
            mock_init.assert_called_once_with()  # Called without file arguments for ADC

    @patch("firebase_admin._apps", {})
    def test_firebase_degrades_gracefully_in_local_dev_without_credentials(self):
        with patch.dict(os.environ, {}, clear=False), \
             patch("app.core.config.settings.ENVIRONMENT", "development"), \
             patch("app.core.config.settings.FIREBASE_CREDENTIALS_PATH", "./firebase/firebase-service-account.json"), \
             patch("os.path.isfile", return_value=False):
            # Must not raise an error; returns False safely
            res = init_firebase()
            assert res is False

    @patch("firebase_admin._apps", {})
    @patch("firebase_admin.initialize_app", side_effect=Exception("Simulated ADC connection error"))
    def test_firebase_adc_failure_in_cloud_raises_runtime_error(self, mock_init):
        with patch.dict(os.environ, {"K_SERVICE": "yadvi-backend"}, clear=False), \
             patch("os.path.isfile", return_value=False):
            with pytest.raises(RuntimeError) as exc_info:
                init_firebase()
            assert "Firebase ADC initialization error" in str(exc_info.value)


# ==============================================================================
# Part C: Private Visit-Photo Delivery & Streaming Tests (CR-01 & CR-04)
# ==============================================================================

class TestVisitPhotoStreaming:
    """Verifies authenticated streaming, role authorization, and header security."""

    def teardown_method(self):
        reset_media_storage_for_testing(None)

    def _generate_token(self, user_id: int, role: str) -> str:
        payload = {
            "sub": str(user_id),
            "role": role,
            "name": f"User {user_id}",
            "exp": datetime.utcnow() + timedelta(hours=1),
        }
        return jwt.encode(payload, DEFAULT_DEV_SECRET_KEY, algorithm="HS256")

    def _setup_mock_db_with_visit(self):
        """Creates a mock DB session with an authorized visit and associated profiles."""
        mock_db = MagicMock()

        # Admin user (ID 1)
        admin_user = User(id=1, full_name="Admin", is_active=True)
        admin_user.role = Role(id=1, name="administrator")

        # Assigned Executive (ID 10)
        exec_user = User(id=10, full_name="Suresh Babu", is_active=True)
        exec_user.role = Role(id=2, name="field_executive")
        exec_profile = FieldExecutive(id=1, user_id=10, employee_code="EMP-10")
        exec_profile.user = exec_user

        # Associated Shop Owner (ID 20)
        shop_user = User(id=20, full_name="Venkat Rao", is_active=True)
        shop_user.role = Role(id=3, name="shop_owner")
        shop = ShopOwner(id=1, user_id=20, shop_name="Sri Rama Seeds")
        shop.user = shop_user

        # Unrelated Executive (ID 99)
        unrelated_user = User(id=99, full_name="Other Exec", is_active=True)
        unrelated_user.role = Role(id=2, name="field_executive")

        # Target Visit record
        visit = Visit(
            id=50,
            executive_id=1,
            shop_id=1,
            purpose="Routine Audit",
            status="Visited",
            visit_photo_url="/public/visits/visit_test_photo.jpg"
        )
        visit.executive = exec_profile
        visit.shop = shop

        def mock_query(model):
            q = MagicMock()
            if model == User:
                def mock_user_filter(expr):
                    f = MagicMock()
                    uid = getattr(getattr(expr, "right", None), "value", None)
                    if uid == 10:
                        f.first.return_value = exec_user
                    elif uid == 20:
                        f.first.return_value = shop_user
                    elif uid == 99:
                        f.first.return_value = unrelated_user
                    else:
                        f.first.return_value = admin_user
                    return f
                q.filter = mock_user_filter
            elif model == Visit:
                def mock_visit_filter(expr):
                    f = MagicMock()
                    val = getattr(getattr(expr, "right", None), "value", None)
                    if val and "visit_test_photo.jpg" in str(val):
                        f.first.return_value = visit
                    else:
                        f.first.return_value = None
                    return f
                q.filter = mock_visit_filter
            return q

        mock_db.query = mock_query
        return mock_db

    def test_unauthenticated_request_rejected(self):
        client = AppTestClient(app)
        resp = client.get("/public/visits/visit_test_photo.jpg")
        assert resp.status_code == 401
        assert "Authentication token required" in resp.json()["detail"]

    def test_query_token_rejected_preventing_url_leakage(self):
        client = AppTestClient(app)
        token = self._generate_token(1, "administrator")
        # Passing ?token= must NOT authenticate the request
        resp = client.get(f"/public/visits/visit_test_photo.jpg?token={token}")
        assert resp.status_code == 401
        assert "Authentication token required" in resp.json()["detail"]

    def test_unrelated_user_forbidden(self):
        mock_db = self._setup_mock_db_with_visit()
        app.dependency_overrides[get_db] = lambda: mock_db
        try:
            client = AppTestClient(app)
            unrelated_token = self._generate_token(99, "field_executive")
            resp = client.get(
                "/public/visits/visit_test_photo.jpg",
                headers={"Authorization": f"Bearer {unrelated_token}"}
            )
            assert resp.status_code == 403
            assert "Forbidden: You are not authorized" in resp.json()["detail"]
        finally:
            app.dependency_overrides.pop(get_db, None)

    def test_administrator_authorized_and_receives_streamed_content(self):
        mock_db = self._setup_mock_db_with_visit()
        mock_storage = MagicMock()
        image_bytes = b"\xff\xd8\xff\xe0" + b"mock-jpeg-binary-payload-data" * 10
        mock_stream = io.BytesIO(image_bytes)
        mock_storage.open_stream.return_value = (mock_stream, "image/jpeg", len(image_bytes))
        reset_media_storage_for_testing(mock_storage)

        app.dependency_overrides[get_db] = lambda: mock_db
        try:
            client = AppTestClient(app)
            admin_token = self._generate_token(1, "administrator")
            resp = client.get(
                "/public/visits/visit_test_photo.jpg",
                headers={"Authorization": f"Bearer {admin_token}"}
            )
            assert resp.status_code == 200
            assert resp.content == image_bytes
            assert resp.headers["content-type"] == "image/jpeg"
            assert resp.headers["cache-control"] == "private, no-cache, no-store, must-revalidate"
            assert resp.headers["x-content-type-options"] == "nosniff"
            mock_storage.open_stream.assert_called_once_with("visits/visit_test_photo.jpg")
        finally:
            app.dependency_overrides.pop(get_db, None)

    def test_assigned_executive_authorized_to_stream(self):
        mock_db = self._setup_mock_db_with_visit()
        mock_storage = MagicMock()
        image_bytes = b"\xff\xd8\xff\xe0" + b"exec-stream-bytes"
        mock_storage.open_stream.return_value = (io.BytesIO(image_bytes), "image/jpeg", len(image_bytes))
        reset_media_storage_for_testing(mock_storage)

        app.dependency_overrides[get_db] = lambda: mock_db
        try:
            client = AppTestClient(app)
            exec_token = self._generate_token(10, "field_executive")
            resp = client.get(
                "/public/visits/visit_test_photo.jpg",
                headers={"Authorization": f"Bearer {exec_token}"}
            )
            assert resp.status_code == 200
            assert resp.content == image_bytes
        finally:
            app.dependency_overrides.pop(get_db, None)

    def test_associated_shop_owner_authorized_to_stream(self):
        mock_db = self._setup_mock_db_with_visit()
        mock_storage = MagicMock()
        image_bytes = b"\xff\xd8\xff\xe0" + b"shop-stream-bytes"
        mock_storage.open_stream.return_value = (io.BytesIO(image_bytes), "image/jpeg", len(image_bytes))
        reset_media_storage_for_testing(mock_storage)

        app.dependency_overrides[get_db] = lambda: mock_db
        try:
            client = AppTestClient(app)
            shop_token = self._generate_token(20, "shop_owner")
            resp = client.get(
                "/public/visits/visit_test_photo.jpg",
                headers={"Authorization": f"Bearer {shop_token}"}
            )
            assert resp.status_code == 200
            assert resp.content == image_bytes
        finally:
            app.dependency_overrides.pop(get_db, None)

    def test_missing_visit_record_returns_404(self):
        mock_db = self._setup_mock_db_with_visit()
        app.dependency_overrides[get_db] = lambda: mock_db
        try:
            client = AppTestClient(app)
            admin_token = self._generate_token(1, "administrator")
            resp = client.get(
                "/public/visits/non_existent_visit_photo.jpg",
                headers={"Authorization": f"Bearer {admin_token}"}
            )
            assert resp.status_code == 404
            assert "Visit photo record not found" in resp.json()["detail"]
        finally:
            app.dependency_overrides.pop(get_db, None)

    def test_storage_backend_open_stream_failure_handled_cleanly(self):
        mock_db = self._setup_mock_db_with_visit()
        mock_storage = MagicMock()
        mock_storage.open_stream.side_effect = Exception("Storage disk failure or bucket network timeout")
        reset_media_storage_for_testing(mock_storage)

        app.dependency_overrides[get_db] = lambda: mock_db
        try:
            client = AppTestClient(app)
            admin_token = self._generate_token(1, "administrator")
            resp = client.get(
                "/public/visits/visit_test_photo.jpg",
                headers={"Authorization": f"Bearer {admin_token}"}
            )
            assert resp.status_code == 500
            assert "Unable to retrieve media object" in resp.json()["detail"]
            assert "Storage disk failure" not in resp.text  # Must not leak internal details
        finally:
            app.dependency_overrides.pop(get_db, None)
