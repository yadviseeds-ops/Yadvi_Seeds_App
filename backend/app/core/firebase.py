import os
import logging
import firebase_admin
from firebase_admin import credentials
from app.core.config import settings

logger = logging.getLogger(__name__)

def init_firebase():
    """Initializes the Firebase Admin SDK securely."""
    # Check if already initialized to prevent duplicate app errors
    if len(firebase_admin._apps) > 0:
        logger.info("Firebase Admin SDK already initialized.")
        return

    cred_path = settings.FIREBASE_CREDENTIALS_PATH
    if not cred_path or not os.path.exists(cred_path):
        logger.error(f"Firebase credentials not found at {cred_path}.")
        raise FileNotFoundError(
            f"Firebase Admin initialization failed. Credentials file missing at: {cred_path}"
        )

    try:
        cred = credentials.Certificate(cred_path)
        firebase_admin.initialize_app(cred)
        logger.info("Firebase Admin SDK initialized successfully.")
    except Exception as e:
        logger.error(f"Failed to initialize Firebase Admin SDK: {e}")
        raise RuntimeError(f"Firebase Admin SDK configuration error: {e}")
