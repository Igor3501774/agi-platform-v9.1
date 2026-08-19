from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from pydantic import BaseModel
from datetime import datetime, timedelta
from typing import Optional
import jwt
from config.settings import settings
from services.embedding_service import EmbeddingService
from services.cross_encoder_service import CrossEncoderService
from services.memory_service import MemoryService
from middleware.rate_limiter_middleware import RateLimiter

app = FastAPI(title="AGI Platform v9.0 Backend")

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="login")

# Инициализация сервисов
embedding_service = EmbeddingService(
    model_name=settings.EMBEDDING_MODEL_NAME,
)
cross_encoder_service = CrossEncoderService(
    model_name=settings.CROSS_ENCODER_MODEL_NAME,
)
memory_service = MemoryService(
    host=settings.QDRANT_HOST,
    port=settings.QDRANT_PORT,
    collection_name=settings.QDRANT_COLLECTION_NAME,
)
rate_limiter = RateLimiter()

@app.on_event("startup")
async def startup():
    if settings.RATE_LIMIT_ENABLED:
        app.state.rate_limiter_enabled = True
    else:
        app.state.rate_limiter_enabled = False

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    expire = datetime.utcnow() + (expires_delta or timedelta(hours=24))
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)
    return encoded_jwt

@app.post("/login")
async def login():
    access_token = create_access_token(data={"sub": "test_user"})
    return {"access_token": access_token, "token_type": "bearer"}

@app.get("/health")
async def health():
    return {"status": "ok", "version": "v9.0"}

@app.post("/search")
async def search(query: str):
    query_vec = embedding_service.encode([query])[0].tolist()
    results = memory_service.search(query_vec, top_k=10)
    candidates = [r["payload"]["content"] for r in results]
    ranked = cross_encoder_service.rank(query, candidates)
    return {"query": query, "ranked_results": ranked}
