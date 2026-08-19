import asyncio
import logging
import uuid
from typing import Optional, Dict, Any, List

import httpx
from core.config import settings

logger = logging.getLogger(__name__)


class LLMService:

    def __init__(self):
        self.api_key = settings.DEEPSEEK_API_KEY
        self.model = settings.LLM_MODEL or "deepseek-chat"
        self.base_url = "https://api.deepseek.com/v1"
        self.client = httpx.AsyncClient(timeout=60.0)
        self._available = False
        self._provider = "unknown"
        self._last_request_id: Optional[str] = None

    async def check_availability(self) -> Dict[str, Any]:
        if not self.api_key:
            return {"available": False, "reason": "API key not configured"}

        try:
            response = await self.client.get(
                f"{self.base_url}/models",
                headers={"Authorization": f"Bearer {self.api_key}"},
                timeout=10.0
            )
            if response.status_code == 200:
                self._available = True
                self._provider = "deepseek"
                return {"available": True, "provider": "deepseek", "model": self.model}
            else:
                return {
                    "available": False,
                    "reason": f"API error: {response.status_code} - {response.text[:100]}"
                }
        except Exception as e:
            logger.error(f"LLM availability check failed: {e}")
            return {"available": False, "reason": str(e)}

    async def generate(
        self,
        prompt: str,
        system_prompt: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: int = 2000,
        **kwargs
    ) -> Dict[str, Any]:
        if not self.api_key:
            raise RuntimeError("DEEPSEEK_API_KEY not configured")

        request_id = str(uuid.uuid4())
        self._last_request_id = request_id

        messages = []
        if system_prompt:
            messages.append({"role": "system", "content": system_prompt})
        messages.append({"role": "user", "content": prompt})

        attempt_ids = []
        audit_trail = []
        last_error = None
        max_attempts = 2

        for attempt in range(max_attempts):
            attempt_id = str(uuid.uuid4())
            attempt_ids.append(attempt_id)
            attempt_start = asyncio.get_event_loop().time()

            try:
                logger.info(f"🔮 LLM request {request_id} attempt {attempt + 1}/{attempt_id}")

                response = await self.client.post(
                    f"{self.base_url}/chat/completions",
                    headers={
                        "Authorization": f"Bearer {self.api_key}",
                        "Content-Type": "application/json"
                    },
                    json={
                        "model": self.model,
                        "messages": messages,
                        "temperature": temperature,
                        "max_tokens": max_tokens,
                        **kwargs
                    }
                )

                attempt_duration = asyncio.get_event_loop().time() - attempt_start

                if response.status_code == 200:
                    data = response.json()
                    content = data["choices"][0]["message"]["content"]
                    upstream_request_id = data.get("id")
                    upstream_model = data.get("model", self.model)
                    upstream_usage = data.get("usage", {})

                    audit_trail.append({
                        "attempt": attempt + 1,
                        "attempt_id": attempt_id,
                        "status": "success",
                        "timestamp": attempt_start,
                        "duration": attempt_duration,
                        "upstream_request_id": upstream_request_id,
                        "upstream_status": response.status_code
                    })

                    logger.info(f"✅ LLM request {request_id} attempt {attempt + 1}: success")

                    return {
                        "content": content,
                        "provider": "deepseek",
                        "model": self.model,
                        "request_id": request_id,
                        "attempts": attempt + 1,
                        "attempt_ids": attempt_ids,
                        "upstream_status": response.status_code,
                        "upstream_request_id": upstream_request_id,
                        "upstream_model": upstream_model,
                        "upstream_usage": upstream_usage,
                        "audit_trail": audit_trail
                    }
                else:
                    error_msg = f"DeepSeek API error: {response.status_code} - {response.text[:200]}"
                    logger.error(f"❌ LLM request {request_id} attempt {attempt + 1}: {error_msg}")
                    
                    audit_trail.append({
                        "attempt": attempt + 1,
                        "attempt_id": attempt_id,
                        "status": "failed",
                        "timestamp": attempt_start,
                        "duration": attempt_duration,
                        "error": error_msg,
                        "upstream_status": response.status_code
                    })
                    
                    last_error = RuntimeError(error_msg)
                    if attempt < max_attempts - 1:
                        await asyncio.sleep(2 ** attempt)

            except Exception as e:
                attempt_duration = asyncio.get_event_loop().time() - attempt_start
                logger.error(f"❌ LLM request {request_id} attempt {attempt + 1}: {e}")
                
                audit_trail.append({
                    "attempt": attempt + 1,
                    "attempt_id": attempt_id,
                    "status": "error",
                    "timestamp": attempt_start,
                    "duration": attempt_duration,
                    "error": str(e)
                })
                
                last_error = e
                if attempt < max_attempts - 1:
                    await asyncio.sleep(2 ** attempt)

        audit_trail.append({
            "status": "final_failure",
            "timestamp": asyncio.get_event_loop().time(),
            "error": str(last_error) if last_error else "All attempts failed"
        })

        raise last_error or RuntimeError(f"LLM request {request_id} failed after {max_attempts} attempts")

    async def generate_simple(self, prompt: str) -> str:
        result = await self.generate(prompt)
        return result.get("content", "")

    def get_last_request_id(self) -> Optional[str]:
        return self._last_request_id


_llm_service: Optional[LLMService] = None


def get_llm_service() -> LLMService:
    global _llm_service
    if _llm_service is None:
        _llm_service = LLMService()
    return _llm_service
