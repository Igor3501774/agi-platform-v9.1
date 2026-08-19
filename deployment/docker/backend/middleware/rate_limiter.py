from fastapi import Request, HTTPException, status
from redis import Redis
from backend.config import settings

redis = Redis(
    host=settings.REDIS_HOST,
    port=settings.REDIS_PORT,
    decode_responses=True,
    socket_timeout=5,
    socket_connect_timeout=5
)

async def rate_limit_middleware(request: Request, call_next):
    path = request.url.path
    client_ip = request.client.host if request.client else "unknown"
    key = f"rl:{path}:{client_ip}"

    current = redis.get(key)
    if current is None:
        redis.setex(key, 60, 1)
    else:
        count = int(current)
        if count >= 60:
            raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail="Rate limit exceeded")
        redis.incr(key)

    response = await call_next(request)
    return response
