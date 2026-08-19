import json
import asyncio
import redis.asyncio as redis
from typing import Dict, Any, Callable, Awaitable, List
from datetime import datetime
from config.settings import settings
from config.logger import logger

class StreamEventBus:
    def __init__(self):
        self.redis = None
        self._handlers: Dict[str, List[Callable]] = {}
        self._running = False
        self._consumer_group = "agi_platform_consumers"
        self._consumer_name = f"consumer_{id(self)}"
        self._stream_prefix = "events:"
    
    async def connect(self):
        self.redis = redis.from_url(settings.REDIS_URL, decode_responses=True)
        logger.info("Event bus connected")
    
    def subscribe(self, event_type: str, handler: Callable[[Dict], Awaitable[None]]):
        if event_type not in self._handlers:
            self._handlers[event_type] = []
        self._handlers[event_type].append(handler)
    
    async def publish(self, event_type: str, data: Dict[str, Any], source: str = "system"):
        if not self.redis:
            await self.connect()
        stream = f"{self._stream_prefix}{event_type}"
        message = {"type": event_type, "data": json.dumps(data), "source": source, "timestamp": datetime.utcnow().isoformat()}
        return await self.redis.xadd(stream, message)
    
    async def start_listening(self):
        if self._running:
            return
        self._running = True
        for event_type in self._handlers.keys():
            asyncio.create_task(self._consume_events(event_type))
        logger.info(f"Event bus listening started for {len(self._handlers)} event types")
    
    async def _consume_events(self, event_type: str):
        stream = f"{self._stream_prefix}{event_type}"
        while self._running:
            try:
                result = await self.redis.xreadgroup(
                    self._consumer_group,
                    self._consumer_name,
                    {stream: ">"},
                    count=10,
                    block=5000
                )
                if not result:
                    continue
                for stream_name, messages in result:
                    for msg_id, data in messages:
                        try:
                            event_data = json.loads(data["data"])
                            event = {"type": event_type, "data": event_data, "source": data["source"], "timestamp": data["timestamp"], "id": msg_id}
                            if event_type in self._handlers:
                                for handler in self._handlers[event_type]:
                                    await handler(event)
                            await self.redis.xack(stream_name, self._consumer_group, msg_id)
                        except Exception as e:
                            logger.error(f"Event processing error: {e}")
            except Exception as e:
                logger.error(f"Event consumer error: {e}")
                await asyncio.sleep(1)
    
    async def stop(self):
        self._running = False
        if self.redis:
            await self.redis.close()
        logger.info("Event bus stopped")
