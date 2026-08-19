import sys
import os
from dotenv import load_dotenv

load_dotenv('.env', override=True)

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from fastapi import FastAPI, Request, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from starlette.middleware.base import BaseHTTPMiddleware
from backend.routers import auth, agents, chat, memory, embeddings, legal
from backend.health import router as health_router

import time
from collections import defaultdict

# ============================================================
# RATE LIMIT MIDDLEWARE (100 запросов в минуту)
# ============================================================
class RateLimitMiddleware(BaseHTTPMiddleware):
    def __init__(self, app, rate_limit: int = 100, window: int = 60):
        super().__init__(app)
        self.rate_limit = rate_limit
        self.window = window
        self.requests = defaultdict(list)

    async def dispatch(self, request: Request, call_next):
        client_ip = request.client.host
        now = time.time()

        self.requests[client_ip] = [
            t for t in self.requests[client_ip] if now - t < self.window
        ]

        if len(self.requests[client_ip]) >= self.rate_limit:
            raise HTTPException(status_code=429, detail="Too many requests")

        self.requests[client_ip].append(now)
        response = await call_next(request)
        return response

# ============================================================
# FASTAPI APP
# ============================================================
app = FastAPI(
    title="AGI Platform v9.1",
    description="Multi-Agent AGI Platform with Smart Router",
    version="9.1.0"
)

# ============================================================
# CORS (WHITELIST)
# ============================================================
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost",
        "http://localhost:8000",
        "http://127.0.0.1:8000",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ============================================================
# RATE LIMIT
# ============================================================
app.add_middleware(RateLimitMiddleware, rate_limit=100, window=60)

# ============================================================
# РОУТЕРЫ
# ============================================================
app.include_router(health_router)
app.include_router(auth.router, prefix="/auth")
app.include_router(chat.router, prefix="/api")
app.include_router(agents.router, prefix="/api")
app.include_router(embeddings.router, prefix="/api")
app.include_router(memory.router)
app.include_router(legal.router)

@app.get("/")
async def root():
    return {"message": "AGI Platform v9.1", "status": "running"}

@app.get("/debug/routes")
async def debug_routes():
    routes = []
    for route in app.routes:
        routes.append({
            "path": route.path,
            "methods": list(route.methods) if hasattr(route, "methods") else []
        })
    return {"routes": routes}

if __name__ == "__main__":
    import uvicorn
    from core.config import settings
    print(f"🔑 КЛЮЧ: {settings.DEEPSEEK_API_KEY[:20]}...")
    print("🚀 AGI Platform v9.1 запущена на http://localhost:8000")
    uvicorn.run(app, host="0.0.0.0", port=8000)
