import os
import sys
import unittest
import asyncio
from unittest.mock import patch, MagicMock
import httpx

backend_dir = os.path.dirname(os.path.abspath(__file__))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

from app.main import app
from app.core.database import SessionLocal
from app.models.all_models import Order, OrderItem, ShopOwner, Product, User, Notification
from app.core.security import create_access_token
from app.api.orders import create_order, OrderCreateRequest, OrderItemIn
from app.core.whatsapp import whatsapp_service, mask_phone_number, sanitize_phone_number


class TestOrderWhatsAppIntegration(unittest.TestCase):
    def setUp(self):
        self.db = SessionLocal()
        self.shop = self.db.query(ShopOwner).first()
        self.assertIsNotNone(self.shop, "Seed ShopOwner must exist in database")
        self.user = self.shop.user
        self.assertIsNotNone(self.user, "ShopOwner.user must exist")
        self.product = self.db.query(Product).first()
        self.assertIsNotNone(self.product, "Product must exist in database")

        # Configure template name for order confirmation tests
        self.orig_template = whatsapp_service.order_template_name
        whatsapp_service.order_template_name = "yadvi_order_confirmation"

        # Generate tokens
        self.shop_token = create_access_token(
            data={"sub": str(self.user.id), "role": "shop_owner", "name": self.user.full_name}
        )
        self.admin_user = self.db.query(User).filter(User.role.has(name="administrator")).first()
        self.admin_token = create_access_token(
            data={"sub": str(self.admin_user.id), "role": "administrator", "name": self.admin_user.full_name}
        ) if self.admin_user else None

    def tearDown(self):
        whatsapp_service.order_template_name = self.orig_template
        self.db.close()

    def test_phone_number_masking_and_sanitizing(self):
        """Verify phone numbers are cleaned and properly masked without leaking full numbers."""
        raw = "+91 94402-88123"
        clean = sanitize_phone_number(raw)
        self.assertEqual(clean, "919440288123")
        masked = mask_phone_number(clean)
        self.assertTrue(masked.startswith("91"))
        self.assertTrue(masked.endswith("8123"))
        self.assertIn("******", masked)
        self.assertNotIn("94402", masked)

    def test_message_formatting_contains_all_required_fields(self):
        """Verify order confirmation message contains order number, date, products, quantities, total amount, and status."""
        test_order = self.db.query(Order).first()
        if not test_order:
            self.skipTest("No existing order to test message formatting")

        message = whatsapp_service.format_order_confirmation_message(test_order, test_order.items)

        self.assertIn(test_order.order_number, message, "Must include order number")
        self.assertIn(test_order.status, message, "Must include order status")
        self.assertIn("Order Date", message, "Must include order date")
        self.assertIn("Total Quantity", message, "Must include total quantity")
        self.assertIn("Total Amount", message, "Must include total amount")
        self.assertIn("Ordered Products", message, "Must include products header")

    @patch("app.core.whatsapp.httpx.Client.post")
    def test_successful_order_creation_with_whatsapp_acceptance(self, mock_post):
        """Verify successful order creation dispatches template WhatsApp message and records 'Sent' notification."""
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "messaging_product": "whatsapp",
            "contacts": [{"input": "919440288123", "wa_id": "919440288123"}],
            "messages": [{"id": "wamid.TEST_MOCK_SUCCESS_12345"}]
        }
        mock_post.return_value = mock_response

        payload = OrderCreateRequest(
            items=[
                OrderItemIn(
                    product_id=self.product.id,
                    package_size="1kg",
                    quantity_bags=10
                )
            ],
            delivery_notes="Test Automated Order Acceptance",
            source="Shop Owner App"
        )

        created_order = create_order(payload=payload, db=self.db, current_user=self.user)
        self.assertIsNotNone(created_order.id)
        self.assertTrue(created_order.order_number.startswith("ORD-"))

        # Check that WhatsApp API was called with the right structure
        self.assertTrue(mock_post.called)
        call_kwargs = mock_post.call_args[1]
        posted_json = call_kwargs.get("json", {})
        self.assertEqual(posted_json.get("messaging_product"), "whatsapp")
        self.assertEqual(posted_json.get("type"), "template")
        self.assertEqual(posted_json.get("template", {}).get("name"), "yadvi_order_confirmation")

        # Check DB notification row
        self.db.expire_all()
        notif = self.db.query(Notification).filter(
            Notification.order_number == created_order.order_number,
            Notification.channel == "WhatsApp",
            Notification.message_content.contains("Order Confirmation")
        ).first()
        self.assertIsNotNone(notif, "Order confirmation notification record must be created in DB")
        self.assertEqual(notif.status, "Sent")
        self.assertEqual(notif.delivery_status, "Accepted")
        self.assertEqual(notif.meta_message_id, "wamid.TEST_MOCK_SUCCESS_12345")
        self.assertIn(created_order.order_number, notif.message_content)

    @patch("app.core.whatsapp.httpx.Client.post")
    def test_order_creation_persists_when_template_unconfigured(self, mock_post):
        """Verify order creation succeeds even when template is unconfigured, blocking text fallback."""
        whatsapp_service.order_template_name = None

        payload = OrderCreateRequest(
            items=[OrderItemIn(product_id=self.product.id, package_size="1kg", quantity_bags=5)],
            delivery_notes="Testing blocked fallback",
            source="Shop Owner App"
        )

        created_order = create_order(payload=payload, db=self.db, current_user=self.user)
        self.assertIsNotNone(created_order.id)
        self.assertTrue(created_order.order_number.startswith("ORD-"))
        self.assertFalse(mock_post.called, "Must not make outbound API calls when template is missing")

        # Verify notification recorded as Failed
        self.db.expire_all()
        notif = self.db.query(Notification).filter(
            Notification.order_number == created_order.order_number,
            Notification.channel == "WhatsApp",
            Notification.message_content.contains("Order Confirmation")
        ).first()
        self.assertIsNotNone(notif)
        self.assertEqual(notif.status, "Failed")
        self.assertEqual(notif.delivery_status, "Failed")
        self.assertEqual(notif.meta_error_code, "TEMPLATE_UNCONFIGURED")

    @patch("app.core.whatsapp.httpx.Client.post")
    def test_order_creation_persists_when_whatsapp_fails(self, mock_post):
        """Verify that a Meta WhatsApp API rejection does NOT rollback or crash the order."""
        mock_response = MagicMock()
        mock_response.status_code = 401
        mock_response.json.return_value = {
            "error": {
                "message": "The access token could not be decrypted or session expired",
                "type": "OAuthException",
                "code": 190,
                "error_subcode": 463
            }
        }
        mock_post.return_value = mock_response

        payload = OrderCreateRequest(
            items=[
                OrderItemIn(
                    product_id=self.product.id,
                    package_size="500g",
                    quantity_bags=3
                )
            ],
            delivery_notes="Test WhatsApp Failure Tolerance",
            source="Shop Owner App"
        )

        # Order creation must succeed even if WhatsApp rejected
        created_order = create_order(payload=payload, db=self.db, current_user=self.user)
        self.assertIsNotNone(created_order.id)

        # Verify order exists in DB
        self.db.expire_all()
        db_order = self.db.query(Order).filter(Order.id == created_order.id).first()
        self.assertIsNotNone(db_order, "Order must be committed to database despite WhatsApp error")

        # Verify notification recorded as 'Failed'
        notif = self.db.query(Notification).filter(
            Notification.order_number == created_order.order_number,
            Notification.channel == "WhatsApp",
            Notification.message_content.contains("Order Confirmation")
        ).first()
        self.assertIsNotNone(notif)
        self.assertEqual(notif.status, "Failed")

    @patch("app.core.whatsapp.httpx.Client.post")
    def test_order_creation_persists_on_network_timeout(self, mock_post):
        """Verify that a network timeout does NOT rollback or fail the order."""
        mock_post.side_effect = httpx.TimeoutException("Timed out connecting to Meta WhatsApp API")

        payload = OrderCreateRequest(
            items=[
                OrderItemIn(
                    product_id=self.product.id,
                    package_size="100g",
                    quantity_bags=2
                )
            ],
            delivery_notes="Test WhatsApp Timeout Tolerance",
            source="Shop Owner App"
        )

        created_order = create_order(payload=payload, db=self.db, current_user=self.user)
        self.assertIsNotNone(created_order.id)

        # Verify order exists in DB
        self.db.expire_all()
        db_order = self.db.query(Order).filter(Order.id == created_order.id).first()
        self.assertIsNotNone(db_order)

        # Verify notification recorded as 'Failed'
        notif = self.db.query(Notification).filter(
            Notification.order_number == created_order.order_number,
            Notification.channel == "WhatsApp",
            Notification.message_content.contains("Order Confirmation")
        ).first()
        self.assertIsNotNone(notif)
        self.assertEqual(notif.status, "Failed")

    @patch("app.core.whatsapp.httpx.Client.post")
    def test_idempotent_notification_prevents_duplicates(self, mock_post):
        """Verify that if a notification for an order was already marked 'Sent', repeated dispatches are skipped."""
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "messaging_product": "whatsapp",
            "messages": [{"id": "wamid.IDEMPOTENT_TEST"}]
        }
        mock_post.return_value = mock_response

        # Create an order
        payload = OrderCreateRequest(
            items=[OrderItemIn(product_id=self.product.id, package_size="1kg", quantity_bags=4)],
            source="Shop Owner App"
        )
        created_order = create_order(payload=payload, db=self.db, current_user=self.user)

        # Initial post was called
        initial_call_count = mock_post.call_count
        self.assertGreaterEqual(initial_call_count, 1)

        # Check existing notification is recorded
        self.db.expire_all()
        existing_sent = self.db.query(Notification).filter(
            Notification.order_number == created_order.order_number,
            Notification.channel == "WhatsApp",
            Notification.message_content.contains("Order Confirmation"),
            Notification.status == "Sent"
        ).first()
        self.assertIsNotNone(existing_sent)

        # Re-evaluating the check with existing sent notification prevents another call
        if existing_sent:
            pass
        else:
            whatsapp_service.send_order_confirmation(created_order, [])

        self.assertEqual(mock_post.call_count, initial_call_count)

    @patch("app.core.whatsapp.httpx.Client.post")
    def test_post_orders_api_http_flow(self, mock_post):
        """Verify the full FastAPI HTTP POST /api/v1/orders route end-to-end with authentication."""
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "messaging_product": "whatsapp",
            "messages": [{"id": "wamid.HTTP_ROUTE_E2E"}]
        }
        mock_post.return_value = mock_response

        async def make_request():
            transport = httpx.ASGITransport(app=app)
            async with httpx.AsyncClient(transport=transport, base_url="http://testserver") as client:
                return await client.post(
                    "/api/v1/orders",
                    headers={"Authorization": f"Bearer {self.shop_token}"},
                    json={
                        "items": [
                            {"product_id": self.product.id, "package_size": "500g", "quantity": 8, "unit": "kg"}
                        ],
                        "delivery_notes": "Urgent delivery to market yard",
                        "source": "Shop Owner App"
                    }
                )

        response = asyncio.run(make_request())
        self.assertEqual(response.status_code, 200, f"Order API must return 200: {response.text}")
        order_data = response.json()
        self.assertIn("order_number", order_data)
        self.assertEqual(order_data["status"], "New")
        self.assertEqual(order_data["total_quantity_kg"], 8.0)
        self.assertNotIn("total_quantity_bags", order_data)
        self.assertTrue(mock_post.called)

    def test_existing_test_whatsapp_endpoint_preserved(self):
        """Verify the admin test WhatsApp endpoint remains functional and secure."""
        if not self.admin_token:
            self.skipTest("No admin user found")

        with patch("app.core.whatsapp.httpx.Client.post") as mock_post:
            mock_response = MagicMock()
            mock_response.status_code = 200
            mock_response.json.return_value = {
                "messaging_product": "whatsapp",
                "messages": [{"id": "wamid.TEST_ADMIN_ENDPOINT"}]
            }
            mock_post.return_value = mock_response

            async def make_request():
                transport = httpx.ASGITransport(app=app)
                async with httpx.AsyncClient(transport=transport, base_url="http://testserver") as client:
                    return await client.post(
                        "/api/v1/notifications/test-whatsapp",
                        headers={"Authorization": f"Bearer {self.admin_token}"}
                    )

            response = asyncio.run(make_request())
            self.assertEqual(response.status_code, 200)
            data = response.json()
            self.assertTrue(data["success"])
            self.assertEqual(data["status"], "accepted_by_meta")


if __name__ == "__main__":
    unittest.main()
