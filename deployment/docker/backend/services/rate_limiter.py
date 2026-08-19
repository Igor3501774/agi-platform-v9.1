import time
import uuid
import redis.asyncio as redis
from typing import Dict, Any
from config.settings import settings
from config.logger import logger

class RateLimiterService:
    def __init__(self, redis_url: str):
        self.redis_url = redis_url
        self.redis = None
        self._limits = {"free": {"requests": 3, "window": 86400}, "pro": {"requests": 100, "window": 86400}, "business": {"requests": 1000, "window": 86400}}
    
    async def connect(self):
        self.redis = redis.from_url(self.redis_url, decode_responses=True)
        logger.info("Rate limiter connected")
    
    async def check(self, user_id: str, plan: str = "free") -> Dict[str, Any]:
        limit = self._limits.get(plan, self._limits["free"])
        key = f"rate_limit:{user_id}:{plan}"
        now = int(time.time())
        member = f"{now}:{uuid.uuid4()}"
        
        lua = """
        local key = KEYS[1]
        local limit = tonumber(ARGV[1])
        local window = tonumber(ARGV[2])
        local now = tonumber(ARGV[3])
        local member = ARGV[4]
        
        redis.call('ZREMRANGEBYSCORE', key, 0, now - window)
        local current = redis.call('ZCARD', key)
        
        if current < limit then
            redis.call('ZADD', key, now, member)
            redis.call('EXPIRE', key, window)
            return {1, limit - current - 1}
        else
            return {0, 0, 0}
        end
        """
        
        result = await self.redis.eval(lua, 1, key, str(limit["requests"]), str(limit["window"]), str(now), member)
        if result[0] == 1:
            return {"allowed": True, "remaining": result[1], "limit": limit["requests"]}
        return {"allowed": False, "remaining": 0, "limit": limit["requests"]}
