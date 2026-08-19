import hashlib
import json
import redis.asyncio as redis
from typing import Dict, Any, Callable
from config.settings import settings
from config.logger import logger

class IdempotencyService:
    def __init__(self, redis_url: str):
        self.redis_url = redis_url
        self.redis = None
        self.ttl = 604800
    
    async def connect(self):
        self.redis = redis.from_url(self.redis_url, decode_responses=True)
        logger.info("Idempotency service connected")
    
    def generate_key(self, user_id: str, path: str, data: Dict) -> str:
        content = f"{user_id}:{path}:{json.dumps(data, sort_keys=True)}"
        return f"idempotency:{hashlib.sha256(content.encode()).hexdigest()}"
    
    async def process(self, key: str, handler: Callable) -> Dict[str, Any]:
        import asyncio
        cached = await self.redis.get(key)
        if cached:
            return json.loads(cached)
        result = await handler()
        await self.redis.setex(key, self.ttl, json.dumps(result))
        return result
