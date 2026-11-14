import os
import logging
import firebase_admin
from firebase_admin import credentials
from app.core.config import settings

logger = logging.getLogger(__name__)

def is_firebase_initialized() -> bool:
    """Checks whether Firebase Admin SDK is currently initialized."""
    return len(firebase_admin._apps) > 0


def init_firebase() -> bool:
    """
    Initializes the Firebase Admin SDK securely.
    1. If already initialized, returns True immediately.
    2. If FIREBASE_CREDENTIALS_PATH points to an existing file, initializes using the certificate.
    3. If running in a cloud/production environment (K_SERVICE, GAE_INSTANCE, or ENVIRONMENT=production/staging),
       attempts initialization using Google Application Default Credentials (ADC).
    4. If credentials are not configured in local development, degrades safely and returns False without raising.
    5. Never logs raw credential contents or secret keys.
    """
    if is_firebase_initialized():
        logger.info("Firebase Admin SDK already initialized.")
        return True

    cred_path = getattr(settings, "FIREBASE_CREDENTIALS_PATH", None)

    # 1. Local file certificate
    if cred_path and os.path.isfile(cred_path):
        try:
            logger.info("Initializing Firebase Admin SDK using configured service-account certificate...")
            cred = credentials.Certificate(cred_path)
            firebase_admin.initialize_app(cred)
            logger.info("Firebase Admin SDK initialized successfully with service-account certificate.")
            return True
        except Exception as e:
            logger.error(f"Failed to initialize Firebase Admin SDK from certificate: {e}")
            raise RuntimeError(f"Firebase certificate initialization failed: {e}") from e

    # 2. Cloud Run / GCP Application Default Credentials (ADC)
    is_cloud_or_prod = bool(
        os.getenv("K_SERVICE")
        or os.getenv("GAE_INSTANCE")
        or getattr(settings, "ENVIRONMENT", "").lower() in ("production", "staging")
    )

    if is_cloud_or_prod:
        try:
            logger.info("Initializing Firebase Admin SDK using Application Default Credentials (ADC)...")
            firebase_admin.initialize_app()
            logger.info("Firebase Admin SDK initialized successfully with ADC.")
            return True
        except Exception as e:
            logger.warning(f"Firebase ADC initialization failed in cloud environment: {e}")
            raise RuntimeError(f"Firebase ADC initialization error: {e}") from e

    # 3. Development graceful degradation
    logger.info("Firebase credentials file not configured; push notifications disabled for local development.")
    return False


def sync_firebase_phone(old_phone: str, new_phone: str) -> None:
    """
    Synchronizes mobile number changes with Firebase Auth.
    If the old phone exists in Firebase, updates it to the new phone.
    If the user has never logged in (no Firebase account yet), handles gracefully.
    """
    if not is_firebase_initialized():
        init_firebase()
    if not is_firebase_initialized():
        logger.info("Firebase Admin not initialized; skipping phone sync.")
        return

    try:
        from firebase_admin import auth as fb_auth
        if not old_phone or not new_phone:
            return
        norm_old = f"+91{old_phone.strip()[-10:]}"
        norm_new = f"+91{new_phone.strip()[-10:]}"
        
        if norm_old == norm_new:
            return

        try:
            fb_user = fb_auth.get_user_by_phone_number(norm_old)
        except Exception:
            logger.info(f"User with phone {norm_old} not found in Firebase Auth; will be created on next OTP login.")
            return

        try:
            existing = fb_auth.get_user_by_phone_number(norm_new)
            if existing and existing.uid != fb_user.uid:
                logger.warning(f"Phone {norm_new} is already linked to another Firebase user {existing.uid}.")
                return
        except Exception:
            pass

        fb_auth.update_user(fb_user.uid, phone_number=norm_new)
        logger.info(f"Successfully updated Firebase Auth phone number for UID {fb_user.uid} from {norm_old} to {norm_new}")
    except Exception as e:
        logger.warning(f"Error syncing phone number to Firebase Auth: {e}")
