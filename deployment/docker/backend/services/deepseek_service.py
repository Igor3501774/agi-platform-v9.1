import openai
from typing import Dict, Any, List
from config.settings import settings
from config.logger import logger

class DeepSeekService:
    def __init__(self, circuit_breaker=None):
        self.api_key = settings.DEEPSEEK_API_KEY
        self.model = settings.DEEPSEEK_MODEL
        self.timeout = settings.DEEPSEEK_TIMEOUT
        self.circuit_breaker = circuit_breaker
        self.client = openai.AsyncOpenAI(api_key=self.api_key, base_url="https://api.deepseek.com/v1", timeout=self.timeout)
        self._stats = {"total_requests": 0, "total_tokens": 0, "total_cost": 0.0}
    
    async def chat(self, messages: List[Dict[str, str]], **kwargs) -> Dict[str, Any]:
        self._stats["total_requests"] += 1
        response = await self.client.chat.completions.create(
            model=self.model, messages=messages, temperature=0.7, max_tokens=2000, stream=False
        )
        result = {
            "content": response.choices[0].message.content or "",
            "model": response.model,
            "usage": {"prompt_tokens": response.usage.prompt_tokens, "completion_tokens": response.usage.completion_tokens, "total_tokens": response.usage.total_tokens},
            "finish_reason": response.choices[0].finish_reason
        }
        self._stats["total_tokens"] += result["usage"]["total_tokens"]
        return result
