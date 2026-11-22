import json
import logging
import re
from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional
import httpx

from app.core.config import settings

logger = logging.getLogger("yadvi_gupshup_whatsapp")


def mask_phone_number(phone: Optional[str]) -> str:
    """Masks a phone number for safe logging (e.g., 91******1234)."""
    cleaned = re.sub(r"[^\d]", "", phone or "")
    if not cleaned:
        return "****"
    if len(cleaned) <= 4:
        return "****"
    if len(cleaned) > 6:
        return cleaned[:2] + ("*" * (len(cleaned) - 6)) + cleaned[-4:]
    return cleaned[:1] + "****" + cleaned[-1:]


def sanitize_phone_number(phone: Optional[str]) -> str:
    """
    Cleans phone numbers into digits-only standard E.164 format without leading '+'
    as expected by the Gupshup WhatsApp Business API (e.g. 919876543210).
    """
    cleaned = re.sub(r"[^\d]", "", phone or "")
    if not cleaned:
        return ""
    # If 10 digits starting with Indian mobile prefixes (6-9), prepend country code 91
    if len(cleaned) == 10 and cleaned[0] in "6789":
        return f"91{cleaned}"
    # If 11 digits starting with 0, drop leading 0 and prepend 91
    if len(cleaned) == 11 and cleaned.startswith("0") and cleaned[1] in "6789":
        return f"91{cleaned[1:]}"
    return cleaned


_UNSET = object()


class GupshupWhatsAppService:
    """
    Enterprise Gupshup WhatsApp Business API integration for YADVI Hybrid Seeds.

    Delivery Semantics & Failure Boundaries:
    - Transactional Persistence: WhatsAppOutbox entries are committed atomically
      within the same database transaction as the Order, guaranteeing that every
      created Order has a durable notification record without synchronous HTTP overhead.
    - At-Least-Once Delivery Attempts: The outbox worker repeatedly attempts dispatch
      with exponential backoff (2^retry_count * 5s) up to `max_retries` (default: 3).
    - Terminal Failures: Records that exhaust all retries transition to status='Failed'.
      They do NOT disappear; they remain in the database for Administrator visibility
      via the `/api/v1/notifications/gupshup/outbox-status` endpoint and can be
      re-queued via `/api/v1/notifications/gupshup/process-outbox?retry_failed=true`.
    - Duplicate Delivery Across External Boundary: Exactly-once delivery cannot be
      guaranteed across external network boundaries. If Gupshup receives a dispatch
      request but the network connection times out before the client receives the HTTP response,
      a subsequent retry may result in Gupshup dispatching a duplicate message.
      The outbox worker checks existing Notification records before dispatch to minimize this window.
    - Strict configuration enforcement: GUPSHUP_APP_NAME (src.name) and GUPSHUP_TEMPLATE_ID
      (approved template UUID) are required for live API calls.
    - Never logs, returns, or prints API keys or authorization headers.
    - Masks phone numbers in all log messages.
    - Non-blocking error handling that never crashes order placement or FastAPI.
    - Idempotent and monotonic delivery-status tracking via webhooks.
    """

    def __init__(
        self,
        api_key: Optional[str] = None,
        source_number: Optional[str] = None,
        admin_recipient: Optional[str] = None,
        app_name: Optional[str] = None,
        app_id: Optional[str] = None,
        template_id: Optional[str] = None,
        template_name: Optional[str] = None,
        template_lang: Optional[str] = None,
        base_url: Optional[str] = None,
        dispatch_enabled: Optional[bool] = None,
    ):
        self._base_url = base_url if base_url is not None else _UNSET
        self._api_key = api_key if api_key is not None else _UNSET
        self._app_name = app_name if app_name is not None else _UNSET
        self._app_id = app_id if app_id is not None else _UNSET
        self._source_number = source_number if source_number is not None else _UNSET
        self._admin_recipient = admin_recipient if admin_recipient is not None else _UNSET
        self._template_id = template_id if template_id is not None else _UNSET
        self._template_name = template_name if template_name is not None else _UNSET
        self._template_lang = template_lang if template_lang is not None else _UNSET
        self._dispatch_enabled = dispatch_enabled if dispatch_enabled is not None else _UNSET
        self.timeout = 15.0  # seconds

    @property
    def dispatch_enabled(self) -> bool:
        if self._dispatch_enabled is not _UNSET and self._dispatch_enabled is not None:
            return bool(self._dispatch_enabled)
        val = getattr(settings, "GUPSHUP_DISPATCH_ENABLED", False)
        if isinstance(val, str):
            return val.strip().lower() in ("true", "1", "yes", "enabled")
        return bool(val)

    @dispatch_enabled.setter
    def dispatch_enabled(self, val: Optional[bool]):
        self._dispatch_enabled = val

    @property
    def base_url(self) -> str:
        if self._base_url is not _UNSET and self._base_url is not None:
            return self._base_url.rstrip("/")
        url = getattr(settings, "GUPSHUP_BASE_URL", "https://api.gupshup.io") or "https://api.gupshup.io"
        return url.rstrip("/")

    @base_url.setter
    def base_url(self, val: Optional[str]):
        self._base_url = val

    @property
    def api_key(self) -> Optional[str]:
        if self._api_key is not _UNSET:
            return self._api_key
        return getattr(settings, "GUPSHUP_API_KEY", None)

    @api_key.setter
    def api_key(self, val: Optional[str]):
        self._api_key = val

    @property
    def app_name(self) -> Optional[str]:
        if self._app_name is not _UNSET:
            return self._app_name
        return getattr(settings, "GUPSHUP_APP_NAME", None)

    @app_name.setter
    def app_name(self, val: Optional[str]):
        self._app_name = val

    @property
    def app_id(self) -> Optional[str]:
        if self._app_id is not _UNSET:
            return self._app_id
        return getattr(settings, "GUPSHUP_APP_ID", None)

    @app_id.setter
    def app_id(self, val: Optional[str]):
        self._app_id = val

    @property
    def source_number(self) -> Optional[str]:
        if self._source_number is not _UNSET:
            return self._source_number
        return getattr(settings, "GUPSHUP_SOURCE_NUMBER", None)

    @source_number.setter
    def source_number(self, val: Optional[str]):
        self._source_number = val

    @property
    def admin_recipient(self) -> Optional[str]:
        if self._admin_recipient is not _UNSET:
            return self._admin_recipient
        return getattr(settings, "GUPSHUP_ADMIN_RECIPIENT", None)

    @admin_recipient.setter
    def admin_recipient(self, val: Optional[str]):
        self._admin_recipient = val

    @property
    def template_id(self) -> Optional[str]:
        if self._template_id is not _UNSET:
            return self._template_id
        return getattr(settings, "GUPSHUP_TEMPLATE_ID", None)

    @template_id.setter
    def template_id(self, val: Optional[str]):
        self._template_id = val

    @property
    def template_name(self) -> str:
        if self._template_name is not _UNSET and self._template_name is not None:
            return self._template_name
        name = getattr(settings, "GUPSHUP_TEMPLATE_NAME", "yadviapporder_confirmation")
        return name or "yadviapporder_confirmation"

    @template_name.setter
    def template_name(self, val: Optional[str]):
        self._template_name = val

    @property
    def template_lang(self) -> str:
        if self._template_lang is not _UNSET and self._template_lang is not None:
            return self._template_lang
        lang = getattr(settings, "GUPSHUP_TEMPLATE_LANG", "en_US")
        return lang or "en_US"

    @template_lang.setter
    def template_lang(self, val: Optional[str]):
        self._template_lang = val

    def is_configured(self) -> bool:
        """
        Returns True only if all required parameters for live Gupshup API dispatch are present:
        - api_key
        - source_number
        - admin_recipient
        - app_name (required for src.name in form payload)
        - template_id (approved template UUID; human-readable template name is not valid)
        """
        return bool(
            self.api_key
            and self.source_number
            and self.admin_recipient
            and self.app_name
            and self.template_id
        )

    def _get_template_msg_url(self) -> str:
        return f"{self.base_url}/wa/api/v1/template/msg"

    def _get_app_template_url(self) -> Optional[str]:
        if not self.app_id:
            return None
        return f"{self.base_url}/wa/app/{self.app_id}/template"

    def format_template_variables(self, order, items: list) -> List[str]:
        """
        Populates the 6 required Gupshup template variables for `yadviapporder_confirmation`:
        {{1}}: Order ID (e.g. ORD-1149)
        {{2}}: Dealer name (e.g. Shree Seeds)
        {{3}}: Dealer mobile number
        {{4}}: Order date (e.g. 22 November 2026, formatted in IST)
        {{5}}: Product names and their respective quantities (e.g. Maize Hybrid – 2 kg, Cotton – 1 kg)
        {{6}}: Total quantity and number of varieties (e.g. 3 kg (2 varieties))
        """
        # Var 1: Order ID
        order_id_str = getattr(order, "order_number", "") or f"ORD-{getattr(order, 'id', '')}"

        # Var 2: Dealer name
        dealer_name = "Dealer"
        if getattr(order, "shop", None):
            dealer_name = (
                getattr(order.shop, "shop_name", None)
                or getattr(order.shop, "owner_name", None)
                or (order.shop.user.full_name if getattr(order.shop, "user", None) else None)
                or "Dealer"
            )

        # Var 3: Dealer mobile number
        dealer_mobile = "N/A"
        if getattr(order, "shop", None):
            dealer_mobile = (
                getattr(order.shop, "phone", None)
                or (order.shop.user.phone if getattr(order.shop, "user", None) else None)
                or "N/A"
            )
        cleaned_dealer_mobile = re.sub(r"[^\d]", "", dealer_mobile) if dealer_mobile != "N/A" else "N/A"

        # Var 4: Order date (in Asia/Kolkata IST)
        IST_OFFSET = timedelta(hours=5, minutes=30)
        order_dt = getattr(order, "created_at", None) or datetime.utcnow()
        ist_dt = order_dt + IST_OFFSET
        order_date_str = f"{ist_dt.day} {ist_dt.strftime('%B %Y')}"

        # Var 5: Product names and their respective quantities
        item_parts = []
        for it in items:
            p_name = None
            if getattr(it, "product", None) and getattr(it.product, "name", None):
                p_name = it.product.name
            elif getattr(it, "product_name", None):
                p_name = it.product_name
            p_name = p_name or f"Product #{getattr(it, 'product_id', 1)}"

            raw_qty = getattr(it, "quantity", None)
            if raw_qty is None:
                raw_qty = getattr(it, "quantity_bags", 0)
            unit = (getattr(it, "unit", "kg") or "kg").strip().lower()

            try:
                qty_float = float(raw_qty)
                qty_display = str(int(qty_float)) if qty_float.is_integer() else f"{qty_float:g}"
            except (ValueError, TypeError):
                qty_display = str(raw_qty)

            item_parts.append(f"{p_name} – {qty_display} {unit}")

        order_details_str = ", ".join(item_parts) if item_parts else "Standard Consignment"

        # Var 6: Total quantity and number of varieties
        num_varieties = len(items)
        variety_word = "variety" if num_varieties == 1 else "varieties"
        variety_str = f"{num_varieties} {variety_word}"

        tot_kg = getattr(order, "total_quantity_kg", None)
        if tot_kg is not None and float(tot_kg) > 0:
            tot_kg_f = float(tot_kg)
            tot_qty_display = str(int(tot_kg_f)) if tot_kg_f.is_integer() else f"{round(tot_kg_f, 3):g}"
            total_qty_str = f"{tot_qty_display} kg"
        else:
            # Fallback to sum of items
            total_qty_str = f"{num_varieties} units"

        total_quantity_var = f"{total_qty_str} ({variety_str})"

        return [
            order_id_str,
            dealer_name,
            cleaned_dealer_mobile,
            order_date_str,
            order_details_str,
            total_quantity_var,
        ]

    def check_template_status(self) -> Dict[str, Any]:
        """
        Queries Gupshup WhatsApp API to inspect the status of the `yadviapporder_confirmation` template.
        Returns status dict (APPROVED, PENDING, REJECTED, NOT_FOUND, or UNCONFIGURED).
        """
        if not self.api_key or not self.app_id:
            logger.info("Gupshup API key or App ID not configured. Cannot check live template status.")
            return {
                "success": False,
                "status": "UNCONFIGURED",
                "message": "GUPSHUP_API_KEY and GUPSHUP_APP_ID are required to check template status.",
                "template_name": self.template_name,
                "template_id": self.template_id,
            }

        url = self._get_app_template_url()
        headers = {
            "apikey": self.api_key,
            "Accept": "application/json",
        }

        try:
            with httpx.Client(timeout=self.timeout) as client:
                res = client.get(url, headers=headers)
                if res.status_code == 200:
                    data = res.json()
                    templates = data.get("templates", []) if isinstance(data, dict) else (data if isinstance(data, list) else [])
                    for t in templates:
                        if isinstance(t, dict) and t.get("elementName") == self.template_name or t.get("name") == self.template_name:
                            t_status = (t.get("status") or "").upper()
                            t_id = t.get("id")
                            logger.info(f"Gupshup template '{self.template_name}' status: {t_status} (id={t_id})")
                            return {
                                "success": True,
                                "status": t_status,
                                "template_id": t_id,
                                "template_name": self.template_name,
                                "category": t.get("category"),
                                "language": t.get("languageCode") or t.get("language"),
                                "message": f"Template status is {t_status}.",
                            }
                    return {
                        "success": False,
                        "status": "NOT_FOUND",
                        "template_name": self.template_name,
                        "message": f"Template '{self.template_name}' was not found in Gupshup app {self.app_id}.",
                    }
                else:
                    return {
                        "success": False,
                        "status": "HTTP_ERROR",
                        "http_status": res.status_code,
                        "message": f"Gupshup template list returned HTTP {res.status_code}.",
                    }
        except Exception as e:
            logger.error(f"Error querying Gupshup template status: {type(e).__name__}")
            return {
                "success": False,
                "status": "ERROR",
                "message": str(e),
            }

    def send_order_notification(self, order, items: list) -> Dict[str, Any]:
        """
        Dispatches the `yadviapporder_confirmation` WhatsApp template notification
        to the designated Admin recipient (GUPSHUP_ADMIN_RECIPIENT) using Gupshup API.

        Never crashes on failure; returns structured result.
        """
        if not self.dispatch_enabled:
            msg = "Gupshup WhatsApp dispatch is paused (GUPSHUP_DISPATCH_ENABLED=False)."
            logger.info(msg)
            return {
                "success": False,
                "status": "dispatch_paused",
                "message": msg,
                "message_id": None,
                "http_status": None,
                "recipient_masked": mask_phone_number(self.admin_recipient),
            }

        if not self.is_configured():
            if not self.api_key or not self.source_number or not self.admin_recipient:
                msg = "Gupshup WhatsApp integration is not configured. Missing required credentials or phone numbers."
            elif not self.app_name:
                msg = "GUPSHUP_APP_NAME is required for live Gupshup API dispatch (src.name)."
            elif not self.template_id:
                msg = "GUPSHUP_TEMPLATE_ID (approved template UUID) is required. Human-readable template name cannot be used as template ID."
            else:
                msg = "Gupshup WhatsApp integration is not configured."

            logger.warning(f"Gupshup WhatsApp dispatch aborted: {msg}")
            return {
                "success": False,
                "status": "unconfigured",
                "message": msg,
                "message_id": None,
                "http_status": None,
                "recipient_masked": mask_phone_number(self.admin_recipient),
            }

        source = sanitize_phone_number(self.source_number)
        destination = sanitize_phone_number(self.admin_recipient)
        masked_dest = mask_phone_number(destination)
        masked_src = mask_phone_number(source)

        if not source or not destination:
            logger.warning("Invalid source or destination phone number format for Gupshup WhatsApp.")
            return {
                "success": False,
                "status": "validation_error",
                "message": "Invalid source or destination phone number format.",
                "message_id": None,
                "http_status": None,
                "recipient_masked": masked_dest,
            }

        params = self.format_template_variables(order, items)

        # Strict: Gupshup /wa/api/v1/template/msg requires the approved template UUID
        template_obj = {
            "id": self.template_id,
            "params": params,
        }

        # Strict: src.name is required by Gupshup API for live WhatsApp dispatch
        form_payload = {
            "channel": "whatsapp",
            "source": source,
            "destination": destination,
            "src.name": self.app_name,
            "template": json.dumps(template_obj),
        }

        headers = {
            "apikey": self.api_key,
            "Content-Type": "application/x-www-form-urlencoded",
        }

        url = self._get_template_msg_url()

        logger.info(
            f"Dispatching Gupshup order WhatsApp notification for order {getattr(order, 'order_number', 'N/A')} "
            f"from {masked_src} to Admin {masked_dest}"
        )

        try:
            with httpx.Client(timeout=self.timeout) as client:
                res = client.post(url, data=form_payload, headers=headers)
                http_status = res.status_code

                try:
                    data = res.json()
                except Exception:
                    data = {"raw": res.text}

                # Gupshup returns status: "submitted" and messageId on success (HTTP 200 or 202)
                res_status = data.get("status", "").lower()
                message_id = data.get("messageId") or data.get("id")

                if http_status in (200, 202) and res_status in ("submitted", "success"):
                    logger.info(
                        f"Gupshup accepted order notification for {getattr(order, 'order_number', 'N/A')}. "
                        f"MessageId: {message_id}"
                    )
                    return {
                        "success": True,
                        "status": "submitted",
                        "message": "WhatsApp notification submitted to Gupshup queue.",
                        "message_id": message_id,
                        "http_status": http_status,
                        "recipient_masked": masked_dest,
                        "params": params,
                    }
                else:
                    err_msg = data.get("message") or data.get("error") or "Unknown Gupshup rejection"
                    err_code = data.get("code")
                    logger.warning(
                        f"Gupshup rejected WhatsApp message for order {getattr(order, 'order_number', 'N/A')}: "
                        f"status={res_status}, code={err_code}, message={err_msg}"
                    )
                    return {
                        "success": False,
                        "status": "rejected",
                        "message": f"Gupshup rejected: {err_msg}",
                        "error_code": err_code,
                        "message_id": message_id,
                        "http_status": http_status,
                        "recipient_masked": masked_dest,
                        "params": params,
                    }

        except httpx.TimeoutException:
            logger.error(f"Timeout while contacting Gupshup WhatsApp API for Admin {masked_dest}")
            return {
                "success": False,
                "status": "network_timeout",
                "message": "Connection to Gupshup WhatsApp API timed out.",
                "message_id": None,
                "http_status": None,
                "recipient_masked": masked_dest,
                "params": params,
            }
        except httpx.RequestError as exc:
            logger.error(f"Network error while contacting Gupshup WhatsApp API: {type(exc).__name__}")
            return {
                "success": False,
                "status": "network_error",
                "message": "Network error while connecting to Gupshup WhatsApp API.",
                "message_id": None,
                "http_status": None,
                "recipient_masked": masked_dest,
                "params": params,
            }
        except Exception as exc:
            logger.error(f"Unexpected error in Gupshup WhatsApp service: {type(exc).__name__}")
            return {
                "success": False,
                "status": "internal_error",
                "message": f"Unexpected error during WhatsApp notification: {str(exc)}",
                "message_id": None,
                "http_status": None,
                "recipient_masked": masked_dest,
                "params": params,
            }

    @staticmethod
    def process_webhook_event(event_data: dict, db) -> Dict[str, Any]:
        """
        Processes Gupshup WhatsApp delivery receipts (message-event callbacks).

        Supports status updates:
        - enqueued
        - sent
        - delivered
        - read
        - failed

        Maintains monotonic status ordering and records timestamp & error details.
        """
        STATUS_RANKS = {
            "submitted": 1,
            "enqueued": 1,
            "sent": 2,
            "delivered": 3,
            "read": 4,
            "failed": 0,
        }

        # Validate callback event structure
        event_type = (event_data.get("type") or "").strip().lower()

        # Handle system, platform, or probe events cleanly
        if event_type in ("connectivity-check", "platform-event", "health-check", "system-event"):
            logger.info(f"Acknowledged Gupshup {event_type} webhook callback cleanly.")
            return {"status": "acknowledged", "event_type": event_type}

        payload = event_data.get("payload", {})
        if not isinstance(payload, dict):
            return {"status": "ignored", "reason": "invalid_payload_format"}

        # Gupshup message event structure
        # payload.id: Gupshup message ID or WhatsApp wamid
        # payload.gsId: Gupshup message ID
        # payload.type: sent, delivered, read, failed, enqueued
        gs_id = payload.get("gsId")
        event_id = payload.get("id")
        status_raw = (payload.get("type") or "").strip().lower()

        if not status_raw:
            return {"status": "ignored", "reason": "missing_status_type"}

        if status_raw not in STATUS_RANKS:
            logger.info(f"Acknowledged unrecognized Gupshup status event '{status_raw}' without modification.")
            return {"status": "acknowledged", "reason": f"unknown_status_type_{status_raw}"}

        # Import Notification model dynamically to avoid circular dependencies
        from app.models.all_models import Notification

        # Find matching notification by gsId or event_id
        notif = None
        if gs_id:
            notif = db.query(Notification).filter(Notification.meta_message_id == gs_id).first()
        if not notif and event_id:
            notif = db.query(Notification).filter(Notification.meta_message_id == event_id).first()

        if not notif:
            logger.debug(f"No notification record found matching Gupshup message ID gsId={gs_id}, id={event_id}")
            return {"status": "not_found", "message_id": gs_id or event_id}

        current_status_lower = (notif.delivery_status or "submitted").lower()
        current_rank = STATUS_RANKS.get(current_status_lower, 1)
        new_rank = STATUS_RANKS.get(status_raw, 0)

        # Monotonic rule 1: Do not overwrite terminal 'Failed' with delayed 'sent' or 'enqueued'
        if current_status_lower == "failed" and status_raw in ("enqueued", "sent"):
            logger.info(
                f"Ignoring delayed '{status_raw}' event for notification {notif.id} "
                f"because it is already in terminal state 'Failed'."
            )
            return {"status": "ignored_already_failed"}

        # Monotonic rule 2: Do not overwrite confirmed 'delivered' or 'read' with late failure
        if status_raw == "failed" and current_status_lower in ("delivered", "read"):
            logger.warning(
                f"Ignoring delayed failure event for notification {notif.id} "
                f"because delivery was already confirmed ({notif.delivery_status})."
            )
            return {"status": "ignored_already_delivered"}

        if status_raw == "failed":
            notif.delivery_status = "Failed"
            notif.status = "Failed"
            inner_payload = payload.get("payload", {})
            if isinstance(inner_payload, dict):
                notif.meta_error_code = str(inner_payload.get("code") or "")
                notif.meta_error_message = str(inner_payload.get("reason") or inner_payload.get("message") or "")
            try:
                db.commit()
                logger.info(f"Gupshup notification {notif.id} marked Failed. Error: {notif.meta_error_code}")
                return {"status": "updated", "new_status": "Failed"}
            except Exception as e:
                db.rollback()
                logger.error(f"DB error updating failed status for notification {notif.id}: {e}")
                return {"status": "db_error"}

        elif new_rank > current_rank:
            capitalized = status_raw.capitalize()
            notif.delivery_status = capitalized
            if capitalized in ("Delivered", "Read"):
                notif.status = capitalized
            if status_raw == "delivered":
                notif.delivered_at = datetime.utcnow()
            elif status_raw == "read":
                notif.read_at = datetime.utcnow()

            try:
                db.commit()
                logger.info(f"Gupshup notification {notif.id} transitioned to {capitalized}")
                return {"status": "updated", "new_status": capitalized}
            except Exception as e:
                db.rollback()
                logger.error(f"DB error updating status for notification {notif.id}: {e}")
                return {"status": "db_error"}
        elif new_rank == current_rank:
            logger.info(
                f"Skipped duplicate status '{status_raw}' for notification {notif.id} "
                f"(current: {notif.delivery_status})"
            )
            return {"status": "duplicate", "current_status": notif.delivery_status}
        else:
            logger.info(
                f"Skipped lower precedence status '{status_raw}' for notification {notif.id} "
                f"(current: {notif.delivery_status})"
            )
            return {"status": "skipped_lower_rank", "current_status": notif.delivery_status}

    def enqueue_order_notification(self, db, order, items: list):
        """
        Creates a durable database-backed WhatsAppOutbox record committed in the same transaction as the Order.
        Guarantees idempotency via unique order_id constraint and existing dispatch checks.
        Does not perform synchronous HTTP calls.
        """
        from app.models.all_models import WhatsAppOutbox, Notification

        # Check if already in outbox
        existing_outbox = db.query(WhatsAppOutbox).filter(WhatsAppOutbox.order_id == order.id).first()
        if existing_outbox:
            return existing_outbox

        # Check if already dispatched in Notification table
        existing_notif = db.query(Notification).filter(
            Notification.order_number == order.order_number,
            Notification.channel == "WhatsApp",
            Notification.message_content.contains(self.template_name),
            Notification.status.in_(["Sent", "Delivered", "Read", "Submitted"]),
        ).first()
        if existing_notif:
            logger.info(f"Notification already recorded for order {order.order_number}. Skipping outbox enqueue.")
            return None

        params = self.format_template_variables(order, items)
        payload_dict = {
            "order_id": order.id,
            "order_number": order.order_number,
            "params": params,
            "shop_name": order.shop.shop_name if getattr(order, "shop", None) else "N/A",
            "total_bags": getattr(order, "total_quantity_bags", 0),
            "total_quantity_kg": getattr(order, "total_quantity_kg", 0.0),
            "recipient_phone": self.admin_recipient or "Admin",
        }

        outbox_entry = WhatsAppOutbox(
            order_id=order.id,
            order_number=order.order_number,
            recipient_phone=sanitize_phone_number(self.admin_recipient) or "Admin",
            template_id=self.template_id,
            template_name=self.template_name,
            payload_json=json.dumps(payload_dict),
            status="Pending",
            retry_count=0,
            max_retries=3,
            next_retry_at=datetime.utcnow(),
        )
        db.add(outbox_entry)
        logger.info(f"Enqueued durable WhatsApp outbox for order {order.order_number} to Admin.")
        return outbox_entry

    def send_from_outbox(self, outbox) -> Dict[str, Any]:
        """
        Sends a WhatsApp notification to Admin using parameters stored in a WhatsAppOutbox record.
        Never raises exceptions; returns structured result dict.
        """
        if not self.dispatch_enabled:
            msg = "Gupshup WhatsApp dispatch is paused (GUPSHUP_DISPATCH_ENABLED=False)."
            logger.info(f"Outbox #{getattr(outbox, 'id', 'N/A')}: {msg}")
            return {
                "success": False,
                "status": "dispatch_paused",
                "message": msg,
                "message_id": None,
                "http_status": None,
                "recipient_masked": mask_phone_number(self.admin_recipient),
            }

        if not self.is_configured():
            if not self.api_key or not self.source_number or not self.admin_recipient:
                msg = "Gupshup WhatsApp integration is not configured. Missing required credentials or phone numbers."
            elif not self.app_name:
                msg = "GUPSHUP_APP_NAME is required for live Gupshup API dispatch (src.name)."
            elif not self.template_id:
                msg = "GUPSHUP_TEMPLATE_ID (approved template UUID) is required. Human-readable template name cannot be used as template ID."
            else:
                msg = "Gupshup WhatsApp integration is not configured."

            logger.warning(f"Gupshup outbox dispatch aborted for order {outbox.order_number}: {msg}")
            return {
                "success": False,
                "status": "unconfigured",
                "message": msg,
                "message_id": None,
                "http_status": None,
                "recipient_masked": mask_phone_number(self.admin_recipient),
            }

        try:
            data = json.loads(outbox.payload_json)
        except Exception as e:
            return {
                "success": False,
                "status": "invalid_payload",
                "message": f"Malformed outbox payload JSON: {e}",
                "message_id": None,
                "http_status": None,
                "recipient_masked": mask_phone_number(self.admin_recipient),
            }

        params = data.get("params", [])
        source = sanitize_phone_number(self.source_number)
        destination = sanitize_phone_number(self.admin_recipient)
        masked_dest = mask_phone_number(destination)
        masked_src = mask_phone_number(source)

        if not source or not destination:
            return {
                "success": False,
                "status": "validation_error",
                "message": "Invalid source or destination phone number format.",
                "message_id": None,
                "http_status": None,
                "recipient_masked": masked_dest,
            }

        template_obj = {
            "id": self.template_id,
            "params": params,
        }
        form_payload = {
            "channel": "whatsapp",
            "source": source,
            "destination": destination,
            "src.name": self.app_name,
            "template": json.dumps(template_obj),
        }
        headers = {
            "apikey": self.api_key,
            "Content-Type": "application/x-www-form-urlencoded",
        }
        url = self._get_template_msg_url()

        logger.info(
            f"Dispatching Gupshup WhatsApp notification from outbox #{outbox.id} for order {outbox.order_number} "
            f"from {masked_src} to Admin {masked_dest}"
        )

        try:
            with httpx.Client(timeout=self.timeout) as client:
                res = client.post(url, data=form_payload, headers=headers)
                http_status = res.status_code
                try:
                    res_data = res.json()
                except Exception:
                    res_data = {"raw": res.text}

                res_status = res_data.get("status", "").lower()
                message_id = res_data.get("messageId") or res_data.get("id")

                if http_status in (200, 202) and res_status in ("submitted", "success"):
                    logger.info(f"Gupshup accepted outbox notification for {outbox.order_number}. MsgId: {message_id}")
                    return {
                        "success": True,
                        "status": "submitted",
                        "message": "WhatsApp notification submitted to Gupshup queue.",
                        "message_id": message_id,
                        "http_status": http_status,
                        "recipient_masked": masked_dest,
                        "params": params,
                    }
                else:
                    err_msg = res_data.get("message") or res_data.get("error") or "Unknown Gupshup rejection"
                    err_code = res_data.get("code")
                    logger.warning(
                        f"Gupshup rejected outbox notification for {outbox.order_number}: "
                        f"status={res_status}, code={err_code}, message={err_msg}"
                    )
                    return {
                        "success": False,
                        "status": "rejected",
                        "message": f"Gupshup rejected: {err_msg}",
                        "error_code": err_code,
                        "message_id": message_id,
                        "http_status": http_status,
                        "recipient_masked": masked_dest,
                        "params": params,
                    }
        except httpx.TimeoutException:
            logger.error(f"Timeout while contacting Gupshup WhatsApp API for outbox #{outbox.id}")
            return {
                "success": False,
                "status": "network_timeout",
                "message": "Connection to Gupshup WhatsApp API timed out.",
                "message_id": None,
                "http_status": None,
                "recipient_masked": masked_dest,
                "params": params,
            }
        except httpx.RequestError as exc:
            logger.error(f"Network error while contacting Gupshup WhatsApp API for outbox #{outbox.id}: {type(exc).__name__}")
            return {
                "success": False,
                "status": "network_error",
                "message": f"Network error while connecting to Gupshup WhatsApp API: {type(exc).__name__}",
                "message_id": None,
                "http_status": None,
                "recipient_masked": masked_dest,
                "params": params,
            }
        except Exception as exc:
            logger.error(f"Unexpected error in Gupshup outbox dispatch #{outbox.id}: {type(exc).__name__}")
            return {
                "success": False,
                "status": "internal_error",
                "message": f"Unexpected error during WhatsApp notification: {str(exc)}",
                "message_id": None,
                "http_status": None,
                "recipient_masked": masked_dest,
                "params": params,
            }

    def _claim_pending_records(self, db, max_batch: int = 10) -> List[int]:
        """
        Atomically claims up to max_batch pending, retry, or stale processing records.
        Sets status = 'Processing' and locked_at = now inside a short, dedicated transaction,
        and commits immediately before returning the list of claimed IDs.

        Concurrency & Locking Strategy:
        - MySQL 8.0 (Production): Uses `with_for_update(skip_locked=True)` so concurrent Cloud Run
          worker instances instantly skip rows already locked by another transaction without blocking.
        - Dialect Fallback (e.g. SQLite in unit tests): Uses atomic conditional UPDATE
          (Compare-and-Swap) to verify status has not transitioned before claiming.

        Guarantees:
        - Two Cloud Run instances or concurrent workers will NEVER claim or dispatch the same record.
        - Database locks are released immediately upon claim commit, NEVER held during
          outbound HTTP calls to Gupshup.
        - Stale locks (> 5 minutes) from killed/crashed workers are automatically reclaimed.
        """
        from app.models.all_models import WhatsAppOutbox
        from sqlalchemy import or_, and_, update

        now = datetime.utcnow()
        stale_threshold = now - timedelta(minutes=5)

        dialect_name = ""
        try:
            if db.bind:
                dialect_name = getattr(db.bind.dialect, "name", "").lower()
        except Exception:
            pass

        claimed_ids = []

        # Strategy A: MySQL 8.0 Native Row Locking with SKIP LOCKED
        if dialect_name == "mysql":
            try:
                candidates = (
                    db.query(WhatsAppOutbox)
                    .filter(
                        or_(
                            and_(
                                WhatsAppOutbox.status.in_(["Pending", "Retry"]),
                                WhatsAppOutbox.next_retry_at <= now,
                            ),
                            and_(
                                WhatsAppOutbox.status == "Processing",
                                WhatsAppOutbox.locked_at <= stale_threshold,
                            ),
                        )
                    )
                    .order_by(WhatsAppOutbox.id.asc())
                    .limit(max_batch)
                    .with_for_update(skip_locked=True)
                    .all()
                )

                for item in candidates:
                    item.status = "Processing"
                    item.locked_at = now
                    claimed_ids.append(item.id)

                db.commit()
                return claimed_ids
            except Exception as exc:
                db.rollback()
                logger.warning(f"MySQL SKIP LOCKED query failed, falling back to atomic CAS: {exc}")

        # Strategy B: Atomic Compare-and-Swap (CAS) Claim (Universal / SQLite / Fallback)
        candidate_rows = (
            db.query(WhatsAppOutbox.id, WhatsAppOutbox.status, WhatsAppOutbox.locked_at)
            .filter(
                or_(
                    and_(
                        WhatsAppOutbox.status.in_(["Pending", "Retry"]),
                        WhatsAppOutbox.next_retry_at <= now,
                    ),
                    and_(
                        WhatsAppOutbox.status == "Processing",
                        WhatsAppOutbox.locked_at <= stale_threshold,
                    ),
                )
            )
            .order_by(WhatsAppOutbox.id.asc())
            .limit(max_batch)
            .all()
        )

        for cand_id, cand_status, cand_locked_at in candidate_rows:
            try:
                # Build strict CAS condition matching exact observed state:
                # - For Pending/Retry: status must still equal observed status, and next_retry_at <= now.
                # - For Stale Processing: locked_at must strictly equal the previously observed
                #   locked_at timestamp AND still satisfy the stale threshold.
                # This guarantees that if two workers simultaneously observe the same stale row,
                # only the first to commit will match locked_at == cand_locked_at; the second worker's
                # CAS will find rowcount == 0 and skip it.
                if cand_status in ("Pending", "Retry"):
                    cas_condition = and_(
                        WhatsAppOutbox.status == cand_status,
                        WhatsAppOutbox.next_retry_at <= now,
                    )
                else:  # cand_status == "Processing"
                    cas_condition = and_(
                        WhatsAppOutbox.status == "Processing",
                        WhatsAppOutbox.locked_at == cand_locked_at,
                        WhatsAppOutbox.locked_at <= stale_threshold,
                    )

                stmt = (
                    update(WhatsAppOutbox)
                    .where(
                        WhatsAppOutbox.id == cand_id,
                        cas_condition,
                    )
                    .values(status="Processing", locked_at=now)
                )
                res = db.execute(stmt)
                if res.rowcount and res.rowcount > 0:
                    claimed_ids.append(cand_id)
                    db.commit()
            except Exception as e:
                db.rollback()
                logger.error(f"Error executing atomic CAS claim on outbox #{cand_id}: {e}")

        return claimed_ids

    def process_outbox_queue(self, db, max_batch: int = 10) -> Dict[str, Any]:
        """
        Processes pending and retry WhatsAppOutbox items with atomic claiming,
        bounded retries, exponential backoff, and idempotency protection.

        Delivery Semantics:
        - Guarantees at-least-once delivery to Admin.
        - Exactly-once delivery cannot be guaranteed across external API boundaries
          due to potential network timeouts or process crashes after Gupshup receives
          the payload but before local DB commit.
        - Unsafe infinite retries are strictly bounded by `max_retries` (default 3)
          with exponential backoff (2^retry_count * 5s) before transitioning to
          terminal 'Failed'.
        """
        from app.models.all_models import WhatsAppOutbox, Notification

        # Safe feature flag check: if WhatsApp dispatch is paused, do not claim records
        if not self.dispatch_enabled:
            logger.info("Gupshup WhatsApp outbox processing skipped: dispatch is paused (GUPSHUP_DISPATCH_ENABLED=False).")
            return {
                "total_candidates": 0,
                "dispatched": 0,
                "failed": 0,
                "retried": 0,
                "skipped_duplicate": 0,
                "paused": True,
            }

        # Phase 1: Atomically claim a batch of records in a short transaction
        claimed_ids = self._claim_pending_records(db=db, max_batch=max_batch)

        summary = {
            "total_candidates": len(claimed_ids),
            "dispatched": 0,
            "failed": 0,
            "retried": 0,
            "skipped_duplicate": 0,
        }

        # Phase 2: Process each claimed record individually without holding DB table/row locks
        for item_id in claimed_ids:
            item = db.query(WhatsAppOutbox).filter(WhatsAppOutbox.id == item_id).first()
            if not item:
                continue

            try:
                # Idempotency check: has this order already been dispatched?
                existing_sent = db.query(Notification).filter(
                    Notification.order_number == item.order_number,
                    Notification.channel == "WhatsApp",
                    Notification.message_content.contains(item.template_name),
                    Notification.status.in_(["Sent", "Delivered", "Read", "Submitted"]),
                ).first()

                if existing_sent:
                    logger.info(f"Outbox #{item.id} (Order {item.order_number}) already has dispatched notification. Marking Dispatched.")
                    item.status = "Dispatched"
                    item.locked_at = None
                    item.last_error = None
                    db.commit()
                    summary["skipped_duplicate"] += 1
                    continue

                # External HTTP call to Gupshup (executed with NO DB row locks held)
                res = self.send_from_outbox(item)
                is_success = res.get("success", False)

                if is_success:
                    item.status = "Dispatched"
                    item.locked_at = None
                    item.last_error = None
                    msg_id = res.get("message_id")
                    params_repr = json.dumps(res.get("params", []))

                    payload_data = {}
                    try:
                        payload_data = json.loads(item.payload_json)
                    except Exception:
                        pass

                    db_notif = Notification(
                        recipient_phone=item.recipient_phone,
                        channel="WhatsApp",
                        order_number=item.order_number,
                        shop_name=payload_data.get("shop_name", "N/A"),
                        total_bags=payload_data.get("total_bags"),
                        total_quantity_kg=payload_data.get("total_quantity_kg"),
                        status="Sent",
                        meta_message_id=msg_id,
                        delivery_status="Submitted",
                        meta_error_code=None,
                        meta_error_message=None,
                        message_content=f"Template: {item.template_name} | Params: {params_repr}",
                    )
                    db.add(db_notif)
                    db.commit()
                    summary["dispatched"] += 1
                    logger.info(f"Outbox #{item.id} successfully dispatched (MsgId: {msg_id})")
                else:
                    item.retry_count += 1
                    err_msg = res.get("message") or "Unknown error"
                    err_code = str(res.get("error_code") or "")
                    item.last_error = f"{res.get('status')}: {err_msg}"
                    item.locked_at = None

                    if item.retry_count >= item.max_retries:
                        item.status = "Failed"
                        payload_data = {}
                        try:
                            payload_data = json.loads(item.payload_json)
                        except Exception:
                            pass

                        db_notif = Notification(
                            recipient_phone=item.recipient_phone,
                            channel="WhatsApp",
                            order_number=item.order_number,
                            shop_name=payload_data.get("shop_name", "N/A"),
                            total_bags=payload_data.get("total_bags"),
                            total_quantity_kg=payload_data.get("total_quantity_kg"),
                            status="Failed",
                            meta_message_id=None,
                            delivery_status="Failed",
                            meta_error_code=err_code if err_code else None,
                            meta_error_message=item.last_error,
                            message_content=f"Template: {item.template_name} | Outbox #{item.id} reached max retries ({item.max_retries})",
                        )
                        db.add(db_notif)
                        db.commit()
                        summary["failed"] += 1
                        logger.warning(f"Outbox #{item.id} marked Failed after {item.retry_count} attempts.")
                    else:
                        item.status = "Retry"
                        backoff_sec = (2 ** item.retry_count) * 5
                        item.next_retry_at = datetime.utcnow() + timedelta(seconds=backoff_sec)
                        db.commit()
                        summary["retried"] += 1
                        logger.info(f"Outbox #{item.id} scheduled for retry #{item.retry_count} in {backoff_sec}s.")

            except Exception as exc:
                db.rollback()
                logger.error(f"Error processing outbox item #{item.id}: {exc}")
                try:
                    item.locked_at = None
                    item.retry_count += 1
                    item.status = "Retry" if item.retry_count < item.max_retries else "Failed"
                    item.last_error = f"Unhandled worker exception: {type(exc).__name__}"
                    db.commit()
                except Exception:
                    db.rollback()

        return summary


gupshup_whatsapp_service = GupshupWhatsAppService()


def run_outbox_worker_safe() -> Dict[str, Any]:
    """
    Standalone safe worker function suitable for FastAPI BackgroundTasks, thread execution,
    or startup hooks.
    Creates a dedicated DB session and closes it cleanly.
    """
    from app.core.database import SessionLocal
    db = SessionLocal()
    try:
        return gupshup_whatsapp_service.process_outbox_queue(db=db)
    except Exception as e:
        logger.error(f"Background outbox worker error: {e}")
        return {"error": str(e)}
    finally:
        db.close()

