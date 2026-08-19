import os
from functools import lru_cache
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    APP_ENV: str = "development"
    DEBUG: bool = True
    PORT: int = 8000
    
    # Database
    POSTGRES_USER: str = "agi_user"
    POSTGRES_PASSWORD: str = "agi_password_2026"
    POSTGRES_DB: str = "agi_platform"
    DATABASE_URL: str = "postgresql://agi_user:agi_password_2026@postgres:5432/agi_platform"
    
    # Redis
    REDIS_URL: str = "redis://redis:6379/0"
    
    # Qdrant
    QDRANT_URL: str = "http://qdrant:6333"
    QDRANT_API_KEY: str = ""
    
    # JWT
    JWT_SECRET_KEY: str = "dev-secret-key"
    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRE_MINUTES: int = 30
    
    # DeepSeek
    DEEPSEEK_API_KEY: str = ""
    DEEPSEEK_MODEL: str = "deepseek-chat"
    
    # Rate Limiting
    RATE_LIMIT_PER_MINUTE: int = 60
    
    # Logging
    LOG_LEVEL: str = "INFO"
    
    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"

@lru_cache()
def get_settings() -> Settings:
    """Получить настройки (с кешированием)"""
    return Settings()

# Для обратной совместимости
settings = get_settings()