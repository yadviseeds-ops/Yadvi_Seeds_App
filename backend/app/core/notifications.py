import os
import logging
from sqlalchemy.orm import Session
from app.models.all_models import Notification, User

logger = logging.getLogger("yadvi_notifications")

class WhatsAppProviderInterface:
    def send_template_message(self, phone: str, template_name: str, parameters: dict) -> bool:
        raise NotImplementedError

class OfficialWhatsAppProvider(WhatsAppProviderInterface):
    def __init__(self):
        self.api_url = os.getenv("WHATSAPP_API_URL")
        self.api_token = os.getenv("WHATSAPP_API_TOKEN")
        self.phone_number_id = os.getenv("WHATSAPP_PHONE_NUMBER_ID")
        
        self.is_configured = all([self.api_url, self.api_token, self.phone_number_id])
        
    def send_template_message(self, phone: str, template_name: str, parameters: dict) -> bool:
        if not self.is_configured:
            logger.warning(f"PENDING CONFIGURATION: WhatsApp credentials not configured. Skipping WhatsApp message to {phone}.")
            return False
            
        logger.info(f"Sending WhatsApp template {template_name} to {phone}")
        # Real integration would use requests.post here
        return True

class FCMNotificationProvider:
    def __init__(self):
        import firebase_admin
        from firebase_admin import credentials
        
        # Check if already initialized to avoid errors on reload
        if not firebase_admin._apps:
            # We look for a credentials JSON path in env var
            cred_path = os.getenv("FIREBASE_CREDENTIALS_PATH")
            if cred_path and os.path.exists(cred_path):
                cred = credentials.Certificate(cred_path)
                firebase_admin.initialize_app(cred)
                self.is_configured = True
            else:
                self.is_configured = False
        else:
            self.is_configured = True

    def send_to_device(self, token: str, title: str, body: str, data: dict = None) -> bool:
        if not self.is_configured:
            logger.warning("PENDING CONFIGURATION: FCM credentials not configured. Skipping push notification.")
            return False
            
        from firebase_admin import messaging
        
        try:
            message = messaging.Message(
                notification=messaging.Notification(
                    title=title,
                    body=body,
                ),
                data=data or {},
                token=token,
            )
            response = messaging.send(message)
            logger.info(f"Successfully sent FCM message: {response}")
            return True
        except Exception as e:
            logger.error(f"Error sending FCM message: {e}")
            return False

class NotificationService:
    def __init__(self, db: Session):
        self.db = db
        self.whatsapp_provider = OfficialWhatsAppProvider()
        self.fcm_provider = FCMNotificationProvider()
        
    def notify_admin_new_order(self, order, admin_user: User):
        # 1. Save notification to DB
        content = f"New YADVI Order\n\nOrder Number: {order.order_number}\nShop: {order.shop.shop_name if order.shop else 'N/A'}\nTotal Quantity: {order.total_quantity_bags} bags\n\nPlease review and assign a Field Executive."
        db_notif = Notification(
            user_id=admin_user.id,
            title="New Order Received",
            content=content,
            type="Order_Alert",
            is_read=False
        )
        self.db.add(db_notif)
        self.db.commit()
        
        # 2. Try sending WhatsApp
        self.whatsapp_provider.send_template_message(
            phone=admin_user.phone,
            template_name="new_order_admin_alert",
            parameters={
                "order_number": order.order_number,
                "shop_name": order.shop.shop_name if order.shop else 'N/A',
                "quantity": order.total_quantity_bags
            }
        )

    def notify_fe_new_order_assigned(self, order, fe_user: User):
        # 1. Save to DB
        content = f"New order #{order.order_number} assigned for shop {order.shop.shop_name if order.shop else 'N/A'}."
        db_notif = Notification(
            user_id=fe_user.id,
            title="Order Assigned",
            content=content,
            type="Assignment",
            is_read=False
        )
        self.db.add(db_notif)
        self.db.commit()
        
        # 2. Push notification via FCM
        if fe_user.fcm_tokens:
            for token_obj in fe_user.fcm_tokens:
                if token_obj.is_active:
                    self.fcm_provider.send_to_device(
                        token=token_obj.device_token,
                        title="New Order Assigned",
                        body=content,
                        data={"order_id": str(order.id), "type": "assignment"}
                    )

    def notify_shop_order_status(self, order, shop_user: User):
        content = f"Your order #{order.order_number} is now {order.status}."
        db_notif = Notification(
            user_id=shop_user.id,
            title="Order Status Update",
            content=content,
            type="Order_Status",
            is_read=False
        )
        self.db.add(db_notif)
        self.db.commit()
        
        if shop_user.fcm_tokens:
            for token_obj in shop_user.fcm_tokens:
                if token_obj.is_active:
                    self.fcm_provider.send_to_device(
                        token=token_obj.device_token,
                        title="Order Status Update",
                        body=content,
                        data={"order_id": str(order.id), "status": order.status}
                    )
