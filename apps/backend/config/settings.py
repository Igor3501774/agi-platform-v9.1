from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import List
from pathlib import Path
from pydantic import Field, field_validator

BASE_DIR = Path(__file__).resolve().parent.parent.parent
ENV_FILE = BASE_DIR / ".env"

class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=str(ENV_FILE),
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore"
    )

    APP_NAME: str = "AGI Platform"
    APP_VERSION: str = "9.0.0"
    APP_ENV: str = "production"
    DEBUG: bool = False

    HOST: str = "0.0.0.0"
    PORT: int = 5001

    DATABASE_URL: str = "postgresql+asyncpg://agi_user:agi_password@localhost:5432/agi_platform"
    REDIS_URL: str = "redis://localhost:6379/0"

    DEEPSEEK_API_KEY: str = ""
    DEEPSEEK_MODEL: str = "deepseek-chat"
    DEEPSEEK_TIMEOUT: int = 30

    # ВРЕМЕННЫЙ ЖЁСТКИЙ КЛЮЧ (ЗАМЕНИТЕ НА .env ПОТОМ)
    JWT_SECRET_KEY: str = "m7BwU3m7W2iJ1mqaOTaoqg4xP5yR6uV8zA9bC0dE1fG2hI3jK4lM5nO6pQ7rS8tU9vW0xY1zA2bC3dE4fG5hI6jK7lM8nO9pQ0rS1tU2vW3xY4zA5bC6dE7fG8hI9jK0lM1nO2pQ3rS4tU5vW6xY7zA8bC9dE0"
    JWT_ALGORITHM: str = "HS256"
    JWT_ACCESS_EXPIRE_MINUTES: int = 15
    JWT_REFRESH_EXPIRE_DAYS: int = 30

    @field_validator('JWT_SECRET_KEY')
    @classmethod
    def validate_jwt_secret(cls, v: str) -> str:
        if len(v) < 64:
            raise ValueError(f"JWT_SECRET_KEY must be at least 64 characters. Current length: {len(v)}")
        return v

    CORS_ORIGINS: List[str] = ["*"]
    LOG_LEVEL: str = "INFO"
    EMBEDDING_MODEL: str = "all-MiniLM-L6-v2"
    CROSS_ENCODER_MODEL: str = "cross-encoder/ms-marco-MiniLM-L-6-v2"

    QDRANT_HOST: str = "localhost"
    QDRANT_PORT: int = 6333
    QDRANT_COLLECTION_NAME: str = "agents"

settings = Settings()
