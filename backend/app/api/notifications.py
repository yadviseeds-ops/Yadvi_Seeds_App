import secrets
import hmac
import hashlib
import json
import logging
from datetime import datetime
from typing import Optional, Any
from fastapi import APIRouter, Depends, HTTPException, status, Query, Request, Header
from fastapi.responses import PlainTextResponse
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.config import settings
from app.core.security import require_role
from app.models.all_models import User, Notification
from app.core.whatsapp import whatsapp_service, mask_phone_number
from app.services.whatsapp_service import gupshup_whatsapp_service

logger = logging.getLogger("yadvi_webhook")

router = APIRouter(prefix="/notifications", tags=["Notifications & Alerts"])


class TestWhatsAppResponse(BaseModel):
    success: bool
    status: str
    message: str
    http_status: Optional[int] = None
    meta_message_id: Optional[str] = None
    recipient_masked: Optional[str] = None
    error_code: Optional[Any] = None


@router.post(
    "/test-whatsapp",
    response_model=TestWhatsAppResponse,
    summary="Controlled Meta WhatsApp Cloud API Test",
    description="Sends the official 'hello_world' test template strictly to the configured WHATSAPP_TEST_RECIPIENT. Administrator only."
)
def test_whatsapp_notification(
    current_user: User = Depends(require_role(["administrator"]))
):
    """
    Test endpoint for Meta WhatsApp Cloud API integration.

    Security & Control guarantees:
    - Restricted exclusively to authenticated users with role 'administrator'.
    - Does NOT accept request body parameters for phone number, token, or arbitrary message content.
    - Sends solely to WHATSAPP_TEST_RECIPIENT defined in backend environment.
    - Employs official Meta 'hello_world' template in en_US.
    - Never prints or reveals access tokens or full sensitive recipient information.
    - Returns structured status (accepted vs rejected/error) without claiming delivery.
    """
    result = whatsapp_service.send_template_test(template_name="hello_world", language_code="en_US")

    return TestWhatsAppResponse(
        success=result.get("success", False),
        status=result.get("status", "unknown"),
        message=result.get("message", ""),
        http_status=result.get("http_status"),
        meta_message_id=result.get("meta_message_id"),
        recipient_masked=result.get("recipient_masked"),
        error_code=result.get("error_code")
    )


@router.get(
    "/webhook",
    summary="Meta WhatsApp Webhook Verification Handshake",
    description="Handles Meta's hub.challenge verification handshake during webhook registration."
)
def verify_whatsapp_webhook(
    hub_mode: Optional[str] = Query(None, alias="hub.mode"),
    hub_challenge: Optional[str] = Query(None, alias="hub.challenge"),
    hub_verify_token: Optional[str] = Query(None, alias="hub.verify_token")
):
    """
    Verifies Meta's subscription handshake.
    Returns hub.challenge as raw plain text with HTTP 200 upon token match.
    """
    expected_token = getattr(settings, "WHATSAPP_WEBHOOK_VERIFY_TOKEN", None)
    if not expected_token:
        logger.warning("WHATSAPP_WEBHOOK_VERIFY_TOKEN is not configured in backend settings.")
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Webhook verification token not configured on server"
        )

    if hub_mode == "subscribe" and secrets.compare_digest(hub_verify_token or "", expected_token):
        logger.info("Meta WhatsApp webhook challenge successfully verified.")
        return PlainTextResponse(content=hub_challenge or "", status_code=200)

    logger.warning("Meta WhatsApp webhook challenge verification rejected: invalid token or mode.")
    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="Verification handshake failed"
    )


STATUS_RANKS = {
    "accepted": 1,
    "sent": 2,
    "delivered": 3,
    "read": 4,
    "failed": 0
}


@router.post(
    "/webhook",
    summary="Meta WhatsApp Status & Delivery Callback",
    description="Receives message delivery status receipts (sent, delivered, read, failed) from Meta."
)
async def process_whatsapp_webhook(
    request: Request,
    db: Session = Depends(get_db),
    x_hub_signature_256: Optional[str] = Header(None, alias="X-Hub-Signature-256")
):
    """
    Processes asynchronous delivery status updates from Meta WhatsApp Cloud API.
    Guarantees:
    - Signature verification when WHATSAPP_APP_SECRET is set.
    - Idempotent and monotonic state transitions (Accepted -> Sent -> Delivered -> Read).
    - Captures error codes (e.g. 131047 for closed 24h window).
    - Never leaks sensitive data in logs.
    - Returns HTTP 200 immediately.
    """
    raw_body = await request.body()

    # Verify HMAC SHA-256 signature
    app_secret = getattr(settings, "WHATSAPP_APP_SECRET", None)
    allow_insecure = getattr(settings, "WHATSAPP_ALLOW_INSECURE_WEBHOOKS", False)

    if not app_secret:
        if not allow_insecure:
            logger.error("WHATSAPP_APP_SECRET is not configured on server. Rejecting webhook POST (fail-closed).")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Webhook security configuration missing on server (WHATSAPP_APP_SECRET required)"
            )
        logger.warning("DEVELOPMENT OVERRIDE: WHATSAPP_ALLOW_INSECURE_WEBHOOKS is True. Bypassing signature check.")
    else:
        if not x_hub_signature_256 or not x_hub_signature_256.startswith("sha256="):
            logger.warning("Missing or malformed X-Hub-Signature-256 header on WhatsApp webhook.")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Missing or invalid signature header"
            )

        expected_sig = hmac.new(app_secret.encode("utf-8"), raw_body, hashlib.sha256).hexdigest()
        provided_sig = x_hub_signature_256.replace("sha256=", "").strip()
        if not secrets.compare_digest(provided_sig, expected_sig):
            logger.warning("X-Hub-Signature-256 mismatch on WhatsApp webhook.")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid webhook signature"
            )

    try:
        data = json.loads(raw_body.decode("utf-8") if raw_body else "{}")
    except Exception:
        return {"status": "ignored_invalid_json"}

    for entry in data.get("entry", []):
        for change in entry.get("changes", []):
            val = change.get("value", {})
            statuses = val.get("statuses", [])

            for st in statuses:
                wamid = st.get("id")
                meta_status = (st.get("status") or "").lower()
                recipient_id = st.get("recipient_id", "")
                masked_recip = mask_phone_number(recipient_id) if recipient_id else "Unknown"
                errors = st.get("errors", [])

                logger.info(f"Meta webhook event: wamid={wamid}, status={meta_status}, recipient={masked_recip}")

                if not wamid:
                    continue

                notif = db.query(Notification).filter(Notification.meta_message_id == wamid).first()
                if not notif:
                    logger.debug(f"No notification record found matching meta_message_id {wamid}")
                    continue

                current_status_lower = (notif.delivery_status or "accepted").lower()
                current_rank = STATUS_RANKS.get(current_status_lower, 1)
                new_rank = STATUS_RANKS.get(meta_status, 0)

                # Rule 1: Delayed 'sent' events must NOT overwrite 'Failed'
                if current_status_lower == "failed" and meta_status == "sent":
                    logger.info(
                        f"Ignoring delayed 'sent' event for order {notif.order_number} (wamid={wamid}) "
                        f"because notification is already in terminal state 'Failed'."
                    )
                    continue

                # Rule 2: Delayed 'failed' events must NOT overwrite 'Delivered' or 'Read'
                if meta_status == "failed":
                    if current_status_lower in ["delivered", "read"]:
                        logger.warning(
                            f"Ignoring delayed failure event for order {notif.order_number} (wamid={wamid}) "
                            f"because message delivery was already confirmed ({notif.delivery_status})."
                        )
                        continue

                    notif.delivery_status = "Failed"
                    notif.status = "Failed"
                    if errors and isinstance(errors, list):
                        err0 = errors[0]
                        notif.meta_error_code = err0.get("code")
                        safe_msg = str(err0.get("title") or err0.get("message") or "")
                        notif.meta_error_message = safe_msg
                    try:
                        db.commit()
                        logger.info(f"Notification {notif.id} ({notif.order_number}) marked Failed. Error code: {notif.meta_error_code}")
                    except Exception as e:
                        db.rollback()
                        logger.error(f"Database error saving failed status for {notif.order_number}: {e}")

                elif new_rank > current_rank:
                    capitalized = meta_status.capitalize()
                    notif.delivery_status = capitalized
                    if capitalized in ["Delivered", "Read"]:
                        notif.status = capitalized
                    if meta_status == "delivered":
                        notif.delivered_at = datetime.utcnow()
                    elif meta_status == "read":
                        notif.read_at = datetime.utcnow()
                    try:
                        db.commit()
                        logger.info(f"Notification {notif.id} ({notif.order_number}) transitioned to {capitalized}")
                    except Exception as e:
                        db.rollback()
                        logger.error(f"Database error updating status for {notif.order_number}: {e}")
                else:
                    logger.info(
                        f"Skipped duplicate or lower precedence status '{meta_status}' for {notif.order_number} "
                        f"(current: {notif.delivery_status})"
                    )

    return {"status": "ok"}


@router.get(
    "/gupshup-webhook",
    summary="Gupshup Webhook Verification Probe",
    description="Endpoint accessibility check for Gupshup webhook registration."
)
def verify_gupshup_webhook():
    return {"status": "ok", "service": "Gupshup WhatsApp Webhook", "timestamp": datetime.utcnow().isoformat()}


@router.post(
    "/gupshup-webhook",
    summary="Gupshup WhatsApp Status & Delivery Callback",
    description="Processes asynchronous delivery receipts (enqueued, sent, delivered, read, failed) from Gupshup."
)
async def process_gupshup_webhook(
    request: Request,
    db: Session = Depends(get_db),
    x_gupshup_signature: Optional[str] = Header(None, alias="X-Gupshup-Signature")
):
    """
    Receives DLR (delivery receipt) and event callbacks from Gupshup.
    Guarantees:
    - Safe non-blocking execution.
    - Verified secret check if GUPSHUP_WEBHOOK_SECRET is configured (via query token, secret param, or header).
    - Matches Gupshup messageId / gsId / id to Notification.meta_message_id.
    - Enforces monotonic status transitions.
    - Handles duplicate callbacks idempotently.
    - Records delivered_at, read_at, error codes and sanitized reasons.
    - Always responds promptly with HTTP 200.
    """
    raw_body = await request.body()
    secret = getattr(settings, "GUPSHUP_WEBHOOK_SECRET", None)
    if secret:
        # Check query param token/secret, or header token/signature
        provided_token = (
            request.query_params.get("secret")
            or request.query_params.get("token")
            or request.headers.get("token")
            or request.headers.get("Authorization")
            or x_gupshup_signature
        )

        valid = False
        if provided_token:
            # Check direct token match
            if secrets.compare_digest(provided_token.strip(), secret):
                valid = True
            # Or HMAC SHA-256 signature if provided
            else:
                expected_sig = hmac.new(secret.encode("utf-8"), raw_body, hashlib.sha256).hexdigest()
                clean_sig = provided_token.replace("sha256=", "").strip()
                if secrets.compare_digest(clean_sig, expected_sig):
                    valid = True

        if not valid:
            logger.warning("Unauthorized Gupshup webhook callback attempt: secret or signature mismatch.")
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid webhook authentication")

    try:
        data = json.loads(raw_body.decode("utf-8") if raw_body else "{}")
    except Exception:
        return {"status": "ignored", "reason": "invalid_json"}

    result = gupshup_whatsapp_service.process_webhook_event(data, db)
    return {"status": "ok", "result": result}


@router.post(
    "/gupshup/process-outbox",
    summary="Process Pending Gupshup WhatsApp Outbox Queue",
    description="Manually triggers processing of pending and retry outbox messages with exponential backoff. Admin only."
)
def process_gupshup_outbox(
    max_batch: int = Query(10, ge=1, le=50),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["administrator"]))
):
    """
    Triggers the outbox worker loop to dispatch pending notifications to Gupshup.
    Admin restricted.
    """
    summary = gupshup_whatsapp_service.process_outbox_queue(db=db, max_batch=max_batch)
    return {"success": True, "summary": summary}


@router.get(
    "/gupshup/outbox-status",
    summary="Inspect Gupshup WhatsApp Outbox Queue Status",
    description="Returns aggregate counts of pending, processing, dispatched, failed, and retrying outbox messages. Admin only."
)
def get_gupshup_outbox_status(
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role(["administrator"]))
):
    """
    Returns outbox queue metrics. Admin restricted.
    """
    from app.models.all_models import WhatsAppOutbox
    from sqlalchemy import func

    status_counts = (
        db.query(WhatsAppOutbox.status, func.count(WhatsAppOutbox.id))
        .group_by(WhatsAppOutbox.status)
        .all()
    )
    counts_dict = {st: count for st, count in status_counts}
    total = sum(counts_dict.values())

    return {
        "total_outbox_records": total,
        "pending": counts_dict.get("Pending", 0),
        "processing": counts_dict.get("Processing", 0),
        "retry": counts_dict.get("Retry", 0),
        "dispatched": counts_dict.get("Dispatched", 0),
        "failed": counts_dict.get("Failed", 0),
    }


@router.get(
    "/gupshup/template-status",
    summary="Inspect Gupshup WhatsApp Template Approval Status",
    description="Checks whether the yadviapporder_confirmation template is APPROVED, PENDING, or REJECTED. Admin only."
)
def get_gupshup_template_status(
    current_user: User = Depends(require_role(["administrator"]))
):
    """
    Inspects Gupshup template approval status for `yadviapporder_confirmation`.
    Restricted to Administrator role.
    """
    return gupshup_whatsapp_service.check_template_status()


@router.get(
    "/gupshup/config-status",
    summary="Check Gupshup Configuration Status",
    description="Inspects whether Gupshup credentials and sender/recipient numbers are configured without exposing secrets. Admin only."
)
def get_gupshup_config_status(
    current_user: User = Depends(require_role(["administrator"]))
):
    """
    Returns masked Gupshup configuration status. Never reveals API keys.
    """
    return {
        "configured": gupshup_whatsapp_service.is_configured(),
        "has_api_key": bool(gupshup_whatsapp_service.api_key),
        "has_source_number": bool(gupshup_whatsapp_service.source_number),
        "source_number_masked": mask_phone_number(gupshup_whatsapp_service.source_number),
        "has_admin_recipient": bool(gupshup_whatsapp_service.admin_recipient),
        "admin_recipient_masked": mask_phone_number(gupshup_whatsapp_service.admin_recipient),
        "app_id": gupshup_whatsapp_service.app_id,
        "app_name": gupshup_whatsapp_service.app_name,
        "template_name": gupshup_whatsapp_service.template_name,
        "template_id": gupshup_whatsapp_service.template_id,
        "template_lang": gupshup_whatsapp_service.template_lang,
    }
