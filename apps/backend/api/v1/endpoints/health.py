from fastapi import APIRouter
from core.container import container

router = APIRouter(prefix="/health", tags=["Health"])

@router.get("/")
async def health():
    checks = {}
    try:
        db_manager = container.database_manager()
        async with db_manager.session() as session:
            await session.execute("SELECT 1")
        checks["database"] = "healthy"
    except Exception as e:
        checks["database"] = f"unhealthy: {str(e)}"
    
    try:
        rate_limiter = container.rate_limiter()
        await rate_limiter.redis.ping()
        checks["redis"] = "healthy"
    except Exception as e:
        checks["redis"] = f"unhealthy: {str(e)}"
    
    try:
        embedding_service = container.embedding_service()
        await embedding_service.encode("test")
        checks["embedding"] = "healthy"
    except Exception as e:
        checks["embedding"] = f"unhealthy: {str(e)}"
    
    all_healthy = all(v == "healthy" for v in checks.values())
    return {"status": "healthy" if all_healthy else "degraded", "checks": checks}

@router.get("/ready")
async def readiness():
    try:
        db_manager = container.database_manager()
        async with db_manager.session() as session:
            await session.execute("SELECT 1")
        return {"status": "ready"}
    except:
        return {"status": "not_ready"}

@router.get("/live")
async def liveness():
    return {"status": "alive"}
