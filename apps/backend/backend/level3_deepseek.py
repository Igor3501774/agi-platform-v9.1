import os
import httpx
from typing import Optional, Dict, Any
from .settings import settings

class DeepSeekL3Agent:
    def __init__(self, api_key: Optional[str] = None):
        self.api_key = api_key or os.getenv("DEEPSEEK_API_KEY")
        self.base_url = "https://api.deepseek.com"
        if not self.api_key:
            raise RuntimeError("DEEPSEEK_API_KEY not set")

    async def chat(self, messages: list, model: str = "deepseek-chat", temperature: float = 0.7) -> Dict[str, Any]:
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }
        payload = {
            "model": model,
            "messages": messages,
            "temperature": temperature
        }

        async with httpx.AsyncClient(timeout=60.0) as client:
            resp = await client.post(f"{self.base_url}/chat/completions", json=payload, headers=headers)
            resp.raise_for_status()
            return resp.json()

    async def generate_plan(self, goal: str, tools: list) -> str:
        system_prompt = (
            "Ты — планировщик задач для мультиагентной платформы AGI Platform. "
            "Твоя задача — разбить цель на подзадачи и указать, какие инструменты использовать. "
            "Верни только JSON-массив шагов, без лишних слов."
        )
        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": f"Цель: {goal}. Доступные инструменты: {tools}"}
        ]
        result = await self.chat(messages, model="deepseek-reasoner")
        return result["choices"][0]["message"]["content"]
