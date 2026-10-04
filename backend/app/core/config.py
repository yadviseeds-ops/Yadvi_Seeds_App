import os
from pydantic_settings import BaseSettings
from typing import List

class Settings(BaseSettings):
    PROJECT_NAME: str = "Yadvi Hybrid Seeds API"
    API_V1_STR: str = "/api/v1"
    
    # Security
    SECRET_KEY: str = os.getenv("SECRET_KEY", "yadvi_hybrid_seeds_enterprise_secret_key_2026")
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
    
    # Firebase
    FIREBASE_CREDENTIALS_PATH: str | None = os.getenv("FIREBASE_CREDENTIALS_PATH", "./firebase/firebase-service-account.json")
    
    # CORS
    CORS_ORIGINS: List[str] = [
        "http://localhost:5173",
        "http://127.0.0.1:5173",
        "http://localhost:3000",
        "http://localhost:8000",
        "*"
    ]

    class Config:
        case_sensitive = True
        env_file = ".env"
        extra = "allow"

settings = Settings()
