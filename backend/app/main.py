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
from app.seed_data import init_db
from app.core.firebase import init_firebase

import os
from fastapi.staticfiles import StaticFiles

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

# Mount Static Files for images (e.g. /seeds/seed_12.jpeg)
public_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "public")
if os.path.exists(public_dir):
    app.mount("/seeds", StaticFiles(directory=os.path.join(public_dir, "seeds")), name="seeds")
    visits_dir = os.path.join(public_dir, "visits")
    os.makedirs(visits_dir, exist_ok=True)
    app.mount("/public/visits", StaticFiles(directory=visits_dir), name="visits")


@app.on_event("startup")
def on_startup():
    logger.info("Initializing Yadvi Hybrid Seeds Database & Seeding initial accounts...")
    init_db()
    logger.info("Initializing Firebase Admin SDK...")
    try:
        init_firebase()
    except Exception as e:
        logger.error(f"Critical startup failure: {e}")
        # We allow the app to continue so we don't crash entirely, but auth will fail safely later.
        
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
