import unittest
import os
import sys
import json
import logging
from unittest.mock import patch, MagicMock
from datetime import datetime, timedelta

sys.path.insert(0, os.path.abspath('backend'))

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from fastapi import HTTPException

from app.core.database import Base
from app.core.config import settings
from app.models.all_models import User, Role, ShopOwner, Product, Order, OrderItem, Notification
from app.services.whatsapp_service import (
    GupshupWhatsAppService,
    mask_phone_number,
    sanitize_phone_number,
)
from app.api.orders import create_order, OrderCreateRequest, OrderItemIn


class TestGupshupWhatsAppIntegration(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine('sqlite:///:memory:', echo=False)
        Base.metadata.create_all(bind=self.engine)
        self.Session = sessionmaker(bind=self.engine)
        self.db = self.Session()

        # Seed roles
        self.admin_role = Role(id=1, name="administrator")
        self.so_role = Role(id=3, name="shop_owner")
        self.db.add_all([self.admin_role, self.so_role])

        # Admin User
        self.admin_user = User(
            id=1,
            username="admin",
            phone="9876500000",
            full_name="Admin Yadvi",
            role_id=1,
            is_active=True
        )
        self.admin_user.role = self.admin_role

        # Dealer User
        self.dealer_user = User(
            id=10,
            username="dealer_shree",
            phone="9876543210",
            full_name="Ramesh Bhai",
            role_id=3,
            is_active=True
        )
        self.dealer_user.role = self.so_role

        # Shop Profile
        self.shop = ShopOwner(
            id=1,
            user_id=10,
            shop_name="Shree Seeds Agency",
            market_location="Indore",
            address="Mandi Gate No 2, Indore",
            opening_stock_bags=100,
            current_stock_bags=100,
            status="Active"
        )
        self.shop.user = self.dealer_user

        # Products
        self.product1 = Product(
            id=1,
            name="Maize Hybrid",
            variety_type="Hybrid",
            sku="SKU-MAIZE-01",
            category="Field Crops",
            image_url="/seeds/seed_01.jpeg",
            available_stock_kg=1000.0,
            available_stock_bags=500,
            availability="In Stock"
        )
        self.product2 = Product(
            id=2,
            name="Cotton Gold",
            variety_type="Bt Cotton",
            sku="SKU-COTTON-02",
            category="Fiber",
            image_url="/seeds/seed_02.jpeg",
            available_stock_kg=500.0,
            available_stock_bags=500,
            availability="In Stock"
        )

        self.db.add_all([self.admin_user, self.dealer_user, self.shop, self.product1, self.product2])
        self.db.commit()

        # Set up Gupshup settings
        self.orig_api_key = settings.GUPSHUP_API_KEY
        self.orig_source = settings.GUPSHUP_SOURCE_NUMBER
        self.orig_admin = settings.GUPSHUP_ADMIN_RECIPIENT
        self.orig_template_id = settings.GUPSHUP_TEMPLATE_ID
        self.orig_template_name = settings.GUPSHUP_TEMPLATE_NAME

        settings.GUPSHUP_API_KEY = "test_gupshup_api_key_secret_123"
        settings.GUPSHUP_SOURCE_NUMBER = "919999900000"
        settings.GUPSHUP_ADMIN_RECIPIENT = "919876500000"
        settings.GUPSHUP_TEMPLATE_ID = "c6aecef6-bcb0-4fb1-8100-28c094e3bc6b"
        settings.GUPSHUP_TEMPLATE_NAME = "yadviapporder_confirmation"

        self.service = GupshupWhatsAppService()

    def tearDown(self):
        settings.GUPSHUP_API_KEY = self.orig_api_key
        settings.GUPSHUP_SOURCE_NUMBER = self.orig_source
        settings.GUPSHUP_ADMIN_RECIPIENT = self.orig_admin
        settings.GUPSHUP_TEMPLATE_ID = self.orig_template_id
        settings.GUPSHUP_TEMPLATE_NAME = self.orig_template_name

        self.db.close()
        Base.metadata.drop_all(bind=self.engine)

    # 1. Successful Dealer order placement triggers one WhatsApp notification
    @patch('httpx.Client.post')
    def test_1_successful_order_triggers_one_whatsapp_notification(self, mock_post):
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "status": "submitted",
            "messageId": "ee4a68a0-1203-4c85-8dc3-49d0b3226a35"
        }
        mock_post.return_value = mock_response

        payload = OrderCreateRequest(
            items=[
                OrderItemIn(product_id=1, quantity=2.0, unit="kg"),
                OrderItemIn(product_id=2, quantity=1.0, unit="kg"),
            ],
            delivery_notes="Urgent dispatch",
            source="Shop Owner App"
        )

        order_out = create_order(payload=payload, db=self.db, current_user=self.dealer_user)
        self.assertIsNotNone(order_out)
        self.assertTrue(order_out.order_number.startswith("ORD-"))

        # Check mock post was called once
        self.assertEqual(mock_post.call_count, 1)

        # Check notification record was persisted in database
        notif = self.db.query(Notification).filter(
            Notification.order_number == order_out.order_number,
            Notification.message_content.contains("yadviapporder_confirmation")
        ).first()
        self.assertIsNotNone(notif)
        self.assertEqual(notif.status, "Sent")
        self.assertEqual(notif.delivery_status, "Submitted")
        self.assertEqual(notif.meta_message_id, "ee4a68a0-1203-4c85-8dc3-49d0b3226a35")
        self.assertEqual(notif.recipient_phone, "919876500000")

    # 2. Failed order placement does not trigger a notification
    @patch('httpx.Client.post')
    def test_2_failed_order_placement_does_not_trigger_notification(self, mock_post):
        # Request quantity exceeding available stock (available: 1000 kg, requested: 5000 kg)
        payload = OrderCreateRequest(
            items=[OrderItemIn(product_id=1, quantity=5000.0, unit="kg")],
            delivery_notes="Exceeds stock",
            source="Shop Owner App"
        )

        with self.assertRaises(HTTPException):
            create_order(payload=payload, db=self.db, current_user=self.dealer_user)

        # Gupshup WhatsApp API must NOT have been called
        self.assertEqual(mock_post.call_count, 0)
        notif_count = self.db.query(Notification).count()
        self.assertEqual(notif_count, 0)

    # 3. WhatsApp API failure does not fail order placement
    @patch('httpx.Client.post')
    def test_3_whatsapp_api_failure_does_not_fail_order_placement(self, mock_post):
        # Simulate Gupshup server 500 error
        mock_response = MagicMock()
        mock_response.status_code = 500
        mock_response.json.return_value = {
            "status": "error",
            "message": "Internal Gupshup Server Error"
        }
        mock_post.return_value = mock_response

        payload = OrderCreateRequest(
            items=[OrderItemIn(product_id=1, quantity=10.0, unit="kg")],
            source="Shop Owner App"
        )

        # Order must succeed despite WhatsApp 500 failure
        order_out = create_order(payload=payload, db=self.db, current_user=self.dealer_user)
        self.assertIsNotNone(order_out)
        self.assertTrue(order_out.order_number.startswith("ORD-"))

        # Notification must be marked Failed without crashing
        notif = self.db.query(Notification).filter(
            Notification.order_number == order_out.order_number,
            Notification.message_content.contains("yadviapporder_confirmation")
        ).first()
        self.assertIsNotNone(notif)
        self.assertEqual(notif.status, "Failed")
        self.assertEqual(notif.delivery_status, "Failed")

    # 4. Correct Order ID is passed in {{1}}
    def test_4_correct_order_id_passed(self):
        order = Order(
            id=101,
            order_number="ORD-1149",
            shop_id=1,
            total_quantity_kg=5.0,
            created_at=datetime(2026, 11, 22, 10, 0, 0)
        )
        order.shop = self.shop
        items = [OrderItem(product_id=1, quantity=5.0, unit="kg")]
        items[0].product = self.product1

        params = self.service.format_template_variables(order, items)
        self.assertEqual(params[0], "ORD-1149")

    # 5. Correct Dealer name in {{2}} and Dealer mobile in {{3}}
    def test_5_correct_dealer_name_and_mobile_passed(self):
        order = Order(
            id=102,
            order_number="ORD-1150",
            shop_id=1,
            total_quantity_kg=2.0,
            created_at=datetime(2026, 11, 22, 10, 0, 0)
        )
        order.shop = self.shop
        items = [OrderItem(product_id=1, quantity=2.0, unit="kg")]
        items[0].product = self.product1

        params = self.service.format_template_variables(order, items)
        self.assertEqual(params[1], "Shree Seeds Agency")
        self.assertEqual(params[2], "9876543210")

    # 6. Product details and quantities are formatted correctly in {{5}}
    def test_6_product_details_and_quantities_formatted_correctly(self):
        order = Order(
            id=103,
            order_number="ORD-1151",
            shop_id=1,
            total_quantity_kg=3.0,
            created_at=datetime(2026, 11, 22, 10, 0, 0)
        )
        order.shop = self.shop
        item1 = OrderItem(product_id=1, quantity=2.0, unit="kg")
        item1.product = self.product1
        item2 = OrderItem(product_id=2, quantity=1.0, unit="kg")
        item2.product = self.product2
        items = [item1, item2]

        params = self.service.format_template_variables(order, items)
        # Expected: "Maize Hybrid – 2 kg, Cotton Gold – 1 kg"
        self.assertEqual(params[4], "Maize Hybrid – 2 kg, Cotton Gold – 1 kg")

    # 7. Total quantity and variety count are correct in {{6}}
    def test_7_total_quantity_and_variety_count(self):
        # Case A: Multiple varieties
        order_multi = Order(
            id=104,
            order_number="ORD-1152",
            shop_id=1,
            total_quantity_kg=3.0,
            created_at=datetime(2026, 11, 22, 10, 0, 0)
        )
        order_multi.shop = self.shop
        item1 = OrderItem(product_id=1, quantity=2.0, unit="kg")
        item1.product = self.product1
        item2 = OrderItem(product_id=2, quantity=1.0, unit="kg")
        item2.product = self.product2

        params_multi = self.service.format_template_variables(order_multi, [item1, item2])
        self.assertEqual(params_multi[5], "3 kg (2 varieties)")

        # Case B: Single variety
        order_single = Order(
            id=105,
            order_number="ORD-1153",
            shop_id=1,
            total_quantity_kg=5.0,
            created_at=datetime(2026, 11, 22, 10, 0, 0)
        )
        order_single.shop = self.shop
        params_single = self.service.format_template_variables(order_single, [item1])
        self.assertEqual(params_single[5], "5 kg (1 variety)")

        # Case C: Date formatting in {{4}}
        self.assertEqual(params_multi[3], "22 November 2026")

    # 8. Duplicate order requests do not cause duplicate notifications
    @patch('httpx.Client.post')
    def test_8_duplicate_order_requests_do_not_cause_duplicate_notifications(self, mock_post):
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "status": "submitted",
            "messageId": "msg-first-1234"
        }
        mock_post.return_value = mock_response

        # Seed pre-existing sent notification for ORD-2000
        existing_notif = Notification(
            recipient_phone="919876500000",
            channel="WhatsApp",
            order_number="ORD-2000",
            shop_name="Shree Seeds Agency",
            status="Sent",
            delivery_status="Submitted",
            meta_message_id="msg-first-1234",
            message_content="Template: yadviapporder_confirmation"
        )
        self.db.add(existing_notif)
        self.db.commit()

        # Place order with order_number manually set or pre-existing
        order = Order(
            id=200,
            order_number="ORD-2000",
            shop_id=1,
            total_quantity_kg=2.0,
            total_items_count=1,
            status="New"
        )
        order.shop = self.shop
        self.db.add(order)
        self.db.commit()

        # Simulate second trigger for same order
        from app.services.whatsapp_service import gupshup_whatsapp_service
        existing_sent = self.db.query(Notification).filter(
            Notification.order_number == order.order_number,
            Notification.channel == "WhatsApp",
            Notification.status.in_(["Sent", "Delivered", "Read", "Submitted"])
        ).first()

        self.assertIsNotNone(existing_sent)
        # Verify mock_post was NOT called because notification already exists
        self.assertEqual(mock_post.call_count, 0)

    # 9. Invalid or failed Gupshup responses are handled safely
    @patch('httpx.Client.post')
    def test_9_invalid_or_failed_gupshup_responses_handled_safely(self, mock_post):
        # Gupshup returns 400 with 4003 error code (No template match)
        mock_response = MagicMock()
        mock_response.status_code = 400
        mock_response.json.return_value = {
            "status": "error",
            "code": 4003,
            "message": "No Template Match"
        }
        mock_post.return_value = mock_response

        order = Order(
            id=106,
            order_number="ORD-1154",
            shop_id=1,
            total_quantity_kg=2.0,
            created_at=datetime.utcnow()
        )
        order.shop = self.shop
        items = [OrderItem(product_id=1, quantity=2.0, unit="kg")]

        res = self.service.send_order_notification(order, items)
        self.assertFalse(res["success"])
        self.assertEqual(res["status"], "rejected")
        self.assertEqual(res["error_code"], 4003)
        self.assertIn("No Template Match", res["message"])

    # 9B. Test Gupshup template status check method
    @patch('httpx.Client.get')
    def test_9b_check_template_status_method(self, mock_get):
        self.service.app_id = "test-app-id-1234"
        mock_res = MagicMock()
        mock_res.status_code = 200
        mock_res.json.return_value = {
            "templates": [
                {
                    "elementName": "yadviapporder_confirmation",
                    "status": "PENDING",
                    "id": "c6aecef6-bcb0-4fb1-8100-28c094e3bc6b",
                    "category": "UTILITY",
                    "languageCode": "en_US"
                }
            ]
        }
        mock_get.return_value = mock_res

        status_res = self.service.check_template_status()
        self.assertTrue(status_res["success"])
        self.assertEqual(status_res["status"], "PENDING")
        self.assertEqual(status_res["template_name"], "yadviapporder_confirmation")

    # 10. Webhook delivery statuses are processed correctly with monotonic progression
    def test_10_webhook_delivery_statuses_processed_correctly(self):
        # Create a submitted notification
        notif = Notification(
            recipient_phone="919876500000",
            channel="WhatsApp",
            order_number="ORD-3001",
            shop_name="Shree Seeds",
            status="Sent",
            delivery_status="Submitted",
            meta_message_id="gs-msg-uuid-9999",
            message_content="Test message"
        )
        self.db.add(notif)
        self.db.commit()

        # A. Transition Submitted -> Sent
        sent_event = {
            "type": "message-event",
            "payload": {
                "id": "wamid.HBgMOTE...",
                "gsId": "gs-msg-uuid-9999",
                "type": "sent",
                "destination": "919876500000"
            }
        }
        res_sent = GupshupWhatsAppService.process_webhook_event(sent_event, self.db)
        self.assertEqual(res_sent["status"], "updated")
        self.assertEqual(res_sent["new_status"], "Sent")

        self.db.refresh(notif)
        self.assertEqual(notif.delivery_status, "Sent")

        # B. Transition Sent -> Delivered
        deliv_event = {
            "type": "message-event",
            "payload": {
                "id": "wamid.HBgMOTE...",
                "gsId": "gs-msg-uuid-9999",
                "type": "delivered",
                "destination": "919876500000"
            }
        }
        res_deliv = GupshupWhatsAppService.process_webhook_event(deliv_event, self.db)
        self.assertEqual(res_deliv["status"], "updated")
        self.assertEqual(res_deliv["new_status"], "Delivered")

        self.db.refresh(notif)
        self.assertEqual(notif.delivery_status, "Delivered")
        self.assertIsNotNone(notif.delivered_at)

        # C. Monotonic check: Delayed 'sent' event must NOT downgrade 'Delivered'
        res_late_sent = GupshupWhatsAppService.process_webhook_event(sent_event, self.db)
        self.assertEqual(res_late_sent["status"], "skipped_lower_rank")
        self.db.refresh(notif)
        self.assertEqual(notif.delivery_status, "Delivered")

        # D. Transition Delivered -> Read
        read_event = {
            "type": "message-event",
            "payload": {
                "id": "wamid.HBgMOTE...",
                "gsId": "gs-msg-uuid-9999",
                "type": "read",
                "destination": "919876500000"
            }
        }
        res_read = GupshupWhatsAppService.process_webhook_event(read_event, self.db)
        self.assertEqual(res_read["status"], "updated")
        self.assertEqual(res_read["new_status"], "Read")

        self.db.refresh(notif)
        self.assertEqual(notif.delivery_status, "Read")
        self.assertIsNotNone(notif.read_at)

        # E. Failure handling for a new notification
        fail_notif = Notification(
            recipient_phone="919876500000",
            channel="WhatsApp",
            order_number="ORD-3002",
            status="Sent",
            delivery_status="Submitted",
            meta_message_id="gs-fail-msg-1234",
            message_content="Fail test"
        )
        self.db.add(fail_notif)
        self.db.commit()

        fail_event = {
            "type": "message-event",
            "payload": {
                "id": "gs-fail-msg-1234",
                "type": "failed",
                "destination": "919876500000",
                "payload": {
                    "code": 1002,
                    "reason": "Number Not Exist On WhatsApp"
                }
            }
        }
        res_fail = GupshupWhatsAppService.process_webhook_event(fail_event, self.db)
        self.assertEqual(res_fail["status"], "updated")
        self.assertEqual(res_fail["new_status"], "Failed")

        self.db.refresh(fail_notif)
        self.assertEqual(fail_notif.delivery_status, "Failed")
        self.assertEqual(fail_notif.status, "Failed")
        self.assertEqual(fail_notif.meta_error_code, "1002")
        self.assertIn("Number Not Exist", fail_notif.meta_error_message)

    # 11. Missing credentials are handled safely
    def test_11_missing_credentials_handled_safely(self):
        unconfigured_service = GupshupWhatsAppService()
        unconfigured_service.api_key = None
        unconfigured_service.source_number = None

        self.assertFalse(unconfigured_service.is_configured())

        order = Order(id=107, order_number="ORD-1155", shop_id=1)
        res = unconfigured_service.send_order_notification(order, [])
        self.assertFalse(res["success"])
        self.assertEqual(res["status"], "unconfigured")
        self.assertIn("not configured", res["message"])

    # 12. Sensitive credentials and phone numbers are never exposed in logs or return dicts
    def test_12_sensitive_credentials_never_exposed(self):
        secret_key = "very_secret_api_key_xyz_999"
        phone = "+91 98765 43210"

        masked = mask_phone_number(phone)
        self.assertNotIn("9876543210", masked)
        self.assertTrue(masked.startswith("91"))
        self.assertTrue(masked.endswith("3210"))
        self.assertIn("******", masked)

        # Ensure API key is never in sanitized phone
        sanitized = sanitize_phone_number(phone)
        self.assertEqual(sanitized, "919876543210")

        # Ensure service representation never prints raw key
        order = Order(id=108, order_number="ORD-1156", shop_id=1)
        order.shop = self.shop
        items = [OrderItem(product_id=1, quantity=1.0, unit="kg")]

        with patch('httpx.Client.post') as mock_post:
            mock_res = MagicMock()
            mock_res.status_code = 200
            mock_res.json.return_value = {"status": "submitted", "messageId": "test-id"}
            mock_post.return_value = mock_res

            res = self.service.send_order_notification(order, items)
            # The returned dict must NOT contain the secret API key
            res_str = json.dumps(str(res))
            self.assertNotIn(secret_key, res_str)


if __name__ == '__main__':
    unittest.main()
