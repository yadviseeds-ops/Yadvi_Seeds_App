import os
from pydantic_settings import BaseSettings
from typing import List

from pydantic import model_validator

DEFAULT_DEV_SECRET_KEY = "yadvi_hybrid_seeds_enterprise_secret_key_2026"

def _resolve_default_auto_init_db() -> bool:
    env_val = os.getenv("AUTO_INIT_DB")
    if env_val is not None:
        return env_val.strip().lower() in ("true", "1", "yes")
    env = os.getenv("ENVIRONMENT", "development").strip().lower()
    if env in ("production", "staging"):
        return False
    return True

def _resolve_default_public_dir() -> str:
    env_dir = os.getenv("MEDIA_PUBLIC_DIR")
    if env_dir and os.path.isdir(env_dir):
        return os.path.abspath(env_dir)
    candidates = [
        os.path.join(os.getcwd(), "public"),
        os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "public"),
        os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))), "public"),
    ]
    for c in candidates:
        if os.path.isdir(c):
            return os.path.abspath(c)
    return candidates[0]


class Settings(BaseSettings):
    PROJECT_NAME: str = "Yadvi Hybrid Seeds API"
    API_V1_STR: str = "/api/v1"

    # Security
    SECRET_KEY: str = os.getenv("SECRET_KEY", DEFAULT_DEV_SECRET_KEY)
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 days

    # Database Configuration (MySQL with SQLite automatic fallback)
    DB_USER: str = os.getenv("DB_USER", "root")
    DB_PASSWORD: str = os.getenv("DB_PASSWORD", "root")
    DB_HOST: str = os.getenv("DB_HOST", "localhost")
    DB_PORT: str = os.getenv("DB_PORT", "3306")
    DB_NAME: str = os.getenv("DB_NAME", "yadvi_seeds_db")

    # SQLite fallback database for instant local development if MySQL connection is unconfigured
    SQLITE_DB_PATH: str = os.getenv("SQLITE_DB_PATH", "yadvi_seeds.db")

    # Environment & Cloud SQL Configuration
    ENVIRONMENT: str = os.getenv("ENVIRONMENT", "development")
    INSTANCE_CONNECTION_NAME: str | None = os.getenv("INSTANCE_CONNECTION_NAME", None)
    DB_SOCKET_DIR: str = os.getenv("DB_SOCKET_DIR", "/cloudsql")
    ALLOW_SQLITE_FALLBACK: bool = os.getenv("ALLOW_SQLITE_FALLBACK", "true").lower() in ("true", "1", "yes")
    AUTO_INIT_DB: bool = _resolve_default_auto_init_db()

    @model_validator(mode="after")
    def _validate_safety(self) -> "Settings":
        env = (self.ENVIRONMENT or "development").strip().lower()
        if env in ("production", "staging"):
            if self.AUTO_INIT_DB:
                raise RuntimeError(
                    f"Invalid configuration: AUTO_INIT_DB is enabled in '{env}' mode. "
                    "Database auto-initialization and demo seeding are strictly forbidden in "
                    "production/staging environments to protect live data integrity."
                )
            secret = (self.SECRET_KEY or "").strip()
            if not secret or secret == DEFAULT_DEV_SECRET_KEY:
                raise RuntimeError(
                    f"Invalid configuration: Insecure SECRET_KEY detected in '{env}' mode. "
                    "A secure, non-default secret key must be explicitly configured."
                )
        return self

    # Firebase
    FIREBASE_CREDENTIALS_PATH: str | None = os.getenv("FIREBASE_CREDENTIALS_PATH", "./firebase/firebase-service-account.json")

    # Media Storage Configuration (Local vs Google Cloud Storage)
    STORAGE_BACKEND: str = os.getenv("STORAGE_BACKEND", "local")  # "local" or "gcs"
    GCS_MEDIA_BUCKET: str | None = os.getenv("GCS_MEDIA_BUCKET", None)
    GCS_PROJECT_ID: str = os.getenv("GCS_PROJECT_ID", "yadvi-seed-app-5f306")
    GCS_SIGNED_URL_EXPIRATION_SECONDS: int = int(os.getenv("GCS_SIGNED_URL_EXPIRATION_SECONDS", "1800"))
    MEDIA_PUBLIC_DIR: str = _resolve_default_public_dir()

    # CORS
    CORS_ORIGINS: List[str] = [
        "http://localhost:5173",
        "http://127.0.0.1:5173",
        "http://localhost:3000",
        "http://localhost:8000",
        "http://192.168.137.1:8000",
        "http://192.168.137.1:5173",
        "*"
    ]

    # WhatsApp Cloud API
    WHATSAPP_PHONE_NUMBER_ID: str | None = None
    WHATSAPP_ACCESS_TOKEN: str | None = None
    WHATSAPP_TEST_RECIPIENT: str | None = None
    WHATSAPP_API_VERSION: str = "v21.0"
    WHATSAPP_API_BASE_URL: str = "https://graph.facebook.com"
    WHATSAPP_ORDER_TEMPLATE_NAME: str | None = None
    WHATSAPP_ORDER_TEMPLATE_LANG: str = "en_US"
    WHATSAPP_WEBHOOK_VERIFY_TOKEN: str | None = None
    WHATSAPP_APP_SECRET: str | None = None
    WHATSAPP_ALLOW_INSECURE_WEBHOOKS: bool = False

    # Gupshup Enterprise WhatsApp Business API
    GUPSHUP_API_KEY: str | None = None
    GUPSHUP_APP_NAME: str | None = None
    GUPSHUP_APP_ID: str | None = None
    GUPSHUP_SOURCE_NUMBER: str | None = None       # Registered WhatsApp Business Sender (E.164, e.g. 91...)
    GUPSHUP_ADMIN_RECIPIENT: str | None = None     # Designated Admin WhatsApp Recipient (E.164, e.g. 91...)
    GUPSHUP_TEMPLATE_ID: str | None = None         # Unique Gupshup Template UUID
    GUPSHUP_TEMPLATE_NAME: str = "yadviapporder_confirmation"
    GUPSHUP_TEMPLATE_LANG: str = "en_US"
    GUPSHUP_BASE_URL: str = "https://api.gupshup.io"
    GUPSHUP_WEBHOOK_SECRET: str | None = None

    class Config:
        case_sensitive = True
        env_file = [
            ".env",
            os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), ".env"),
            os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "backend", ".env")
        ]
        extra = "allow"

settings = Settings()
