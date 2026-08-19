import hashlib
import json
import redis
from typing import Optional, Dict, Any
from backend.core.config import settings

class CacheManager:
    def __init__(self, redis_url: str = None):
        self.redis_url = redis_url or getattr(settings, 'REDIS_URL', 'redis://localhost:6379/0')
        self.client = None
        self.ttl = getattr(settings, 'CACHE_TTL', 3600)
        self._connect()
    
    def _connect(self):
        try:
            self.client = redis.from_url(self.redis_url, decode_responses=True)
            self.client.ping()
            print("✅ Redis connected for caching")
        except Exception as e:
            print(f"⚠️ Redis not available: {e}")
            self.client = None
    
    def _get_key(self, query: str, agent_id: str, complexity: str) -> str:
        normalized = query.strip().lower()
        content = f"{normalized}:{agent_id}:{complexity}"
        return f"agi:cache:{hashlib.md5(content.encode()).hexdigest()}"
    
    def get(self, query: str, agent_id: str, complexity: str) -> Optional[Dict[str, Any]]:
        if not self.client:
            return None
        try:
            key = self._get_key(query, agent_id, complexity)
            data = self.client.get(key)
            if data:
                print(f"✅ Cache HIT: {query[:50]}...")
                return json.loads(data)
        except Exception as e:
            print(f"⚠️ Cache get error: {e}")
        return None
    
    def set(self, query: str, agent_id: str, complexity: str, data: Dict[str, Any]):
        if not self.client:
            return
        try:
            key = self._get_key(query, agent_id, complexity)
            self.client.setex(key, self.ttl, json.dumps(data, ensure_ascii=False))
            print(f"💾 Cache SET: {query[:50]}...")
        except Exception as e:
            print(f"⚠️ Cache set error: {e}")
