import logging
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings
from app.api.auth import router as auth_router
from app.api.products import router as products_router
from app.api.orders import router as orders_router
from app.api.employees import router as employees_router
from app.api.shops import router as shops_router
from app.api.visits import router as visits_router
from app.api.attendance import router as attendance_router
from app.api.shipments import router as shipments_router
from app.api.dashboard import router as dashboard_router
from app.api.ws import router as ws_router
from app.api.tracking import router as tracking_router
from app.api.eod import router as eod_router
from app.api.notifications import router as notifications_router
from app.seed_data import init_db
from app.core.firebase import init_firebase

import os
from typing import Optional
from fastapi import Query, Depends, HTTPException, status, Response
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse, RedirectResponse, StreamingResponse
from sqlalchemy.orm import Session
from sqlalchemy import text
from jose import jwt, JWTError

from app.core.database import get_db, SessionLocal, mask_db_url
from app.core.security import oauth2_scheme
from app.core.media_storage import get_media_storage
from app.models.all_models import Visit, User

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("yadvi_main")

app = FastAPI(
    title=settings.PROJECT_NAME,
    description="Seed Distribution & Transportation Management System - Enterprise REST API with Role-Based Access Control",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# Configure CORS for React frontend & mobile client
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include All API Routers
app.include_router(auth_router, prefix=settings.API_V1_STR)
app.include_router(products_router, prefix=settings.API_V1_STR)
app.include_router(orders_router, prefix=settings.API_V1_STR)
app.include_router(employees_router, prefix=settings.API_V1_STR)
app.include_router(shops_router, prefix=settings.API_V1_STR)
app.include_router(visits_router, prefix=settings.API_V1_STR)
app.include_router(attendance_router, prefix=settings.API_V1_STR)
app.include_router(shipments_router, prefix=settings.API_V1_STR)
app.include_router(dashboard_router, prefix=settings.API_V1_STR)
app.include_router(ws_router, prefix=settings.API_V1_STR)
app.include_router(tracking_router, prefix=settings.API_V1_STR)
app.include_router(eod_router, prefix=settings.API_V1_STR)
app.include_router(notifications_router, prefix=settings.API_V1_STR)

# Mount Static Files for catalog seeds (always served locally from container)
public_dir = settings.MEDIA_PUBLIC_DIR
if os.path.exists(public_dir):
    seeds_dir = os.path.join(public_dir, "seeds")
    if os.path.exists(seeds_dir):
        app.mount("/seeds", StaticFiles(directory=seeds_dir), name="seeds")

# Product image delivery (direct static mount in dev, redirect to public GCS URL in production)
if settings.STORAGE_BACKEND.lower() == "gcs":
    @app.get("/public/products/{filename}")
    async def get_gcs_product_image(filename: str):
        safe_name = os.path.basename(filename)
        local_path = os.path.join(public_dir, "products", safe_name)
        if os.path.isfile(local_path):
            return FileResponse(local_path)
        storage = get_media_storage()
        gcs_url = storage.get_url(f"products/{safe_name}")
        return RedirectResponse(url=gcs_url, status_code=status.HTTP_307_TEMPORARY_REDIRECT)
else:
    if os.path.exists(public_dir):
        products_dir = os.path.join(public_dir, "products")
        os.makedirs(products_dir, exist_ok=True)
        app.mount("/public/products", StaticFiles(directory=products_dir), name="products")


# Private Visit-Photo Delivery: Authenticated streaming endpoint (CR-01 & CR-04)
# Enforces strict header-based JWT auth, visit-record verification, and role-based access.
# Streams media in memory-bounded chunks with safe non-caching headers.
@app.get("/public/visits/{filename}")
async def get_visit_photo(
    filename: str,
    auth_header: Optional[str] = Depends(oauth2_scheme),
    db: Session = Depends(get_db)
):
    if not auth_header:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication token required to access visit verification photos."
        )
    raw_token = auth_header.replace("Bearer ", "").strip() if auth_header.startswith("Bearer ") else auth_header.strip()
    try:
        payload = jwt.decode(raw_token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        user_id = int(payload.get("sub"))
    except (JWTError, ValueError, TypeError):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired authentication credentials."
        )

    user = db.query(User).filter(User.id == user_id).first()
    if not user or not user.is_active:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User account invalid or inactive.")

    safe_name = os.path.basename(filename)
    visit = db.query(Visit).filter(Visit.visit_photo_url.endswith(safe_name)).first()
    if not visit:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Visit photo record not found.")

    role_name = user.role.name if user.role else ""
    if role_name == "administrator":
        authorized = True
    elif role_name == "field_executive":
        authorized = bool(visit.executive and visit.executive.user_id == user.id)
    elif role_name == "shop_owner":
        authorized = bool(visit.shop and visit.shop.user_id == user.id)
    else:
        authorized = False

    if not authorized:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Forbidden: You are not authorized to view this visit verification photo."
        )

    storage = get_media_storage()
    try:
        stream, content_type, content_length = storage.open_stream(f"visits/{safe_name}")
    except HTTPException:
        raise
    except Exception as err:
        logger.warning(f"Error opening visit media stream for {safe_name}: {err}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Unable to retrieve media object."
        )

    def iterfile(file_obj, chunk_size: int = 64 * 1024):
        try:
            while True:
                chunk = file_obj.read(chunk_size)
                if not chunk:
                    break
                yield chunk
        finally:
            try:
                file_obj.close()
            except Exception:
                pass

    headers = {
        "Cache-Control": "private, no-cache, no-store, must-revalidate",
        "Pragma": "no-cache",
        "Expires": "0",
        "X-Content-Type-Options": "nosniff",
    }
    if content_length > 0:
        headers["Content-Length"] = str(content_length)

    return StreamingResponse(
        iterfile(stream),
        media_type=content_type,
        headers=headers
    )


@app.on_event("startup")
def on_startup():
    env = (getattr(settings, "ENVIRONMENT", None) or "development").strip().lower()
    is_prod_like = env in ("production", "staging")

    if is_prod_like:
        if getattr(settings, "AUTO_INIT_DB", False):
            raise RuntimeError(
                f"FATAL: AUTO_INIT_DB is enabled in {env} environment. "
                "Automatic database initialization is strictly prohibited."
            )
        logger.info(f"{env.capitalize()} environment active: skipping database auto-initialization & demo seeding.")
    else:
        if getattr(settings, "AUTO_INIT_DB", True):
            logger.info("Initializing Yadvi Hybrid Seeds Database & Seeding initial accounts (AUTO_INIT_DB=True)...")
            init_db()
        else:
            logger.info("Skipping database auto-initialization & demo seeding on startup (AUTO_INIT_DB=False).")

    logger.info("Initializing Firebase Admin SDK...")
    try:
        init_firebase()
    except Exception as e:
        logger.warning(f"Firebase Admin SDK initialization skipped or non-fatal error: {e}")

    logger.info("Yadvi Hybrid Seeds Backend API is ready to accept connections!")


@app.get("/")
def root():
    return {
        "system": "Yadvi Hybrid Seeds - Seed Distribution & Logistics Portal",
        "status": "Online",
        "version": "1.0.0",
        "api_docs": "/docs",
        "modules": [
            "Administrator Portal",
            "Field Executive Mobile App",
            "Shop Owner Mobile App"
        ],
        "endpoints": {
            "auth": "/api/v1/auth",
            "products": "/api/v1/products",
            "orders": "/api/v1/orders",
            "employees": "/api/v1/employees",
            "shops": "/api/v1/shops",
            "visits": "/api/v1/visits",
            "attendance": "/api/v1/attendance",
            "shipments": "/api/v1/shipments",
            "dashboard": "/api/v1/dashboard",
        }
    }


@app.get("/healthz", tags=["System"])
def healthz(response: Response):
    """
    Database readiness probe for Cloud Run and container orchestration.
    Executes a bounded SELECT 1 with 2.0s execution timeout.
    Returns HTTP 200 on healthy database connection.
    Returns HTTP 503 on database failure without leaking credentials or stack traces.
    """
    db = None
    try:
        db = SessionLocal()
        with db.connection().execution_options(timeout=2.0) as conn:
            conn.execute(text("SELECT /*+ MAX_EXECUTION_TIME(2000) */ 1"))
        return {
            "status": "healthy",
            "database": "connected",
            "environment": getattr(settings, "ENVIRONMENT", "development")
        }
    except Exception as exc:
        safe_msg = mask_db_url(str(exc))
        if getattr(settings, "DB_PASSWORD", None):
            safe_msg = safe_msg.replace(settings.DB_PASSWORD, "***")
        logger.error(f"Health check database readiness probe failed: {safe_msg}")
        response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE
        return {
            "status": "unhealthy",
            "database": "disconnected"
        }
    finally:
        if db is not None:
            db.close()
