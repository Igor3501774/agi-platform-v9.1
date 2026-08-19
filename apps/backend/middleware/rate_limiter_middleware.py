import os
import time
import asyncio
from fastapi import Request, HTTPException, status
from typing import Dict
from collections import defaultdict

REDIS_HOST = os.getenv("REDIS_HOST", "redis")
REDIS_PORT = int(os.getenv("REDIS_PORT", "6379"))
MAX_REQUESTS = int(os.getenv("RATE_LIMIT_MAX", "60"))
WINDOW_SECONDS = int(os.getenv("RATE_LIMIT_WINDOW", "60"))

REDIS_AVAILABLE = False
r = None

try:
    import redis.asyncio as redis
    r = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, db=0, decode_responses=True)
    REDIS_AVAILABLE = True
    print("? Redis rate limiter connected")
except Exception as e:
    print(f"?? Redis not available: {e}   rate limiting disabled")

#   memory-  (  threading)
class AsyncMemoryLimiter:
    def __init__(self):
        self._requests: Dict[str, list] = defaultdict(list)
        self._lock = asyncio.Lock()

    async def check_and_add(self, key: str, now: int, window_start: int) -> bool:
        async with self._lock:
            self._requests[key] = [t for t in self._requests[key] if t > window_start]
            if len(self._requests[key]) >= MAX_REQUESTS:
                return False
            self._requests[key].append(now)
            return True

memory_limiter = AsyncMemoryLimiter()

async def rate_limit(request: Request):
    client_ip = request.client.host if request.client else "unknown"
    key = f"rate_limit:{client_ip}"
    now = int(time.time())
    window_start = now - WINDOW_SECONDS

    if REDIS_AVAILABLE and r:
        try:
            await r.zremrangebyscore(key, "-inf", window_start)
            count = await r.zcard(key)
            if count >= MAX_REQUESTS:
                raise HTTPException(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    detail="Rate limit exceeded"
                )
            await r.zadd(key, {str(now): now})
            await r.expire(key, WINDOW_SECONDS)
            return
        except Exception as e:
            print(f"?? Redis error: {e}   skipping rate limit")

    # Memory fallback ( )
    ok = await memory_limiter.check_and_add(client_ip, now, window_start)
    if not ok:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Rate limit exceeded (memory)"
        )

class RateLimiter:
    '''Rate limiter middleware wrapper'''
    
    def __init__(self):
        self.limiter = AsyncMemoryLimiter()
    
    async def check_and_add(self, key: str, now: int, window_start: int) -> bool:
        return await self.limiter.check_and_add(key, now, window_start)
    
    async def __call__(self, request, call_next):
        import time
        from fastapi import HTTPException, status
        
        client_ip = request.client.host if request.client else "unknown"
        key = f"rate_limit:{client_ip}"
        now = int(time.time())
        window_start = now - 60
        
        if await self.check_and_add(key, now, window_start):
            return await call_next(request)
        else:
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Too many requests"
            )