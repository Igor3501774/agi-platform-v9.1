import os
from pydantic_settings import BaseSettings
from typing import Optional

class Settings(BaseSettings):
    JWT_SECRET_KEY: str
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30

    DATABASE_URL: str

    QDRANT_HOST: str = "agi_qdrant"
    QDRANT_PORT: int = 6333
    QDRANT_COLLECTION_NAME: str = "agi_memory_v1"

    EMBEDDING_MODEL_NAME: str = "sentence-transformers/all-MiniLM-L6-v2"
    CROSS_ENCODER_MODEL_NAME: str = "cross-encoder/ms-marco-MiniLM-L-6-v2"

    RATE_LIMIT_PER_MINUTE: int = 100
    RATE_LIMIT_WINDOW_SECONDS: int = 60

    class Config:
        env_file = ".env"

settings = Settings()
