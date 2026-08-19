import time
import asyncio
from collections import deque
from enum import Enum
from config.logger import logger

class CircuitState(str, Enum):
    CLOSED = "closed"
    OPEN = "open"
    HALF_OPEN = "half_open"

class SlidingWindowCircuitBreaker:
    def __init__(self, failure_rate_threshold: float = 0.5, window_size: int = 60, min_requests: int = 10, timeout: int = 30):
        self.failure_rate_threshold = failure_rate_threshold
        self.window_size = window_size
        self.min_requests = min_requests
        self.timeout = timeout
        self.state = CircuitState.CLOSED
        self._window = deque()
        self._lock = asyncio.Lock()
        self._last_failure_time = None
    
    async def call(self, func, *args, **kwargs):
        async with self._lock:
            if self.state == CircuitState.OPEN:
                if time.time() - self._last_failure_time > self.timeout:
                    self.state = CircuitState.HALF_OPEN
                    logger.info("Circuit breaker half-open")
                else:
                    raise Exception("Circuit breaker is open")
        try:
            result = await func(*args, **kwargs)
            async with self._lock:
                self._window.append({"timestamp": time.time(), "success": True})
                if self.state == CircuitState.HALF_OPEN:
                    self.state = CircuitState.CLOSED
                    logger.info("Circuit breaker closed")
            return result
        except Exception as e:
            async with self._lock:
                self._window.append({"timestamp": time.time(), "success": False})
                self._last_failure_time = time.time()
                cutoff = time.time() - self.window_size
                while self._window and self._window[0]["timestamp"] < cutoff:
                    self._window.popleft()
                if len(self._window) >= self.min_requests:
                    failures = sum(1 for r in self._window if not r["success"])
                    if failures / len(self._window) >= self.failure_rate_threshold:
                        self.state = CircuitState.OPEN
                        logger.warning("Circuit breaker opened")
            raise
