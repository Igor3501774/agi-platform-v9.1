from fastapi import APIRouter
import os, time, psycopg2, redis, httpx

router = APIRouter()

def check_postgres():
    try:
        conn = psycopg2.connect(
            dbname=os.getenv("POSTGRES_DB", "agi_platform"),
            user=os.getenv("POSTGRES_USER", "agi_user"),
            password=os.getenv("POSTGRES_PASSWORD", "agi_password_2026"),
            host="postgres", port=5432, connect_timeout=2
        )
        conn.close(); return True
    except: return False

def check_redis():
    try:
        r = redis.Redis(host="redis", port=6379, socket_connect_timeout=2)
        r.ping(); return True
    except: return False

async def check_qdrant():
    try:
        async with httpx.AsyncClient(timeout=2.0) as client:
            return (await client.get("http://qdrant:6333/healthz")).status_code == 200
    except: return False

@router.get("/health")
async def health():
    pg, rd, qd = check_postgres(), check_redis(), await check_qdrant()
    return {"status": "ok" if (pg and rd and qd) else "degraded", "service": "agi-backend",
            "version": "9.0.0", "timestamp": time.time(),
            "dependencies": {"postgres": "✅" if pg else "❌", "redis": "✅" if rd else "❌", "qdrant": "✅" if qd else "❌"}}