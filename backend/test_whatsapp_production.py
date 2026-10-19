import os
import sys
import unittest
import asyncio
import hmac
import hashlib
import json
from datetime import datetime
from unittest.mock import patch, MagicMock
import httpx

backend_dir = os.path.dirname(os.path.abspath(__file__))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

from app.main import app
from app.core.database import SessionLocal
from app.core.config import settings
from app.models.all_models import Order, OrderItem, ShopOwner, Product, User, Notification
from app.core.security import create_access_token
from app.api.orders import create_order, OrderCreateRequest, OrderItemIn
from app.core.whatsapp import whatsapp_service, mask_phone_number, sanitize_phone_number


class TestWhatsAppProductionDelivery(unittest.TestCase):
    def setUp(self):
        self.db = SessionLocal()
        self.shop = self.db.query(ShopOwner).first()
        self.assertIsNotNone(self.shop, "Seed ShopOwner must exist")
        self.user = self.shop.user
        self.product = self.db.query(Product).first()
        self.shop_token = create_access_token(
            data={"sub": str(self.user.id), "role": "shop_owner", "name": self.user.full_name}
        )

        # Test order for component testing
        self.test_order = self.db.query(Order).first()

    def tearDown(self):
        self.db.close()

    def test_build_order_template_components(self):
        """Verify dynamic template parameter builder generates 7 required positional parameters with shop & owner name."""
        if not self.test_order:
            self.skipTest("No test order available")

        components = whatsapp_service.build_order_template_components(self.test_order, self.test_order.items)
        self.assertIsInstance(components, list)
        self.assertEqual(len(components), 1)
        self.assertEqual(components[0]["type"], "body")

        params = components[0]["parameters"]
        self.assertEqual(len(params), 7, "Must contain exactly 7 positional parameters")

        shop_and_owner_param = params[0]["text"]
        order_num_param = params[1]["text"]
        status_param = params[3]["text"]
        bags_param = params[5]["text"]
        billing_param = params[6]["text"]

        # Check shop name and owner name when available
        if self.test_order.shop:
            self.assertIn(self.test_order.shop.shop_name, shop_and_owner_param)
            if self.test_order.shop.user and self.test_order.shop.user.full_name:
                self.assertIn(self.test_order.shop.user.full_name, shop_and_owner_param)

        self.assertIn(self.test_order.order_number, order_num_param)
        self.assertIn(self.test_order.status, status_param)
        self.assertIn(str(self.test_order.total_quantity_bags), bags_param)
        self.assertIn("Billed on Dispatch", billing_param)

    @patch("app.core.whatsapp.httpx.Client.post")
    def test_send_order_confirmation_uses_template_when_configured(self, mock_post):
        """Verify send_order_confirmation dispatches type: 'template' when WHATSAPP_ORDER_TEMPLATE_NAME is set."""
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "messaging_product": "whatsapp",
            "messages": [{"id": "wamid.TEMPLATE_DISPATCH_TEST"}]
        }
        mock_post.return_value = mock_response

        orig_template = whatsapp_service.order_template_name
        try:
            whatsapp_service.order_template_name = "yadvi_order_confirmation"
            result = whatsapp_service.send_order_confirmation(self.test_order, self.test_order.items)

            self.assertTrue(result["success"])
            self.assertEqual(result["dispatch_mode"], "template")
            self.assertEqual(result["template_name"], "yadvi_order_confirmation")
            self.assertEqual(result["meta_message_id"], "wamid.TEMPLATE_DISPATCH_TEST")

            posted_json = mock_post.call_args[1]["json"]
            self.assertEqual(posted_json["type"], "template")
            self.assertEqual(posted_json["template"]["name"], "yadvi_order_confirmation")
            self.assertIn("components", posted_json["template"])
        finally:
            whatsapp_service.order_template_name = orig_template

    @patch("app.core.whatsapp.httpx.Client.post")
    def test_send_order_confirmation_blocks_unconfigured_template(self, mock_post):
        """Verify free-form text fallback is strictly blocked when no template is configured."""
        orig_template = whatsapp_service.order_template_name
        try:
            whatsapp_service.order_template_name = None
            result = whatsapp_service.send_order_confirmation(self.test_order, self.test_order.items)

            self.assertFalse(result["success"])
            self.assertEqual(result["status"], "template_unconfigured")
            self.assertEqual(result["dispatch_mode"], "blocked_unconfigured_template")
            self.assertEqual(result["error_code"], "TEMPLATE_UNCONFIGURED")
            self.assertIsNone(result["meta_message_id"])
            self.assertFalse(mock_post.called, "Must not make outbound API call to Meta when template is unconfigured")
        finally:
            whatsapp_service.order_template_name = orig_template

    def test_webhook_get_verification_handshake(self):
        """Verify GET /webhook handles Meta challenge verification."""
        test_verify_token = "yadvi_webhook_secret_verification_token_2026"
        orig_token = getattr(settings, "WHATSAPP_WEBHOOK_VERIFY_TOKEN", None)
        settings.WHATSAPP_WEBHOOK_VERIFY_TOKEN = test_verify_token

        try:
            async def run_handshake():
                transport = httpx.ASGITransport(app=app)
                async with httpx.AsyncClient(transport=transport, base_url="http://testserver") as client:
                    resp_ok = await client.get(
                        "/api/v1/notifications/webhook",
                        params={
                            "hub.mode": "subscribe",
                            "hub.challenge": "CHALLENGE_STRING_12345",
                            "hub.verify_token": test_verify_token
                        }
                    )
                    resp_fail = await client.get(
                        "/api/v1/notifications/webhook",
                        params={
                            "hub.mode": "subscribe",
                            "hub.challenge": "CHALLENGE_STRING_12345",
                            "hub.verify_token": "wrong_token_here"
                        }
                    )
                    return resp_ok, resp_fail

            resp_ok, resp_fail = asyncio.run(run_handshake())
            self.assertEqual(resp_ok.status_code, 200)
            self.assertEqual(resp_ok.text, "CHALLENGE_STRING_12345")
            self.assertEqual(resp_fail.status_code, 403)
        finally:
            settings.WHATSAPP_WEBHOOK_VERIFY_TOKEN = orig_token

    def test_webhook_post_fails_closed_when_secret_unset(self):
        """Verify POST /webhook fails closed with HTTP 500 when WHATSAPP_APP_SECRET is not configured."""
        orig_secret = getattr(settings, "WHATSAPP_APP_SECRET", None)
        orig_insecure = getattr(settings, "WHATSAPP_ALLOW_INSECURE_WEBHOOKS", False)
        settings.WHATSAPP_APP_SECRET = None
        settings.WHATSAPP_ALLOW_INSECURE_WEBHOOKS = False

        try:
            async def run_req():
                transport = httpx.ASGITransport(app=app)
                async with httpx.AsyncClient(transport=transport, base_url="http://testserver") as client:
                    return await client.post(
                        "/api/v1/notifications/webhook",
                        json={"object": "whatsapp_business_account", "entry": []}
                    )

            resp = asyncio.run(run_req())
            self.assertEqual(resp.status_code, 500, "Must fail closed with 500 when WHATSAPP_APP_SECRET is unset")
        finally:
            settings.WHATSAPP_APP_SECRET = orig_secret
            settings.WHATSAPP_ALLOW_INSECURE_WEBHOOKS = orig_insecure

    def test_webhook_post_signature_validation(self):
        """Verify POST /webhook validates X-Hub-Signature-256 HMAC SHA-256 signature."""
        test_app_secret = "meta_test_app_secret_123"
        orig_secret = getattr(settings, "WHATSAPP_APP_SECRET", None)
        settings.WHATSAPP_APP_SECRET = test_app_secret

        try:
            payload = json.dumps({"object": "whatsapp_business_account", "entry": []}).encode("utf-8")
            valid_sig = "sha256=" + hmac.new(test_app_secret.encode("utf-8"), payload, hashlib.sha256).hexdigest()
            invalid_sig = "sha256=bad_hex_signature_here_00000000000000000000000000000000"

            async def run_sig_checks():
                transport = httpx.ASGITransport(app=app)
                async with httpx.AsyncClient(transport=transport, base_url="http://testserver") as client:
                    # Valid signature
                    resp_valid = await client.post(
                        "/api/v1/notifications/webhook",
                        content=payload,
                        headers={"Content-Type": "application/json", "X-Hub-Signature-256": valid_sig}
                    )
                    # Invalid signature
                    resp_invalid = await client.post(
                        "/api/v1/notifications/webhook",
                        content=payload,
                        headers={"Content-Type": "application/json", "X-Hub-Signature-256": invalid_sig}
                    )
                    # Missing signature
                    resp_missing = await client.post(
                        "/api/v1/notifications/webhook",
                        content=payload,
                        headers={"Content-Type": "application/json"}
                    )
                    return resp_valid, resp_invalid, resp_missing

            resp_valid, resp_invalid, resp_missing = asyncio.run(run_sig_checks())
            self.assertEqual(resp_valid.status_code, 200)
            self.assertEqual(resp_invalid.status_code, 401)
            self.assertEqual(resp_missing.status_code, 401)
        finally:
            settings.WHATSAPP_APP_SECRET = orig_secret

    def test_webhook_status_lifecycle_progression(self):
        """Verify webhook status transitions: Accepted -> Sent -> Delivered -> Read."""
        test_wamid = "wamid.TEST_LIFECYCLE_001"
        notif = Notification(
            recipient_phone="919440288123",
            channel="WhatsApp",
            order_number="ORD-TEST-LIFECYCLE",
            meta_message_id=test_wamid,
            delivery_status="Accepted",
            status="Sent",
            message_content="Test Message Content"
        )
        self.db.add(notif)
        self.db.commit()

        orig_secret = getattr(settings, "WHATSAPP_APP_SECRET", None)
        orig_insecure = getattr(settings, "WHATSAPP_ALLOW_INSECURE_WEBHOOKS", False)
        settings.WHATSAPP_APP_SECRET = None
        settings.WHATSAPP_ALLOW_INSECURE_WEBHOOKS = True  # Explicit dev override for transition testing

        try:
            async def send_status(status_val):
                payload = {
                    "object": "whatsapp_business_account",
                    "entry": [
                        {
                            "id": "WABA_ID",
                            "changes": [
                                {
                                    "value": {
                                        "messaging_product": "whatsapp",
                                        "statuses": [
                                            {
                                                "id": test_wamid,
                                                "status": status_val,
                                                "timestamp": "1728828000",
                                                "recipient_id": "919440288123"
                                            }
                                        ]
                                    },
                                    "field": "messages"
                                }
                            ]
                        }
                    ]
                }
                transport = httpx.ASGITransport(app=app)
                async with httpx.AsyncClient(transport=transport, base_url="http://testserver") as client:
                    return await client.post("/api/v1/notifications/webhook", json=payload)

            # Step 1: Transition to 'sent'
            asyncio.run(send_status("sent"))
            self.db.expire_all()
            updated = self.db.query(Notification).filter(Notification.meta_message_id == test_wamid).first()
            self.assertEqual(updated.delivery_status, "Sent")

            # Step 2: Transition to 'delivered'
            asyncio.run(send_status("delivered"))
            self.db.expire_all()
            updated = self.db.query(Notification).filter(Notification.meta_message_id == test_wamid).first()
            self.assertEqual(updated.delivery_status, "Delivered")
            self.assertEqual(updated.status, "Delivered")
            self.assertIsNotNone(updated.delivered_at)

            # Step 3: Transition to 'read'
            asyncio.run(send_status("read"))
            self.db.expire_all()
            updated = self.db.query(Notification).filter(Notification.meta_message_id == test_wamid).first()
            self.assertEqual(updated.delivery_status, "Read")
            self.assertEqual(updated.status, "Read")
            self.assertIsNotNone(updated.read_at)

        finally:
            settings.WHATSAPP_APP_SECRET = orig_secret
            settings.WHATSAPP_ALLOW_INSECURE_WEBHOOKS = orig_insecure
            self.db.delete(notif)
            self.db.commit()

    def test_delayed_sent_cannot_overwrite_failed(self):
        """Verify delayed 'sent' event cannot overwrite an already 'Failed' notification."""
        test_wamid = "wamid.TEST_FAILED_NOT_OVERWRITTEN"
        notif = Notification(
            recipient_phone="919440288123",
            channel="WhatsApp",
            order_number="ORD-TEST-FAIL-LOCK",
            meta_message_id=test_wamid,
            delivery_status="Failed",
            status="Failed",
            meta_error_code=131047,
            meta_error_message="Re-engagement message",
            message_content="Test Content"
        )
        self.db.add(notif)
        self.db.commit()

        orig_secret = getattr(settings, "WHATSAPP_APP_SECRET", None)
        orig_insecure = getattr(settings, "WHATSAPP_ALLOW_INSECURE_WEBHOOKS", False)
        settings.WHATSAPP_APP_SECRET = None
        settings.WHATSAPP_ALLOW_INSECURE_WEBHOOKS = True

        try:
            delayed_payload = {
                "object": "whatsapp_business_account",
                "entry": [
                    {
                        "changes": [
                            {
                                "value": {
                                    "statuses": [{"id": test_wamid, "status": "sent", "recipient_id": "919440288123"}]
                                }
                            }
                        ]
                    }
                ]
            }
            async def run_delayed():
                transport = httpx.ASGITransport(app=app)
                async with httpx.AsyncClient(transport=transport, base_url="http://testserver") as client:
                    return await client.post("/api/v1/notifications/webhook", json=delayed_payload)

            asyncio.run(run_delayed())
            self.db.expire_all()
            rec = self.db.query(Notification).filter(Notification.meta_message_id == test_wamid).first()
            self.assertEqual(rec.delivery_status, "Failed", "Delayed 'sent' must NOT overwrite 'Failed'")
            self.assertEqual(rec.status, "Failed")
        finally:
            settings.WHATSAPP_APP_SECRET = orig_secret
            settings.WHATSAPP_ALLOW_INSECURE_WEBHOOKS = orig_insecure
            self.db.delete(notif)
            self.db.commit()

    def test_delayed_failed_cannot_overwrite_delivered_or_read(self):
        """Verify delayed 'failed' event cannot overwrite an already 'Delivered' or 'Read' notification."""
        test_wamid = "wamid.TEST_DELIVERED_NOT_FAILED"
        notif = Notification(
            recipient_phone="919440288123",
            channel="WhatsApp",
            order_number="ORD-TEST-DELIV-LOCK",
            meta_message_id=test_wamid,
            delivery_status="Delivered",
            status="Delivered",
            delivered_at=datetime.utcnow(),
            message_content="Test Content"
        )
        self.db.add(notif)
        self.db.commit()

        orig_secret = getattr(settings, "WHATSAPP_APP_SECRET", None)
        orig_insecure = getattr(settings, "WHATSAPP_ALLOW_INSECURE_WEBHOOKS", False)
        settings.WHATSAPP_APP_SECRET = None
        settings.WHATSAPP_ALLOW_INSECURE_WEBHOOKS = True

        try:
            delayed_failed_payload = {
                "object": "whatsapp_business_account",
                "entry": [
                    {
                        "changes": [
                            {
                                "value": {
                                    "statuses": [
                                        {
                                            "id": test_wamid,
                                            "status": "failed",
                                            "recipient_id": "919440288123",
                                            "errors": [{"code": 131047, "title": "Re-engagement message"}]
                                        }
                                    ]
                                }
                            }
                        ]
                    }
                ]
            }
            async def run_fail():
                transport = httpx.ASGITransport(app=app)
                async with httpx.AsyncClient(transport=transport, base_url="http://testserver") as client:
                    return await client.post("/api/v1/notifications/webhook", json=delayed_failed_payload)

            asyncio.run(run_fail())
            self.db.expire_all()
            rec = self.db.query(Notification).filter(Notification.meta_message_id == test_wamid).first()
            self.assertEqual(rec.delivery_status, "Delivered", "Delayed 'failed' must NOT overwrite 'Delivered'")
            self.assertEqual(rec.status, "Delivered")
        finally:
            settings.WHATSAPP_APP_SECRET = orig_secret
            settings.WHATSAPP_ALLOW_INSECURE_WEBHOOKS = orig_insecure
            self.db.delete(notif)
            self.db.commit()

    def test_webhook_failure_event_capture(self):
        """Verify webhook captures error code (e.g. 131047) and error message, transitioning Accepted to Failed."""
        test_wamid = "wamid.TEST_FAILURE_003"
        notif = Notification(
            recipient_phone="919440288123",
            channel="WhatsApp",
            order_number="ORD-TEST-FAIL",
            meta_message_id=test_wamid,
            delivery_status="Accepted",
            status="Sent",
            message_content="Test Message Content"
        )
        self.db.add(notif)
        self.db.commit()

        orig_secret = getattr(settings, "WHATSAPP_APP_SECRET", None)
        orig_insecure = getattr(settings, "WHATSAPP_ALLOW_INSECURE_WEBHOOKS", False)
        settings.WHATSAPP_APP_SECRET = None
        settings.WHATSAPP_ALLOW_INSECURE_WEBHOOKS = True

        try:
            fail_payload = {
                "object": "whatsapp_business_account",
                "entry": [
                    {
                        "changes": [
                            {
                                "value": {
                                    "statuses": [
                                        {
                                            "id": test_wamid,
                                            "status": "failed",
                                            "recipient_id": "919440288123",
                                            "errors": [
                                                {
                                                    "code": 131047,
                                                    "title": "Re-engagement message",
                                                    "message": "More than 24 hours have passed since the customer replied."
                                                }
                                            ]
                                        }
                                    ]
                                }
                            }
                        ]
                    }
                ]
            }
            async def run_fail():
                transport = httpx.ASGITransport(app=app)
                async with httpx.AsyncClient(transport=transport, base_url="http://testserver") as client:
                    return await client.post("/api/v1/notifications/webhook", json=fail_payload)

            asyncio.run(run_fail())
            self.db.expire_all()
            rec = self.db.query(Notification).filter(Notification.meta_message_id == test_wamid).first()
            self.assertEqual(rec.delivery_status, "Failed")
            self.assertEqual(rec.status, "Failed")
            self.assertEqual(rec.meta_error_code, 131047)
            self.assertIn("Re-engagement message", rec.meta_error_message)
        finally:
            settings.WHATSAPP_APP_SECRET = orig_secret
            settings.WHATSAPP_ALLOW_INSECURE_WEBHOOKS = orig_insecure
            self.db.delete(notif)
            self.db.commit()

    @patch("app.core.whatsapp.httpx.Client.post")
    def test_order_creation_persists_when_whatsapp_fails(self, mock_post):
        """Verify order creation completes cleanly in the database even if WhatsApp API rejects."""
        mock_response = MagicMock()
        mock_response.status_code = 500
        mock_response.json.return_value = {"error": {"message": "Meta Internal Server Error", "code": 1}}
        mock_post.return_value = mock_response

        # Set template name so dispatch is attempted but fails at Meta API
        orig_template = whatsapp_service.order_template_name
        whatsapp_service.order_template_name = "yadvi_order_confirmation"

        try:
            payload = OrderCreateRequest(
                items=[OrderItemIn(product_id=self.product.id, package_size="1kg", quantity_bags=6)],
                source="Shop Owner App"
            )
            created_order = create_order(payload=payload, db=self.db, current_user=self.user)
            self.assertIsNotNone(created_order.id)

            # Verify order in DB
            db_order = self.db.query(Order).filter(Order.id == created_order.id).first()
            self.assertIsNotNone(db_order)
            self.assertEqual(db_order.status, "New")

            # Verify notification marked Failed
            self.db.expire_all()
            notif = self.db.query(Notification).filter(
                Notification.order_number == created_order.order_number,
                Notification.channel == "WhatsApp"
            ).order_by(Notification.id.desc()).first()
            self.assertIsNotNone(notif)
            self.assertEqual(notif.status, "Failed")
        finally:
            whatsapp_service.order_template_name = orig_template


if __name__ == "__main__":
    unittest.main()
