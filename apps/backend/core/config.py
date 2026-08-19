import os
from typing import Optional
from pydantic_settings import BaseSettings
from dotenv import load_dotenv

# Загружаем .env
load_dotenv('.env', override=True)

class Settings(BaseSettings):
    """Настройки приложения"""
    
    # DeepSeek
    DEEPSEEK_API_KEY: str = os.getenv("DEEPSEEK_API_KEY", "sk-placeholder-key")
    
    # JWT
    JWT_SECRET_KEY: str = os.getenv("JWT_SECRET_KEY", "super_secret_key_32_chars_minimum")
    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRE_MINUTES: int = 3600
    
    # Database
    POSTGRES_USER: str = os.getenv("POSTGRES_USER", "agi_user")
    POSTGRES_PASSWORD: str = os.getenv("POSTGRES_PASSWORD", "agi_password")
    POSTGRES_DB: str = os.getenv("POSTGRES_DB", "agi_platform")
    POSTGRES_HOST: str = "localhost"
    POSTGRES_PORT: str = "5432"
    
    # Qdrant
    QDRANT_URL: str = os.getenv("QDRANT_URL", "http://localhost:6333")
    QDRANT_VECTOR_SIZE: int = 384
    
    # Redis
    REDIS_URL: str = os.getenv("REDIS_URL", "redis://localhost:6379/0")
    CACHE_TTL: int = 3600
    
    # Smart Router
    ENABLE_SMART_ROUTER: bool = True
    ENABLE_CACHE: bool = True
    ENABLE_LOCAL_MODELS: bool = True
    
    # Rate Limiting
    RATE_LIMIT_PER_MINUTE: int = 100
    RATE_LIMIT_WINDOW_SECONDS: int = 60
    
    # Embedding
    EMBEDDING_MODEL_NAME: str = "sentence-transformers/all-MiniLM-L6-v2"
    CROSS_ENCODER_MODEL_NAME: str = "cross-encoder/ms-marco-MiniLM-L-6-v2"
    
    @property
    def DATABASE_URL(self) -> str:
        return f"postgresql://{self.POSTGRES_USER}:{self.POSTGRES_PASSWORD}@{self.POSTGRES_HOST}:{self.POSTGRES_PORT}/{self.POSTGRES_DB}"
    
    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        extra = "ignore"

# ============================================================
# ГЛОБАЛЬНЫЙ ЭКЗЕМПЛЯР
# ============================================================
settings = Settings()

# Для обратной совместимости
SECRET_KEY = settings.JWT_SECRET_KEY
ALGORITHM = settings.JWT_ALGORITHM
QDRANT_URL = settings.QDRANT_URL
DATABASE_URL = settings.DATABASE_URL

print(f"🔑 КЛЮЧ ЗАГРУЖЕН: {settings.DEEPSEEK_API_KEY[:20]}...")
print(f"   Длина ключа: {len(settings.DEEPSEEK_API_KEY)}")
