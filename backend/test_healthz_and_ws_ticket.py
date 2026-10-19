"""
Unit tests for /healthz database readiness probe and WebSocket ticket authentication.
Location: backend/test_healthz_and_ws_ticket.py
"""

import sys
import os
import time
import asyncio
import unittest
from unittest.mock import MagicMock, AsyncMock, patch

# Ensure backend root is on sys.path
BACKEND_DIR = os.path.dirname(os.path.abspath(__file__))
if BACKEND_DIR not in sys.path:
    sys.path.insert(0, BACKEND_DIR)

import httpx
from app.main import app
from app.core.websocket import WebSocketTicketManager, ticket_manager
from app.core.security import create_access_token, get_current_user
from app.api.ws import get_current_user_ws


class AppTestClient:
    """ASGI test client wrapper compatible with httpx 0.28+."""
    def __init__(self, target_app):
        self.transport = httpx.ASGITransport(app=target_app)

    def get(self, url: str, headers=None, params=None):
        async def _run():
            async with httpx.AsyncClient(transport=self.transport, base_url="http://testserver") as client:
                return await client.get(url, headers=headers, params=params)
        return asyncio.run(_run())

    def post(self, url: str, headers=None, json=None, data=None):
        async def _run():
            async with httpx.AsyncClient(transport=self.transport, base_url="http://testserver") as client:
                return await client.post(url, headers=headers, json=json, data=data)
        return asyncio.run(_run())


class TestHealthzEndpoint(unittest.TestCase):
    def setUp(self):
        self.client = AppTestClient(app)

    @patch("app.main.SessionLocal")
    def test_healthz_healthy_db(self, mock_session_local):
        """When database executes SELECT 1 successfully, /healthz returns 200 with healthy status."""
        mock_session = MagicMock()
        mock_conn = MagicMock()
        mock_session.connection.return_value.execution_options.return_value.__enter__.return_value = mock_conn
        mock_session_local.return_value = mock_session

        response = self.client.get("/healthz")
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(data.get("status"), "healthy")
        self.assertEqual(data.get("database"), "connected")
        mock_session.close.assert_called_once()

    @patch("app.main.SessionLocal")
    def test_healthz_db_error_fail_closed(self, mock_session_local):
        """When database connection fails, /healthz returns 503 without leaking credentials or tracebacks."""
        sensitive_pass = "super_secret_db_password_xyz123"
        mock_session_local.side_effect = Exception(
            f"mysql+mysqlconnector://user:{sensitive_pass}@10.0.0.1/dbname: Connection refused"
        )

        response = self.client.get("/healthz")
        self.assertEqual(response.status_code, 503)
        data = response.json()
        self.assertEqual(data.get("status"), "unhealthy")
        self.assertEqual(data.get("database"), "disconnected")
        # Ensure zero credentials or internal URLs leak to client
        raw_text = response.text
        self.assertNotIn(sensitive_pass, raw_text)
        self.assertNotIn("10.0.0.1", raw_text)
        self.assertNotIn("Connection refused", raw_text)

    @patch("app.main.SessionLocal")
    def test_healthz_db_timeout(self, mock_session_local):
        """When database query times out, /healthz returns 503 Service Unavailable."""
        mock_session = MagicMock()
        mock_conn = MagicMock()
        mock_conn.execute.side_effect = TimeoutError("Query execution timed out after 2.0s")
        mock_session.connection.return_value.execution_options.return_value.__enter__.return_value = mock_conn
        mock_session_local.return_value = mock_session

        response = self.client.get("/healthz")
        self.assertEqual(response.status_code, 503)
        data = response.json()
        self.assertEqual(data.get("status"), "unhealthy")
        self.assertEqual(data.get("database"), "disconnected")


class TestWebSocketTicketManager(unittest.TestCase):
    def setUp(self):
        self.tm = WebSocketTicketManager(ttl_seconds=2)

    def test_issue_and_consume_ticket(self):
        ticket = self.tm.issue_ticket(user_id=42)
        self.assertIsInstance(ticket, str)
        self.assertGreater(len(ticket), 20)

        # First consumption succeeds
        user_id = self.tm.consume_ticket(ticket)
        self.assertEqual(user_id, 42)

        # Second consumption fails (single-use enforced)
        second_attempt = self.tm.consume_ticket(ticket)
        self.assertIsNone(second_attempt)

    def test_ticket_expiration(self):
        # Short TTL manager
        tm_short = WebSocketTicketManager(ttl_seconds=0.1)
        ticket = tm_short.issue_ticket(user_id=99)
        time.sleep(0.15)
        # Expired ticket must return None
        self.assertIsNone(tm_short.consume_ticket(ticket))

    def test_invalid_ticket_strings(self):
        self.assertIsNone(self.tm.consume_ticket(""))
        self.assertIsNone(self.tm.consume_ticket("non_existent_ticket_12345"))
        self.assertIsNone(self.tm.consume_ticket(None))


class TestWebSocketTicketAPI(unittest.TestCase):
    def setUp(self):
        self.client = AppTestClient(app)
        ticket_manager.reset_for_testing()
        app.dependency_overrides.clear()

    def tearDown(self):
        app.dependency_overrides.clear()

    def test_ws_ticket_unauthenticated(self):
        """Calling /api/v1/auth/ws-ticket without Bearer token returns 401."""
        response = self.client.post("/api/v1/auth/ws-ticket")
        self.assertEqual(response.status_code, 401)

    def test_ws_ticket_authenticated(self):
        """Calling /api/v1/auth/ws-ticket with valid auth returns a valid ticket and TTL."""
        mock_user = MagicMock()
        mock_user.id = 101
        app.dependency_overrides[get_current_user] = lambda: mock_user

        response = self.client.post(
            "/api/v1/auth/ws-ticket",
            headers={"Authorization": "Bearer mock_valid_token"}
        )
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertIn("ticket", data)
        self.assertEqual(data.get("expires_in"), 60)
        ticket = data["ticket"]

        # Verify the ticket was stored and can be consumed for user 101
        consumed_user = ticket_manager.consume_ticket(ticket)
        self.assertEqual(consumed_user, 101)


class TestWebSocketAuthenticationLogic(unittest.TestCase):
    def setUp(self):
        ticket_manager.reset_for_testing()

    def test_ws_connect_with_valid_ticket(self):
        mock_db = MagicMock()
        mock_user = MagicMock()
        mock_user.id = 5
        mock_role = MagicMock()
        mock_role.name = "administrator"
        mock_user.role = mock_role
        mock_db.query.return_value.filter.return_value.first.return_value = mock_user

        ticket = ticket_manager.issue_ticket(user_id=5)

        mock_ws = MagicMock()
        mock_ws.query_params = {"ticket": ticket}
        mock_ws.close = AsyncMock()

        user = asyncio.run(get_current_user_ws(mock_ws, mock_db))
        self.assertIsNotNone(user)
        self.assertEqual(user.id, 5)
        mock_ws.close.assert_not_called()

    def test_ws_rejects_replayed_ticket(self):
        mock_db = MagicMock()
        mock_user = MagicMock()
        mock_user.id = 5
        mock_db.query.return_value.filter.return_value.first.return_value = mock_user

        ticket = ticket_manager.issue_ticket(user_id=5)

        # First connection uses up the ticket
        mock_ws1 = MagicMock()
        mock_ws1.query_params = {"ticket": ticket}
        mock_ws1.close = AsyncMock()
        user1 = asyncio.run(get_current_user_ws(mock_ws1, mock_db))
        self.assertIsNotNone(user1)

        # Second connection attempt with same ticket is rejected with 1008
        mock_ws2 = MagicMock()
        mock_ws2.query_params = {"ticket": ticket}
        mock_ws2.close = AsyncMock()
        user2 = asyncio.run(get_current_user_ws(mock_ws2, mock_db))
        self.assertIsNone(user2)
        mock_ws2.close.assert_called_once_with(code=1008)

    def test_ws_rejects_missing_credentials(self):
        mock_db = MagicMock()
        mock_ws = MagicMock()
        mock_ws.query_params = {}
        mock_ws.close = AsyncMock()

        user = asyncio.run(get_current_user_ws(mock_ws, mock_db))
        self.assertIsNone(user)
        mock_ws.close.assert_called_once_with(code=1008)

    def test_ws_rejects_invalid_ticket(self):
        mock_db = MagicMock()
        mock_ws = MagicMock()
        mock_ws.query_params = {"ticket": "forged_random_ticket_abc123"}
        mock_ws.close = AsyncMock()

        user = asyncio.run(get_current_user_ws(mock_ws, mock_db))
        self.assertIsNone(user)
        mock_ws.close.assert_called_once_with(code=1008)

    def test_ws_deprecated_token_fallback(self):
        mock_db = MagicMock()
        mock_user = MagicMock()
        mock_user.id = 7
        mock_role = MagicMock()
        mock_role.name = "administrator"
        mock_user.role = mock_role
        mock_db.query.return_value.filter.return_value.first.return_value = mock_user

        valid_jwt = create_access_token({"sub": "7", "role": "administrator"})
        mock_ws = MagicMock()
        mock_ws.query_params = {"token": valid_jwt}
        mock_ws.close = AsyncMock()

        user = asyncio.run(get_current_user_ws(mock_ws, mock_db))
        self.assertIsNotNone(user)
        self.assertEqual(user.id, 7)
        mock_ws.close.assert_not_called()

    def test_ws_rejects_invalid_token_fallback(self):
        mock_db = MagicMock()
        mock_ws = MagicMock()
        mock_ws.query_params = {"token": "invalid_jwt_garbage_token"}
        mock_ws.close = AsyncMock()

        user = asyncio.run(get_current_user_ws(mock_ws, mock_db))
        self.assertIsNone(user)
        mock_ws.close.assert_called_once_with(code=1008)


if __name__ == "__main__":
    unittest.main()
