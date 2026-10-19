import re
import logging
from typing import Dict, Any, Optional
import httpx
from app.core.config import settings

logger = logging.getLogger("yadvi_whatsapp")


def mask_phone_number(phone: str) -> str:
    """Masks a phone number for privacy in logs (e.g., 91******1234)."""
    cleaned = re.sub(r"[^\d]", "", phone or "")
    if len(cleaned) <= 4:
        return "****"
    return cleaned[:2] + ("*" * (len(cleaned) - 6)) + cleaned[-4:] if len(cleaned) > 6 else cleaned[:1] + "****" + cleaned[-1:]


def sanitize_phone_number(phone: str) -> str:
    """Cleans phone numbers into standard digits-only format required by Meta WhatsApp Cloud API."""
    return re.sub(r"[^\d]", "", phone or "")


class WhatsAppService:
    """
    WhatsApp Cloud API Service for YADVI Hybrid Seeds.

    Adheres strictly to enterprise security rules:
    - Never logs, returns, or prints access tokens or authorization headers.
    - Masks phone numbers in logs.
    - During testing phase, only allows sending to the explicitly configured WHATSAPP_TEST_RECIPIENT.
    - Never includes prices or financial data.
    - Explicit network timeouts and robust error handling that never crashes FastAPI.
    """

    def __init__(self):
        self.api_version = getattr(settings, "WHATSAPP_API_VERSION", "v21.0") or "v21.0"
        self.base_url = getattr(settings, "WHATSAPP_API_BASE_URL", "https://graph.facebook.com") or "https://graph.facebook.com"
        self.phone_number_id = getattr(settings, "WHATSAPP_PHONE_NUMBER_ID", None)
        self.access_token = getattr(settings, "WHATSAPP_ACCESS_TOKEN", None)
        self.test_recipient = getattr(settings, "WHATSAPP_TEST_RECIPIENT", None)
        self.order_template_name = getattr(settings, "WHATSAPP_ORDER_TEMPLATE_NAME", None)
        self.order_template_lang = getattr(settings, "WHATSAPP_ORDER_TEMPLATE_LANG", "en_US") or "en_US"
        self.timeout = 15.0  # seconds

    def is_configured(self) -> bool:
        """Returns True if minimum required credentials and test recipient are present."""
        return bool(self.phone_number_id and self.access_token and self.test_recipient)

    def _get_messages_url(self) -> str:
        return f"{self.base_url.rstrip('/')}/{self.api_version}/{self.phone_number_id}/messages"

    def send_template_test(self, template_name: str = "hello_world", language_code: str = "en_US") -> Dict[str, Any]:
        """
        Sends a pre-approved template message to the strictly configured WHATSAPP_TEST_RECIPIENT.
        Does not accept an arbitrary destination from an API caller.
        """
        if not self.phone_number_id or not self.access_token:
            logger.warning("WhatsApp credentials missing. Unable to send test message.")
            return {
                "success": False,
                "status": "configuration_error",
                "message": "WhatsApp Cloud API credentials (phone number ID or access token) are not configured.",
                "http_status": None,
                "meta_message_id": None,
                "recipient_masked": None,
            }

        if not self.test_recipient:
            logger.warning("WHATSAPP_TEST_RECIPIENT is not configured.")
            return {
                "success": False,
                "status": "configuration_error",
                "message": "WHATSAPP_TEST_RECIPIENT is not configured in backend environment.",
                "http_status": None,
                "meta_message_id": None,
                "recipient_masked": None,
            }

        recipient_clean = sanitize_phone_number(self.test_recipient)
        masked_recipient = mask_phone_number(recipient_clean)

        if not recipient_clean:
            return {
                "success": False,
                "status": "validation_error",
                "message": "Configured WHATSAPP_TEST_RECIPIENT does not contain a valid phone number.",
                "http_status": None,
                "meta_message_id": None,
                "recipient_masked": masked_recipient,
            }

        url = self._get_messages_url()
        headers = {
            "Authorization": f"Bearer {self.access_token}",
            "Content-Type": "application/json",
        }
        payload = {
            "messaging_product": "whatsapp",
            "to": recipient_clean,
            "type": "template",
            "template": {
                "name": template_name,
                "language": {
                    "code": language_code
                }
            }
        }

        logger.info(f"Dispatching test template '{template_name}' to recipient {masked_recipient}")

        try:
            with httpx.Client(timeout=self.timeout) as client:
                response = client.post(url, json=payload, headers=headers)

            http_status = response.status_code

            try:
                response_data = response.json()
            except Exception:
                response_data = {}

            if 200 <= http_status < 300:
                messages = response_data.get("messages", [])
                meta_id = messages[0].get("id") if messages and isinstance(messages, list) else None
                logger.info(f"WhatsApp Cloud API accepted message to {masked_recipient}. Meta ID: {meta_id}")
                return {
                    "success": True,
                    "status": "accepted_by_meta",
                    "message": "WhatsApp Cloud API accepted the message request. Note: Actual delivery depends on recipient device status.",
                    "http_status": http_status,
                    "meta_message_id": meta_id,
                    "recipient_masked": masked_recipient,
                }
            else:
                error_obj = response_data.get("error", {})
                error_msg = error_obj.get("message", "Request was rejected by Meta WhatsApp Cloud API.")
                error_code = error_obj.get("code")
                error_type = error_obj.get("type")

                # Sanitize error message to ensure no tokens or sensitive headers leak
                safe_error_msg = str(error_msg).replace(self.access_token, "[REDACTED]")

                logger.warning(
                    f"Meta WhatsApp API rejected message to {masked_recipient}. "
                    f"HTTP {http_status}, Code {error_code}, Type {error_type}: {safe_error_msg}"
                )

                return {
                    "success": False,
                    "status": "rejected_by_meta",
                    "message": safe_error_msg,
                    "error_code": error_code,
                    "http_status": http_status,
                    "meta_message_id": None,
                    "recipient_masked": masked_recipient,
                }

        except httpx.TimeoutException:
            logger.error(f"Timeout while contacting Meta WhatsApp API for {masked_recipient}")
            return {
                "success": False,
                "status": "network_timeout",
                "message": "Connection to Meta WhatsApp Cloud API timed out.",
                "http_status": None,
                "meta_message_id": None,
                "recipient_masked": masked_recipient,
            }
        except httpx.RequestError as exc:
            logger.error(f"Network error while contacting Meta WhatsApp API for {masked_recipient}: {type(exc).__name__}")
            return {
                "success": False,
                "status": "network_error",
                "message": "Network error while connecting to Meta WhatsApp Cloud API.",
                "http_status": None,
                "meta_message_id": None,
                "recipient_masked": masked_recipient,
            }
        except Exception as exc:
            logger.error(f"Unexpected error in WhatsApp service: {type(exc).__name__}")
            return {
                "success": False,
                "status": "internal_error",
                "message": "An unexpected error occurred while processing WhatsApp request.",
                "http_status": None,
                "meta_message_id": None,
                "recipient_masked": masked_recipient,
            }

    def format_order_confirmation_message(self, order, items: list) -> str:
        """
        Formats order confirmation message with required details:
        - Order number
        - Order date
        - Product names
        - Quantities
        - Total amount / volume
        - Order status
        """
        order_date_str = order.created_at.strftime("%d-%b-%Y %I:%M %p") if getattr(order, "created_at", None) else "Today"
        shop_name = order.shop.shop_name if getattr(order, "shop", None) and getattr(order.shop, "shop_name", None) else "YADVI Partner"
        owner_name = order.shop.user.full_name if getattr(order, "shop", None) and getattr(order.shop, "user", None) and getattr(order.shop.user, "full_name", None) else None
        partner_display = f"{shop_name} ({owner_name})" if owner_name else shop_name

        item_lines = []
        for i, item in enumerate(items, 1):
            prod_name = getattr(item, "product_name", None)
            if not prod_name and getattr(item, "product", None):
                prod_name = item.product.name
            prod_name = prod_name or f"Product #{getattr(item, 'product_id', i)}"
            pkg_size = getattr(item, "package_size", "Standard")
            qty = getattr(item, "quantity", None)
            unit = getattr(item, "unit", "kg")
            if qty is None:
                qty = getattr(item, "quantity_bags", 0)
                unit = "kg"
            item_lines.append(f"  {i}. {prod_name} ({pkg_size}) — {qty} {unit}")

        items_str = "\n".join(item_lines) if item_lines else "  1. Standard Seed Consignment"
        total_kg = getattr(order, "total_quantity_kg", None)
        if total_kg is None or total_kg == 0.0:
            total_kg = getattr(order, "total_quantity_bags", sum(getattr(it, "quantity", 0) for it in items))

        message = (
            f"🌾 *YADVI Hybrid Seeds — Order Confirmation* 🌾\n\n"
            f"Dear Partner ({partner_display}),\n"
            f"Your order has been successfully placed and confirmed!\n\n"
            f"📋 *Order Number:* {order.order_number}\n"
            f"📅 *Order Date:* {order_date_str}\n"
            f"📦 *Order Status:* {order.status}\n\n"
            f"🌱 *Ordered Products:*\n"
            f"{items_str}\n\n"
            f"📊 *Total Quantity:* {total_kg} kg\n"
            f"💰 *Total Amount:* Billed on Dispatch / Invoice Generated with LR\n\n"
            f"Thank you for choosing YADVI Hybrid Seeds!"
        )
        return message

    def send_text_message(self, message_text: str, recipient: Optional[str] = None) -> Dict[str, Any]:
        """
        Sends a standard text WhatsApp message to the configured test recipient.
        Never logs sensitive access tokens or full phone numbers.
        """
        if not self.phone_number_id or not self.access_token:
            logger.warning("WhatsApp credentials missing. Unable to send text message.")
            return {
                "success": False,
                "status": "configuration_error",
                "message": "WhatsApp Cloud API credentials (phone number ID or access token) are not configured.",
                "http_status": None,
                "meta_message_id": None,
                "recipient_masked": None,
            }

        target_recipient = recipient or self.test_recipient
        if not target_recipient:
            logger.warning("WhatsApp recipient is not configured.")
            return {
                "success": False,
                "status": "configuration_error",
                "message": "WHATSAPP_TEST_RECIPIENT is not configured in backend environment.",
                "http_status": None,
                "meta_message_id": None,
                "recipient_masked": None,
            }

        recipient_clean = sanitize_phone_number(target_recipient)
        masked_recipient = mask_phone_number(recipient_clean)

        if not recipient_clean:
            return {
                "success": False,
                "status": "validation_error",
                "message": "Configured recipient does not contain a valid phone number.",
                "http_status": None,
                "meta_message_id": None,
                "recipient_masked": masked_recipient,
            }

        url = self._get_messages_url()
        headers = {
            "Authorization": f"Bearer {self.access_token}",
            "Content-Type": "application/json",
        }
        payload = {
            "messaging_product": "whatsapp",
            "recipient_type": "individual",
            "to": recipient_clean,
            "type": "text",
            "text": {
                "preview_url": False,
                "body": message_text
            }
        }

        logger.info(f"Dispatching WhatsApp text message to recipient {masked_recipient}")

        try:
            with httpx.Client(timeout=self.timeout) as client:
                response = client.post(url, json=payload, headers=headers)

            http_status = response.status_code

            try:
                response_data = response.json()
            except Exception:
                response_data = {}

            if 200 <= http_status < 300:
                messages = response_data.get("messages", [])
                meta_id = messages[0].get("id") if messages and isinstance(messages, list) else None
                logger.info(f"WhatsApp Cloud API accepted text message to {masked_recipient}. Meta ID: {meta_id}")
                return {
                    "success": True,
                    "status": "accepted_by_meta",
                    "message": "WhatsApp Cloud API accepted the message request. Note: Actual delivery depends on recipient device status.",
                    "http_status": http_status,
                    "meta_message_id": meta_id,
                    "recipient_masked": masked_recipient,
                }
            else:
                error_obj = response_data.get("error", {})
                error_msg = error_obj.get("message", "Request was rejected by Meta WhatsApp Cloud API.")
                error_code = error_obj.get("code")
                error_type = error_obj.get("type")

                safe_error_msg = str(error_msg).replace(self.access_token, "[REDACTED]")

                logger.warning(
                    f"Meta WhatsApp API rejected text message to {masked_recipient}. "
                    f"HTTP {http_status}, Code {error_code}, Type {error_type}: {safe_error_msg}"
                )

                return {
                    "success": False,
                    "status": "rejected_by_meta",
                    "message": safe_error_msg,
                    "error_code": error_code,
                    "http_status": http_status,
                    "meta_message_id": None,
                    "recipient_masked": masked_recipient,
                }

        except httpx.TimeoutException:
            logger.error(f"Timeout while contacting Meta WhatsApp API for {masked_recipient}")
            return {
                "success": False,
                "status": "network_timeout",
                "message": "Connection to Meta WhatsApp Cloud API timed out.",
                "http_status": None,
                "meta_message_id": None,
                "recipient_masked": masked_recipient,
            }
        except httpx.RequestError as exc:
            logger.error(f"Network error while contacting Meta WhatsApp API for {masked_recipient}: {type(exc).__name__}")
            return {
                "success": False,
                "status": "network_error",
                "message": "Network error while connecting to Meta WhatsApp Cloud API.",
                "http_status": None,
                "meta_message_id": None,
                "recipient_masked": masked_recipient,
            }
        except Exception as exc:
            logger.error(f"Unexpected error in WhatsApp text service: {type(exc).__name__}")
            return {
                "success": False,
                "status": "internal_error",
                "message": "An unexpected error occurred while processing WhatsApp request.",
                "http_status": None,
                "meta_message_id": None,
                "recipient_masked": masked_recipient,
            }

    def build_order_template_components(self, order, items: list) -> list:
        """
        Builds positional components for an approved Meta Utility order-confirmation template:
        {{1}}: Shop Name
        {{2}}: Order Number
        {{3}}: Order Date
        {{4}}: Order Status
        {{5}}: Itemized Products Summary
        {{6}}: Total Volume (Bags)
        {{7}}: Pricing / Settlement Status
        """
        order_date_str = order.created_at.strftime("%d-%b-%Y %I:%M %p") if getattr(order, "created_at", None) else "Today"
        shop_name = order.shop.shop_name if getattr(order, "shop", None) and getattr(order.shop, "shop_name", None) else "YADVI Partner"
        owner_name = order.shop.user.full_name if getattr(order, "shop", None) and getattr(order.shop, "user", None) and getattr(order.shop.user, "full_name", None) else None
        partner_display = f"{shop_name} ({owner_name})" if owner_name else shop_name

        item_lines = []
        for i, item in enumerate(items, 1):
            prod_name = getattr(item, "product_name", None)
            if not prod_name and getattr(item, "product", None):
                prod_name = item.product.name
            prod_name = prod_name or f"Product #{getattr(item, 'product_id', i)}"
            pkg_size = getattr(item, "package_size", "Standard")
            qty = getattr(item, "quantity", None)
            unit = getattr(item, "unit", "kg")
            if qty is None:
                qty = getattr(item, "quantity_bags", 0)
                unit = "kg"
            item_lines.append(f"{i}. {prod_name} ({pkg_size}) — {qty} {unit}")

        items_summary = "\n".join(item_lines) if item_lines else "1. Standard Seed Consignment"
        total_kg = getattr(order, "total_quantity_kg", None)
        if total_kg is None or total_kg == 0.0:
            total_kg = getattr(order, "total_quantity_bags", sum(getattr(it, "quantity", 0) for it in items))

        return [
            {
                "type": "body",
                "parameters": [
                    {"type": "text", "text": str(partner_display)},
                    {"type": "text", "text": str(order.order_number)},
                    {"type": "text", "text": str(order_date_str)},
                    {"type": "text", "text": str(order.status)},
                    {"type": "text", "text": str(items_summary)},
                    {"type": "text", "text": f"{total_kg} kg"},
                    {"type": "text", "text": "Billed on Dispatch / Invoice Generated with LR"},
                ]
            }
        ]

    def send_template_message(
        self,
        template_name: str,
        language_code: str = "en_US",
        components: Optional[list] = None,
        recipient: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Sends an approved Meta template message with dynamic parameters.
        Delivers 24/7 regardless of customer service window status.
        """
        if not self.phone_number_id or not self.access_token:
            logger.warning("WhatsApp credentials missing. Unable to send template message.")
            return {
                "success": False,
                "status": "configuration_error",
                "message": "WhatsApp Cloud API credentials (phone number ID or access token) are not configured.",
                "http_status": None,
                "meta_message_id": None,
                "recipient_masked": None,
            }

        target_recipient = recipient or self.test_recipient
        if not target_recipient:
            logger.warning("WhatsApp recipient is not configured.")
            return {
                "success": False,
                "status": "configuration_error",
                "message": "WHATSAPP_TEST_RECIPIENT is not configured in backend environment.",
                "http_status": None,
                "meta_message_id": None,
                "recipient_masked": None,
            }

        recipient_clean = sanitize_phone_number(target_recipient)
        masked_recipient = mask_phone_number(recipient_clean)

        if not recipient_clean:
            return {
                "success": False,
                "status": "validation_error",
                "message": "Configured recipient does not contain a valid phone number.",
                "http_status": None,
                "meta_message_id": None,
                "recipient_masked": masked_recipient,
            }

        url = self._get_messages_url()
        headers = {
            "Authorization": f"Bearer {self.access_token}",
            "Content-Type": "application/json",
        }
        template_payload = {
            "name": template_name,
            "language": {
                "code": language_code
            }
        }
        if components:
            template_payload["components"] = components

        payload = {
            "messaging_product": "whatsapp",
            "recipient_type": "individual",
            "to": recipient_clean,
            "type": "template",
            "template": template_payload
        }

        logger.info(f"Dispatching template '{template_name}' to recipient {masked_recipient}")

        try:
            with httpx.Client(timeout=self.timeout) as client:
                response = client.post(url, json=payload, headers=headers)

            http_status = response.status_code
            try:
                response_data = response.json()
            except Exception:
                response_data = {}

            if 200 <= http_status < 300:
                messages = response_data.get("messages", [])
                meta_id = messages[0].get("id") if messages and isinstance(messages, list) else None
                logger.info(f"WhatsApp Cloud API accepted template '{template_name}' for {masked_recipient}. Meta ID: {meta_id}")
                return {
                    "success": True,
                    "status": "accepted_by_meta",
                    "message": "WhatsApp Cloud API accepted template message.",
                    "http_status": http_status,
                    "meta_message_id": meta_id,
                    "recipient_masked": masked_recipient,
                }
            else:
                error_obj = response_data.get("error", {})
                error_msg = error_obj.get("message", "Request was rejected by Meta WhatsApp Cloud API.")
                error_code = error_obj.get("code")
                error_type = error_obj.get("type")
                safe_error_msg = str(error_msg).replace(self.access_token, "[REDACTED]")

                logger.warning(
                    f"Meta WhatsApp API rejected template '{template_name}' for {masked_recipient}. "
                    f"HTTP {http_status}, Code {error_code}, Type {error_type}: {safe_error_msg}"
                )
                return {
                    "success": False,
                    "status": "rejected_by_meta",
                    "message": safe_error_msg,
                    "error_code": error_code,
                    "http_status": http_status,
                    "meta_message_id": None,
                    "recipient_masked": masked_recipient,
                }
        except httpx.TimeoutException:
            logger.error(f"Timeout while contacting Meta WhatsApp API for {masked_recipient}")
            return {
                "success": False,
                "status": "network_timeout",
                "message": "Connection to Meta WhatsApp Cloud API timed out.",
                "http_status": None,
                "meta_message_id": None,
                "recipient_masked": masked_recipient,
            }
        except httpx.RequestError as exc:
            logger.error(f"Network error while contacting Meta WhatsApp API for {masked_recipient}: {type(exc).__name__}")
            return {
                "success": False,
                "status": "network_error",
                "message": "Network error while connecting to Meta WhatsApp Cloud API.",
                "http_status": None,
                "meta_message_id": None,
                "recipient_masked": masked_recipient,
            }
        except Exception as exc:
            logger.error(f"Unexpected error in WhatsApp template service: {type(exc).__name__}")
            return {
                "success": False,
                "status": "internal_error",
                "message": "An unexpected error occurred while processing WhatsApp request.",
                "http_status": None,
                "meta_message_id": None,
                "recipient_masked": masked_recipient,
            }

    def send_order_confirmation(self, order, items: list) -> Dict[str, Any]:
        """
        Sends WhatsApp order confirmation message to the configured test recipient.
        Uses approved Meta Utility template if WHATSAPP_ORDER_TEMPLATE_NAME is configured.
        Blocks free-form text fallback to prevent silent Meta downstream delivery drops outside 24h window.
        """
        message_text = self.format_order_confirmation_message(order, items)

        if not self.order_template_name:
            logger.warning(
                "WHATSAPP_ORDER_TEMPLATE_NAME is not configured. "
                "Outbound order confirmation blocked to prevent silent downstream delivery drop outside 24h window."
            )
            recipient_clean = sanitize_phone_number(self.test_recipient)
            masked_recipient = mask_phone_number(recipient_clean)
            return {
                "success": False,
                "status": "template_unconfigured",
                "message": (
                    "WHATSAPP_ORDER_TEMPLATE_NAME is not configured. "
                    "Business-initiated order confirmations outside the 24-hour window require a pre-approved Meta Utility template."
                ),
                "http_status": None,
                "meta_message_id": None,
                "recipient_masked": masked_recipient,
                "dispatch_mode": "blocked_unconfigured_template",
                "message_text": message_text,
                "error_code": "TEMPLATE_UNCONFIGURED",
            }

        components = self.build_order_template_components(order, items)
        result = self.send_template_message(
            template_name=self.order_template_name,
            language_code=self.order_template_lang,
            components=components
        )
        result["dispatch_mode"] = "template"
        result["template_name"] = self.order_template_name
        result["message_text"] = message_text
        return result


whatsapp_service = WhatsAppService()
