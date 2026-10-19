import os
import re
import logging
from sqlalchemy import create_engine
from sqlalchemy.engine import URL
from sqlalchemy.orm import declarative_base, sessionmaker
from app.core.config import settings

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("yadvi_db")

Base = declarative_base()


def mask_db_url(url: str) -> str:
    """Masks database password in connection strings for safe logging."""
    return re.sub(r"://([^:]+):([^@]+)@", r"://\1:***@", url)


def get_engine():
    # Construct primary database connection URL securely using URL.create
    # Automatically handles special characters in passwords and Cloud SQL Unix sockets
    if getattr(settings, "INSTANCE_CONNECTION_NAME", None):
        # Cloud SQL Unix socket connection (Cloud Run)
        socket_dir = getattr(settings, "DB_SOCKET_DIR", "/cloudsql") or "/cloudsql"
        unix_socket = f"{socket_dir}/{settings.INSTANCE_CONNECTION_NAME}"
        mysql_url = URL.create(
            drivername="mysql+mysqlconnector",
            username=settings.DB_USER,
            password=settings.DB_PASSWORD,
            database=settings.DB_NAME,
            query={"unix_socket": unix_socket}
        )
    else:
        # Standard TCP connection
        mysql_url = URL.create(
            drivername="mysql+mysqlconnector",
            username=settings.DB_USER,
            password=settings.DB_PASSWORD,
            host=settings.DB_HOST,
            port=int(settings.DB_PORT) if settings.DB_PORT else 3306,
            database=settings.DB_NAME
        )

    try:
        engine = create_engine(
            mysql_url,
            pool_size=5,
            max_overflow=5,
            pool_timeout=30,
            pool_recycle=1800,
            pool_pre_ping=True,
            connect_args={"connection_timeout": 3}
        )
        # Test connection
        with engine.connect() as conn:
            logger.info("Successfully connected to primary database engine!")
            return engine
    except Exception as e:
        is_production_like = settings.ENVIRONMENT.lower() in ("production", "staging")
        fallback_allowed = bool(settings.ALLOW_SQLITE_FALLBACK and not is_production_like)

        safe_err_msg = re.sub(r"://([^:]+):([^@]+)@", r"://\1:***@", str(e))
        if settings.DB_PASSWORD:
            safe_err_msg = safe_err_msg.replace(settings.DB_PASSWORD, "***")

        if not fallback_allowed:
            logger.critical(
                f"FATAL: Primary database connection failed in {settings.ENVIRONMENT} mode: {safe_err_msg}. "
                f"SQLite fallback is strictly forbidden to prevent silent data loss on ephemeral Cloud Run filesystems."
            )
            raise RuntimeError(
                f"Primary database connection failed ({settings.ENVIRONMENT}): {safe_err_msg}. "
                f"SQLite fallback disabled."
            ) from e

        logger.warning(
            f"Could not connect to primary database ({safe_err_msg}). "
            f"Falling back to local SQLite engine ({settings.SQLITE_DB_PATH}) for local development."
        )
        sqlite_url = f"sqlite:///{settings.SQLITE_DB_PATH}"
        return create_engine(sqlite_url, connect_args={"check_same_thread": False})

engine = get_engine()
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
