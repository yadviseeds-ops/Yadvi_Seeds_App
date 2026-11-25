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
from app.models.all_models import User, Role, ShopOwner, Product, Order, OrderItem, Notification, WhatsAppOutbox
from app.services.whatsapp_service import (
    GupshupWhatsAppService,
    mask_phone_number,
    sanitize_phone_number,
)
from app.api.orders import create_order, OrderCreateRequest, OrderItemIn
from app.api.notifications import process_gupshup_outbox


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
        self.orig_app_name = settings.GUPSHUP_APP_NAME
        self.orig_app_id = settings.GUPSHUP_APP_ID
        self.orig_template_id = settings.GUPSHUP_TEMPLATE_ID
        self.orig_template_name = settings.GUPSHUP_TEMPLATE_NAME
        self.orig_dispatch_enabled = settings.GUPSHUP_DISPATCH_ENABLED

        settings.GUPSHUP_API_KEY = "test_gupshup_api_key_secret_123"
        settings.GUPSHUP_SOURCE_NUMBER = "919999900000"
        settings.GUPSHUP_ADMIN_RECIPIENT = "919876500000"
        settings.GUPSHUP_APP_NAME = "YadviHybridSeeds"
        settings.GUPSHUP_APP_ID = "bfa14c34-fc9d-4f5b-bfce-73fc89434929"
        settings.GUPSHUP_TEMPLATE_ID = "c6aecef6-bcb0-4fb1-8100-28c094e3bc6b"
        settings.GUPSHUP_TEMPLATE_NAME = "yadviapporder_confirmation"
        settings.GUPSHUP_DISPATCH_ENABLED = True

        self.service = GupshupWhatsAppService()

    def tearDown(self):
        settings.GUPSHUP_API_KEY = self.orig_api_key
        settings.GUPSHUP_SOURCE_NUMBER = self.orig_source
        settings.GUPSHUP_ADMIN_RECIPIENT = self.orig_admin
        settings.GUPSHUP_APP_NAME = self.orig_app_name
        settings.GUPSHUP_APP_ID = self.orig_app_id
        settings.GUPSHUP_TEMPLATE_ID = self.orig_template_id
        settings.GUPSHUP_TEMPLATE_NAME = self.orig_template_name
        settings.GUPSHUP_DISPATCH_ENABLED = self.orig_dispatch_enabled

        self.db.close()
        Base.metadata.drop_all(bind=self.engine)

    # 1. Non-blocking order creation: creates durable outbox without synchronous HTTP calls
    @patch('httpx.Client.post')
    def test_1_order_creation_is_non_blocking_and_creates_durable_outbox(self, mock_post):
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

        # Synchronous HTTP calls must NOT occur during order placement (0 network delay for Dealer)
        self.assertEqual(mock_post.call_count, 0)

        # Durable WhatsAppOutbox record must exist in the database with status Pending
        outbox = self.db.query(WhatsAppOutbox).filter(WhatsAppOutbox.order_number == order_out.order_number).first()
        self.assertIsNotNone(outbox)
        self.assertEqual(outbox.status, "Pending")
        self.assertEqual(outbox.retry_count, 0)
        self.assertEqual(outbox.template_id, "c6aecef6-bcb0-4fb1-8100-28c094e3bc6b")
        self.assertIn("919876500000", outbox.recipient_phone)

        # Verify serialized payload contains template params
        payload_data = json.loads(outbox.payload_json)
        self.assertEqual(payload_data["order_number"], order_out.order_number)
        self.assertEqual(len(payload_data["params"]), 6)
        self.assertEqual(payload_data["params"][0], order_out.order_number)

    # 2. Worker processes outbox queue successfully
    @patch('httpx.Client.post')
    def test_2_worker_processes_outbox_queue_successfully(self, mock_post):
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "status": "submitted",
            "messageId": "ee4a68a0-1203-4c85-8dc3-49d0b3226a35"
        }
        mock_post.return_value = mock_response

        payload = OrderCreateRequest(
            items=[OrderItemIn(product_id=1, quantity=2.0, unit="kg")],
            source="Shop Owner App"
        )
        order_out = create_order(payload=payload, db=self.db, current_user=self.dealer_user)

        # Run outbox worker
        summary = self.service.process_outbox_queue(self.db)
        self.assertEqual(summary["total_candidates"], 1)
        self.assertEqual(summary["dispatched"], 1)
        self.assertEqual(summary["failed"], 0)

        # Gupshup API POST must have been called exactly once
        self.assertEqual(mock_post.call_count, 1)

        # Verify outbox state transitioned to Dispatched
        outbox = self.db.query(WhatsAppOutbox).filter(WhatsAppOutbox.order_number == order_out.order_number).first()
        self.assertEqual(outbox.status, "Dispatched")
        self.assertIsNone(outbox.last_error)

        # Verify Notification record created with messageId
        notif = self.db.query(Notification).filter(
            Notification.order_number == order_out.order_number,
            Notification.message_content.contains("yadviapporder_confirmation")
        ).first()
        self.assertIsNotNone(notif)
        self.assertEqual(notif.status, "Sent")
        self.assertEqual(notif.delivery_status, "Submitted")
        self.assertEqual(notif.meta_message_id, "ee4a68a0-1203-4c85-8dc3-49d0b3226a35")

    # 3. Failed order placement does not create outbox or send notification
    @patch('httpx.Client.post')
    def test_3_failed_order_placement_does_not_create_outbox_or_send(self, mock_post):
        # Exceeds available stock
        payload = OrderCreateRequest(
            items=[OrderItemIn(product_id=1, quantity=5000.0, unit="kg")],
            source="Shop Owner App"
        )

        with self.assertRaises(HTTPException):
            create_order(payload=payload, db=self.db, current_user=self.dealer_user)

        self.assertEqual(mock_post.call_count, 0)
        self.assertEqual(self.db.query(WhatsAppOutbox).count(), 0)
        self.assertEqual(self.db.query(Notification).count(), 0)

    # 4. Worker bounded retry with exponential backoff on Gupshup failure
    @patch('httpx.Client.post')
    def test_4_worker_bounded_retry_and_exponential_backoff(self, mock_post):
        mock_response = MagicMock()
        mock_response.status_code = 500
        mock_response.json.return_value = {
            "status": "error",
            "message": "Internal Gupshup Server Error"
        }
        mock_post.return_value = mock_response

        payload = OrderCreateRequest(
            items=[OrderItemIn(product_id=1, quantity=5.0, unit="kg")],
            source="Shop Owner App"
        )
        order_out = create_order(payload=payload, db=self.db, current_user=self.dealer_user)
        outbox = self.db.query(WhatsAppOutbox).filter(WhatsAppOutbox.order_number == order_out.order_number).first()

        # Attempt 1
        summary1 = self.service.process_outbox_queue(self.db)
        self.assertEqual(summary1["retried"], 1)
        self.db.refresh(outbox)
        self.assertEqual(outbox.status, "Retry")
        self.assertEqual(outbox.retry_count, 1)
        self.assertIn("Internal Gupshup Server Error", outbox.last_error)
        self.assertTrue(outbox.next_retry_at > datetime.utcnow() - timedelta(seconds=1))

        # Advance next_retry_at to simulate backoff elapse
        outbox.next_retry_at = datetime.utcnow() - timedelta(seconds=1)
        self.db.commit()

        # Attempt 2
        summary2 = self.service.process_outbox_queue(self.db)
        self.assertEqual(summary2["retried"], 1)
        self.db.refresh(outbox)
        self.assertEqual(outbox.status, "Retry")
        self.assertEqual(outbox.retry_count, 2)

        # Advance next_retry_at again
        outbox.next_retry_at = datetime.utcnow() - timedelta(seconds=1)
        self.db.commit()

        # Attempt 3 (Max retries reached -> terminal Failed)
        summary3 = self.service.process_outbox_queue(self.db)
        self.assertEqual(summary3["failed"], 1)
        self.db.refresh(outbox)
        self.assertEqual(outbox.status, "Failed")
        self.assertEqual(outbox.retry_count, 3)

        # Check terminal failure logged in Notification table
        notif = self.db.query(Notification).filter(
            Notification.order_number == order_out.order_number,
            Notification.message_content.contains("yadviapporder_confirmation")
        ).first()
        self.assertIsNotNone(notif)
        self.assertEqual(notif.status, "Failed")
        self.assertEqual(notif.delivery_status, "Failed")

        # Attempt 4 (No further retries)
        summary4 = self.service.process_outbox_queue(self.db)
        self.assertEqual(summary4["total_candidates"], 0)

    # 5. Worker idempotency prevents duplicate dispatch
    @patch('httpx.Client.post')
    def test_5_worker_idempotency_prevents_duplicate_dispatch(self, mock_post):
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "status": "submitted",
            "messageId": "msg-id-12345"
        }
        mock_post.return_value = mock_response

        # Seed pre-existing dispatched notification
        notif = Notification(
            recipient_phone="919876500000",
            channel="WhatsApp",
            order_number="ORD-DUP-01",
            shop_name="Shree Seeds",
            status="Sent",
            delivery_status="Submitted",
            meta_message_id="msg-id-12345",
            message_content="Template: yadviapporder_confirmation | Pre-existing dispatched notification"
        )
        self.db.add(notif)

        # Seed outbox for same order
        outbox = WhatsAppOutbox(
            order_id=999,
            order_number="ORD-DUP-01",
            recipient_phone="919876500000",
            template_id="c6aecef6-bcb0-4fb1-8100-28c094e3bc6b",
            template_name="yadviapporder_confirmation",
            payload_json=json.dumps({"params": ["ORD-DUP-01", "Shree", "9876543210", "date", "items", "qty"]}),
            status="Pending",
            retry_count=0
        )
        self.db.add(outbox)
        self.db.commit()

        # Run worker: should skip because Notification already exists
        summary = self.service.process_outbox_queue(self.db)
        self.assertEqual(summary["skipped_duplicate"], 1)
        self.assertEqual(summary["dispatched"], 0)
        self.assertEqual(mock_post.call_count, 0)

        self.db.refresh(outbox)
        self.assertEqual(outbox.status, "Dispatched")

    # 6. Worker recovers crashed stale processing locks
    @patch('httpx.Client.post')
    def test_6_worker_recovers_crashed_stale_processing_locks(self, mock_post):
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "status": "submitted",
            "messageId": "msg-recovered-99"
        }
        mock_post.return_value = mock_response

        # Seed an outbox entry stuck in Processing with stale lock (>5 minutes ago)
        crashed_time = datetime.utcnow() - timedelta(minutes=15)
        outbox = WhatsAppOutbox(
            order_id=888,
            order_number="ORD-CRASH-01",
            recipient_phone="919876500000",
            template_id="c6aecef6-bcb0-4fb1-8100-28c094e3bc6b",
            template_name="yadviapporder_confirmation",
            payload_json=json.dumps({"order_number": "ORD-CRASH-01", "params": ["ORD-CRASH-01", "Shop", "987", "d", "p", "q"]}),
            status="Processing",
            locked_at=crashed_time,
            retry_count=0
        )
        self.db.add(outbox)
        self.db.commit()

        # Worker should recover stale lock and process it
        summary = self.service.process_outbox_queue(self.db)
        self.assertEqual(summary["total_candidates"], 1)
        self.assertEqual(summary["dispatched"], 1)
        self.assertEqual(mock_post.call_count, 1)

        self.db.refresh(outbox)
        self.assertEqual(outbox.status, "Dispatched")

    # 7. Strict config: missing app_name fails safely without dispatching
    @patch('httpx.Client.post')
    def test_7_strict_config_missing_app_name(self, mock_post):
        self.service.app_name = None
        self.assertFalse(self.service.is_configured())

        order = Order(id=107, order_number="ORD-NO-APP", shop_id=1)
        res = self.service.send_order_notification(order, [])
        self.assertFalse(res["success"])
        self.assertEqual(res["status"], "unconfigured")
        self.assertIn("GUPSHUP_APP_NAME", res["message"])
        self.assertIn("src.name", res["message"])
        self.assertEqual(mock_post.call_count, 0)

    # 8. Strict config: missing template UUID fails safely and never uses template name
    @patch('httpx.Client.post')
    def test_8_strict_config_missing_template_uuid(self, mock_post):
        self.service.template_id = None
        self.assertFalse(self.service.is_configured())

        order = Order(id=108, order_number="ORD-NO-TPL", shop_id=1)
        res = self.service.send_order_notification(order, [])
        self.assertFalse(res["success"])
        self.assertEqual(res["status"], "unconfigured")
        self.assertIn("GUPSHUP_TEMPLATE_ID", res["message"])
        self.assertIn("approved template UUID", res["message"])
        self.assertEqual(mock_post.call_count, 0)

    # 9. src.name and approved template UUID are always present in the form payload
    @patch('httpx.Client.post')
    def test_9_src_name_and_template_uuid_in_form_payload(self, mock_post):
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "status": "submitted",
            "messageId": "msg-payload-check-1"
        }
        mock_post.return_value = mock_response

        order = Order(
            id=109,
            order_number="ORD-1157",
            shop_id=1,
            total_quantity_kg=2.0,
            created_at=datetime.utcnow()
        )
        order.shop = self.shop
        items = [OrderItem(product_id=1, quantity=2.0, unit="kg")]
        items[0].product = self.product1

        res = self.service.send_order_notification(order, items)
        self.assertTrue(res["success"])
        self.assertEqual(mock_post.call_count, 1)

        # Inspect call arguments
        call_kwargs = mock_post.call_args[1]
        data_sent = call_kwargs["data"]

        # src.name must be sent
        self.assertEqual(data_sent.get("src.name"), "YadviHybridSeeds")
        self.assertEqual(data_sent.get("channel"), "whatsapp")
        self.assertEqual(data_sent.get("source"), "919999900000")
        self.assertEqual(data_sent.get("destination"), "919876500000")

        # template must contain the approved template UUID, NOT the template name
        tpl_parsed = json.loads(data_sent.get("template"))
        self.assertEqual(tpl_parsed["id"], "c6aecef6-bcb0-4fb1-8100-28c094e3bc6b")
        self.assertNotEqual(tpl_parsed["id"], "yadviapporder_confirmation")
        self.assertEqual(len(tpl_parsed["params"]), 6)

    # 10. Webhook delivery monotonic transitions and duplicate event idempotency
    def test_10_webhook_delivery_monotonic_and_duplicate_idempotency(self):
        notif = Notification(
            recipient_phone="919876500000",
            channel="WhatsApp",
            order_number="ORD-W-01",
            status="Sent",
            delivery_status="Submitted",
            meta_message_id="gs-test-w-99",
            message_content="Test message"
        )
        self.db.add(notif)
        self.db.commit()

        # Step 1: Transition Submitted -> Sent
        event_sent = {
            "type": "message-event",
            "payload": {
                "id": "wamid.123",
                "gsId": "gs-test-w-99",
                "type": "sent"
            }
        }
        res1 = GupshupWhatsAppService.process_webhook_event(event_sent, self.db)
        self.assertEqual(res1["status"], "updated")
        self.assertEqual(res1["new_status"], "Sent")

        # Step 2: Duplicate Sent event handled idempotently
        res1_dup = GupshupWhatsAppService.process_webhook_event(event_sent, self.db)
        self.assertEqual(res1_dup["status"], "duplicate")

        # Step 3: Transition Sent -> Delivered
        event_deliv = {
            "type": "message-event",
            "payload": {
                "id": "wamid.123",
                "gsId": "gs-test-w-99",
                "type": "delivered"
            }
        }
        res2 = GupshupWhatsAppService.process_webhook_event(event_deliv, self.db)
        self.assertEqual(res2["status"], "updated")
        self.assertEqual(res2["new_status"], "Delivered")
        self.db.refresh(notif)
        self.assertIsNotNone(notif.delivered_at)

        # Step 4: Out-of-order 'sent' event does not downgrade 'Delivered'
        res_late_sent = GupshupWhatsAppService.process_webhook_event(event_sent, self.db)
        self.assertEqual(res_late_sent["status"], "skipped_lower_rank")
        self.db.refresh(notif)
        self.assertEqual(notif.delivery_status, "Delivered")

        # Step 5: Transition Delivered -> Read
        event_read = {
            "type": "message-event",
            "payload": {
                "id": "wamid.123",
                "gsId": "gs-test-w-99",
                "type": "read"
            }
        }
        res3 = GupshupWhatsAppService.process_webhook_event(event_read, self.db)
        self.assertEqual(res3["status"], "updated")
        self.assertEqual(res3["new_status"], "Read")
        self.db.refresh(notif)
        self.assertIsNotNone(notif.read_at)

        # Step 6: Delayed failure event does NOT overwrite confirmed Read
        event_late_fail = {
            "type": "message-event",
            "payload": {
                "id": "gs-test-w-99",
                "type": "failed"
            }
        }
        res_late_fail = GupshupWhatsAppService.process_webhook_event(event_late_fail, self.db)
        self.assertEqual(res_late_fail["status"], "ignored_already_delivered")
        self.db.refresh(notif)
        self.assertEqual(notif.delivery_status, "Read")

    # 11. Template formatting correctly populates all 6 variables
    def test_11_template_formatting_all_variables(self):
        order = Order(
            id=201,
            order_number="ORD-2026-X",
            shop_id=1,
            total_quantity_kg=4.5,
            created_at=datetime(2026, 11, 23, 14, 30, 0)
        )
        order.shop = self.shop
        item1 = OrderItem(product_id=1, quantity=3.0, unit="kg")
        item1.product = self.product1
        item2 = OrderItem(product_id=2, quantity=1.5, unit="kg")
        item2.product = self.product2

        params = self.service.format_template_variables(order, [item1, item2])
        self.assertEqual(params[0], "ORD-2026-X")
        self.assertEqual(params[1], "Shree Seeds Agency")
        self.assertEqual(params[2], "9876543210")
        self.assertEqual(params[3], "23 November 2026")
        self.assertEqual(params[4], "Maize Hybrid – 3 kg, Cotton Gold – 1.5 kg")
        self.assertEqual(params[5], "4.5 kg (2 varieties)")

    # 12. Sensitive credentials and phone numbers are never exposed
    def test_12_sensitive_credentials_never_exposed(self):
        phone = "+91 98765 43210"
        masked = mask_phone_number(phone)
        self.assertNotIn("9876543210", masked)
        self.assertTrue(masked.startswith("91"))
        self.assertTrue(masked.endswith("3210"))

        sanitized = sanitize_phone_number(phone)
        self.assertEqual(sanitized, "919876543210")

        order = Order(id=110, order_number="ORD-SAFE", shop_id=1)
        order.shop = self.shop
        items = [OrderItem(product_id=1, quantity=1.0, unit="kg")]

        with patch('httpx.Client.post') as mock_post:
            mock_res = MagicMock()
            mock_res.status_code = 200
            mock_res.json.return_value = {"status": "submitted", "messageId": "safe-id"}
            mock_post.return_value = mock_res

            res = self.service.send_order_notification(order, items)
            res_str = json.dumps(str(res))
            self.assertNotIn("test_gupshup_api_key_secret_123", res_str)

    # 13. Atomic worker claiming prevents concurrent workers from claiming the same record
    def test_13_atomic_claiming_two_concurrent_workers(self):
        """
        Tests multi-worker concurrency protection:
        Worker 1 claims the pending record inside a short transaction and commits 'Processing'.
        Worker 2, executing concurrently, must skip the record.

        Note on Test Environment Limitations:
        - In production MySQL 8.0, row-level locking via `SELECT ... FOR UPDATE SKIP LOCKED`
          instantly skips locked rows at the storage engine level.
        - In this SQLite in-memory test environment, SQLite does not support `SKIP LOCKED`,
          so atomic Compare-And-Swap (CAS) update `UPDATE ... WHERE id = :id AND status = :cand_status`
          reliably enforces that only one worker can claim the row.
        """
        # Create a pending outbox record
        outbox = WhatsAppOutbox(
            order_id=501,
            order_number="ORD-CONCUR-01",
            recipient_phone="919876500000",
            template_id="c6aecef6-bcb0-4fb1-8100-28c094e3bc6b",
            template_name="yadviapporder_confirmation",
            payload_json=json.dumps({"order_number": "ORD-CONCUR-01", "params": ["ORD-CONCUR-01", "Shop", "987", "d", "p", "q"]}),
            status="Pending",
            retry_count=0,
            next_retry_at=datetime.utcnow() - timedelta(seconds=1)
        )
        self.db.add(outbox)
        self.db.commit()

        # Session 1: Worker 1 claims the record
        session1 = self.Session()
        claimed1 = self.service._claim_pending_records(session1, max_batch=10)
        self.assertEqual(len(claimed1), 1)
        self.assertEqual(claimed1[0], outbox.id)

        # Session 2: Worker 2 attempts to claim concurrently
        session2 = self.Session()
        claimed2 = self.service._claim_pending_records(session2, max_batch=10)
        # Worker 2 must find 0 claimable records because Worker 1 already claimed it
        self.assertEqual(len(claimed2), 0)

        # Verify record in DB is in Processing state with fresh locked_at
        self.db.refresh(outbox)
        self.assertEqual(outbox.status, "Processing")
        self.assertIsNotNone(outbox.locked_at)

        session1.close()
        session2.close()

    # 14. Manual Admin processing uses the same atomic claiming mechanism
    @patch('httpx.Client.post')
    def test_14_admin_process_outbox_uses_same_claim_mechanism(self, mock_post):
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "status": "submitted",
            "messageId": "admin-triggered-msg-01"
        }
        mock_post.return_value = mock_response

        # Non-admin user attempting to call process-outbox must be rejected
        with self.assertRaises(HTTPException) as cm:
            process_gupshup_outbox(max_batch=10, db=self.db, current_user=self.dealer_user)
        self.assertEqual(cm.exception.status_code, 403)

        # Seed a pending record
        outbox = WhatsAppOutbox(
            order_id=502,
            order_number="ORD-ADMIN-01",
            recipient_phone="919876500000",
            template_id="c6aecef6-bcb0-4fb1-8100-28c094e3bc6b",
            template_name="yadviapporder_confirmation",
            payload_json=json.dumps({"order_number": "ORD-ADMIN-01", "params": ["ORD-ADMIN-01", "Shop", "987", "d", "p", "q"]}),
            status="Pending",
            retry_count=0
        )
        self.db.add(outbox)
        self.db.commit()

        # Admin call to process-outbox endpoint
        res = process_gupshup_outbox(max_batch=10, db=self.db, current_user=self.admin_user)
        self.assertTrue(res["success"])
        self.assertEqual(res["summary"]["dispatched"], 1)

        self.db.refresh(outbox)
        self.assertEqual(outbox.status, "Dispatched")

    # 15. Migration schema matches the SQLAlchemy model
    def test_15_migration_schema_matches_sqlalchemy_model(self):
        migration_path = os.path.join(
            os.path.dirname(os.path.dirname(__file__)),
            "migrations",
            "20261123_create_whatsapp_outbox_table.sql"
        )
        self.assertTrue(os.path.exists(migration_path), f"Migration file missing at {migration_path}")

        with open(migration_path, "r", encoding="utf-8") as f:
            sql_content = f.read()

        # Verify all columns in SQLAlchemy model are present in SQL migration DDL
        model_columns = [
            "id", "order_id", "order_number", "recipient_phone",
            "template_id", "template_name", "payload_json", "status",
            "retry_count", "max_retries", "next_retry_at", "locked_at",
            "last_error", "created_at", "updated_at"
        ]
        for col in model_columns:
            self.assertIn(col, sql_content, f"Column '{col}' missing in SQL migration")

        # Verify foreign key constraint and unique order_id constraint
        self.assertIn("orders (id)", sql_content)
        self.assertIn("uq_whatsapp_outbox_order_id", sql_content)
        self.assertIn("UNIQUE (order_id)", sql_content)
        self.assertIn("ENGINE=InnoDB", sql_content)

        # Inspect actual SQLAlchemy Table metadata
        table = WhatsAppOutbox.__table__
        for col in model_columns:
            self.assertIn(col, table.c, f"Column '{col}' missing in SQLAlchemy Table metadata")

        # Verify foreign key metadata
        fk = list(table.c.order_id.foreign_keys)[0]
        self.assertEqual(fk.target_fullname, "orders.id")
        self.assertEqual(fk.ondelete, "CASCADE")
        self.assertEqual(fk.onupdate, "CASCADE")

        # Verify composite indexes
        index_names = {idx.name for idx in table.indexes}
        self.assertIn("idx_whatsapp_outbox_worker_schedule", index_names)
        self.assertIn("idx_whatsapp_outbox_stale_lock", index_names)

    # 16. Two competing workers attempting to reclaim the same stale Processing record
    def test_16_atomic_claiming_stale_record_concurrency(self):
        """
        Tests multi-worker concurrency when recovering stale 'Processing' records:
        A record was claimed previously by Worker A which crashed 10 minutes ago (locked_at <= stale_threshold).
        Worker 1 and Worker 2 concurrently run _claim_pending_records.
        The CAS condition (WhatsAppOutbox.locked_at == cand_locked_at) guarantees that only
        ONE worker can successfully update and claim the record.
        """
        stale_time = datetime.utcnow() - timedelta(minutes=10)
        outbox = WhatsAppOutbox(
            order_id=505,
            order_number="ORD-STALE-CONCUR",
            recipient_phone="919876500000",
            template_id="c6aecef6-bcb0-4fb1-8100-28c094e3bc6b",
            template_name="yadviapporder_confirmation",
            payload_json=json.dumps({"order_number": "ORD-STALE-CONCUR", "params": ["ORD-STALE-CONCUR", "Shop", "987", "d", "p", "q"]}),
            status="Processing",
            locked_at=stale_time,
            retry_count=1,
            next_retry_at=datetime.utcnow() - timedelta(minutes=15)
        )
        self.db.add(outbox)
        self.db.commit()

        # Worker 1 claims the stale record
        session1 = self.Session()
        claimed1 = self.service._claim_pending_records(session1, max_batch=10)
        self.assertEqual(len(claimed1), 1)
        self.assertEqual(claimed1[0], outbox.id)

        # Worker 2 attempts to claim concurrently
        session2 = self.Session()
        claimed2 = self.service._claim_pending_records(session2, max_batch=10)
        self.assertEqual(len(claimed2), 0)

        # Verify outbox has a refreshed locked_at > stale_time
        self.db.refresh(outbox)
        self.assertEqual(outbox.status, "Processing")
        self.assertGreater(outbox.locked_at, stale_time)

        session1.close()
        session2.close()

    # 17. Gupshup webhook probe events (connectivity-check, platform-event)
    def test_17_webhook_connectivity_and_platform_probe_events(self):
        # Gupshup connectivity-check probe
        event_conn = {"type": "connectivity-check"}
        res_conn = GupshupWhatsAppService.process_webhook_event(event_conn, self.db)
        self.assertEqual(res_conn["status"], "acknowledged")
        self.assertEqual(res_conn["event_type"], "connectivity-check")

        # Gupshup platform-event
        event_plat = {"type": "platform-event", "payload": {"code": "100", "info": "ping"}}
        res_plat = GupshupWhatsAppService.process_webhook_event(event_plat, self.db)
        self.assertEqual(res_plat["status"], "acknowledged")
        self.assertEqual(res_plat["event_type"], "platform-event")

        # Gupshup health-check
        event_health = {"type": "health-check"}
        res_health = GupshupWhatsAppService.process_webhook_event(event_health, self.db)
        self.assertEqual(res_health["status"], "acknowledged")
        self.assertEqual(res_health["event_type"], "health-check")

    # 18. Gupshup webhook unknown status and message ID mapping (gsId vs id)
    def test_18_webhook_unknown_status_and_id_mapping(self):
        # Create a notification with meta_message_id = 'gs-wamid-mapping-999'
        notif = Notification(
            recipient_phone="919876500000",
            channel="WhatsApp",
            order_number="ORD-MAP-01",
            status="Sent",
            meta_message_id="gs-wamid-mapping-999",
            delivery_status="Sent",
            message_content="Template: yadviapporder_confirmation",
        )
        self.db.add(notif)
        self.db.commit()

        # Unknown status type acknowledged cleanly without corrupting notification status
        event_unknown = {
            "type": "message-event",
            "payload": {
                "gsId": "gs-wamid-mapping-999",
                "type": "custom_provider_ack",
            }
        }
        res_unk = GupshupWhatsAppService.process_webhook_event(event_unknown, self.db)
        self.assertEqual(res_unk["status"], "acknowledged")
        self.assertIn("unknown_status_type", res_unk["reason"])

        self.db.refresh(notif)
        self.assertEqual(notif.delivery_status, "Sent")

        # Event using payload.id instead of payload.gsId
        event_by_id = {
            "type": "message-event",
            "payload": {
                "id": "gs-wamid-mapping-999",
                "type": "delivered",
            }
        }
        res_id = GupshupWhatsAppService.process_webhook_event(event_by_id, self.db)
        self.assertEqual(res_id["status"], "updated")
        self.assertEqual(res_id["new_status"], "Delivered")

        self.db.refresh(notif)
        self.assertEqual(notif.delivery_status, "Delivered")

    # 19. Admin can safely re-queue terminal Failed outbox records
    @patch('httpx.Client.post')
    def test_19_admin_retry_failed_records(self, mock_post):
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {
            "status": "submitted",
            "messageId": "requeued-msg-id-123"
        }
        mock_post.return_value = mock_response

        # Create a record that previously failed terminally
        failed_outbox = WhatsAppOutbox(
            order_id=506,
            order_number="ORD-FAILED-RETRY",
            recipient_phone="919876500000",
            template_id="c6aecef6-bcb0-4fb1-8100-28c094e3bc6b",
            template_name="yadviapporder_confirmation",
            payload_json=json.dumps({"order_number": "ORD-FAILED-RETRY", "params": ["ORD-FAILED-RETRY", "Shop", "987", "d", "p", "q"]}),
            status="Failed",
            retry_count=3,
            last_error="Simulated network failure"
        )
        self.db.add(failed_outbox)
        self.db.commit()

        # Admin calls process_gupshup_outbox with retry_failed=True
        res = process_gupshup_outbox(
            max_batch=10,
            retry_failed=True,
            db=self.db,
            current_user=self.admin_user
        )
        self.assertTrue(res["success"])
        self.assertEqual(res["summary"]["dispatched"], 1)

        self.db.refresh(failed_outbox)
        self.assertEqual(failed_outbox.status, "Dispatched")
        self.assertIsNone(failed_outbox.locked_at)

    # 20. When dispatch is paused, outbox entries are preserved without consuming retries or failing
    @patch('httpx.Client.post')
    def test_20_dispatch_paused_preserves_outbox_without_retries(self, mock_post):
        # Explicitly pause dispatch via feature flag
        settings.GUPSHUP_DISPATCH_ENABLED = False

        # Create an order: outbox entry is enqueued safely
        payload = OrderCreateRequest(
            items=[OrderItemIn(product_id=1, quantity=1.0, unit="kg")],
            source="Shop Owner App"
        )
        order_out = create_order(payload=payload, db=self.db, current_user=self.dealer_user)
        self.assertIsNotNone(order_out)

        outbox = self.db.query(WhatsAppOutbox).filter(WhatsAppOutbox.order_number == order_out.order_number).first()
        self.assertIsNotNone(outbox)
        self.assertEqual(outbox.status, "Pending")
        self.assertEqual(outbox.retry_count, 0)
        self.assertIsNone(outbox.locked_at)

        # Worker runs while dispatch is paused
        summary = self.service.process_outbox_queue(db=self.db, max_batch=10)
        self.assertTrue(summary.get("paused"))
        self.assertEqual(summary.get("dispatched"), 0)
        self.assertEqual(summary.get("failed"), 0)
        self.assertEqual(summary.get("retried"), 0)

        # HTTP post must NOT be called
        self.assertEqual(mock_post.call_count, 0)

        # Outbox entry must remain untouched in Pending state with 0 retries
        self.db.refresh(outbox)
        self.assertEqual(outbox.status, "Pending")
        self.assertEqual(outbox.retry_count, 0)
        self.assertIsNone(outbox.locked_at)

    # 21. Direct dispatch calls return dispatch_paused when feature flag is disabled
    @patch('httpx.Client.post')
    def test_21_dispatch_paused_direct_calls(self, mock_post):
        settings.GUPSHUP_DISPATCH_ENABLED = False

        order = Order(id=999, order_number="ORD-PAUSED-DIRECT", shop_id=1)
        order.shop = self.shop
        items = [OrderItem(product_id=1, quantity=1.0, unit="kg")]

        res_direct = self.service.send_order_notification(order, items)
        self.assertFalse(res_direct["success"])
        self.assertEqual(res_direct["status"], "dispatch_paused")

        outbox = WhatsAppOutbox(
            order_id=999,
            order_number="ORD-PAUSED-DIRECT",
            recipient_phone="919876500000",
            template_id="c6aecef6-bcb0-4fb1-8100-28c094e3bc6b",
            template_name="yadviapporder_confirmation",
            payload_json=json.dumps({"order_number": "ORD-PAUSED-DIRECT", "params": []}),
            status="Pending"
        )
        res_outbox = self.service.send_from_outbox(outbox)
        self.assertFalse(res_outbox["success"])
        self.assertEqual(res_outbox["status"], "dispatch_paused")
        self.assertEqual(mock_post.call_count, 0)

    # 22. Configuration: distinct sender and admin recipient numbers
    def test_22_admin_recipient_and_sender_configuration(self):
        service = GupshupWhatsAppService(
            source_number="918262028208",
            admin_recipient="919850082563",
        )
        self.assertEqual(service.source_number, "918262028208")
        self.assertEqual(service.admin_recipient, "919850082563")
        # Ensure sender and recipient are not identical (Meta Cloud API restriction)
        self.assertNotEqual(service.source_number, service.admin_recipient)
        self.assertEqual(mask_phone_number(service.source_number), "91******8208")
        self.assertEqual(mask_phone_number(service.admin_recipient), "91******2563")


if __name__ == '__main__':
    unittest.main()
