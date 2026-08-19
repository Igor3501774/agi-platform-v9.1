import asyncio
import logging
from datetime import datetime
from typing import List, Dict, Any
from collections import deque

logger = logging.getLogger(__name__)

class Outbox:
    def __init__(self):
        self.events = deque()
        self.processing = False
    
    async def publish(self, event_type: str, data: Dict[str, Any]):
        event = {
            "id": f"evt_{len(self.events) + 1}",
            "type": event_type,
            "data": data,
            "timestamp": datetime.utcnow().isoformat(),
            "status": "pending"
        }
        self.events.append(event)
        logger.info(f"Event published: {event_type}")
        await self.process()
    
    async def process(self):
        if self.processing or not self.events:
            return
        self.processing = True
        try:
            while self.events:
                event = self.events[0]
                logger.info(f"Processing event: {event['id']} ({event['type']})")
                # Здесь логика обработки
                event["status"] = "processed"
                self.events.popleft()
                await asyncio.sleep(0.01)
        finally:
            self.processing = False
    
    def get_stats(self):
        return {"total": len(self.events), "pending": len([e for e in self.events if e["status"] == "pending"])}

outbox = Outbox()