import asyncio
import json
import logging
from typing import Dict, List, Optional, Any

from backend.services.agent_registry import get_registry
from backend.services.agent_definitions import AGENTS_50
from backend.core.config import settings
from backend.core.smart_router import SmartRouter
from backend.core.cache_manager import CacheManager
from backend.core.response_formatter import ResponseFormatter

logger = logging.getLogger(__name__)

class AgentService:
    """Сервис для работы с агентами"""

    def __init__(self):
        self.registry = get_registry()
        self.router = SmartRouter()
        self.cache = CacheManager()
        self.formatter = ResponseFormatter()
        self.deepseek_api_key = settings.DEEPSEEK_API_KEY
        self.deepseek_url = "https://api.deepseek.com/v1/chat/completions"

    async def process_query(
        self,
        agent_id: str,
        query: str,
        user_plan: str = "free"
    ) -> Dict[str, Any]:
        """Обрабатывает запрос с использованием Smart Router"""

        # 1. Получаем агента
        agent = self.registry.get_agent(agent_id)
        if not agent:
            return {"error": f"Agent {agent_id} not found"}

        # 2. Анализируем сложность
        complexity_result = self.router.estimate_complexity(query)
        complexity = complexity_result.complexity

        print(f"📊 [Router] Complexity: {complexity} (score: {complexity_result.score})")
        print(f"   Query: {query[:100]}...")

        # 3. Проверяем кэш
        if self.router.should_use_cache(complexity) and user_plan == "free":
            cached = self.cache.get(query, agent_id, complexity)
            if cached:
                return self.formatter.format({
                    **cached,
                    "cached": True,
                    "complexity": complexity
                })

        # 4. Проверяем апгрейд
        if self.router.should_upgrade(complexity, user_plan):
            return self.formatter.format({
                "answer": "🔥 Для полного стратегического анализа требуется Pro тариф ($19/мес). Получите детальный разбор рынка, конкурентов и пошаговый план.",
                "insights": [
                    "Запрос требует глубинного анализа",
                    "Pro тариф даёт доступ к расширенным моделям",
                    "Включены: стратегический анализ, прогнозы, конкуренты"
                ],
                "roi_message": "Pro тариф: $19/мес",
                "next_steps": [
                    "Оформите Pro подписку в приложении",
                    "Получите полный стратегический анализ",
                    "Доступ к 50+ экспертам"
                ],
                "confidence": 0.95,
                "complexity": complexity,
                "model": "pro_required",
                "cached": False,
                "upgrade_required": True,
                "upgrade_message": "🔥 Требуется Pro тариф для полного анализа"
            })

        # 5. Выбираем модель
        recommended_model = self.router.get_recommended_model(complexity, user_plan)

        # 6. Формируем промпт
        agent_name = agent.get("name", "Агент")
        agent_role = agent.get("role", "Консультант")
        prompt = f"Ты {agent_name} — {agent_role}. Ответь на вопрос пользователя на русском языке. Вопрос: {query}"

        # 7. Вызываем LLM
        response_text = await self._call_deepseek(prompt)

        # 8. Парсим ответ
        parsed = self.formatter.from_text(response_text, query)

        # 9. Формируем результат
        result = {
            **parsed,
            "complexity": complexity,
            "model": recommended_model,
            "cached": False,
            "upgrade_required": False,
            "upgrade_message": ""
        }

        # 10. Сохраняем в кэш
        if self.router.should_use_cache(complexity) and user_plan == "free":
            self.cache.set(query, agent_id, complexity, result)

        return self.formatter.format(result)

    async def _call_deepseek(self, prompt: str) -> str:
        """Вызов DeepSeek API"""
        import aiohttp

        if not self.deepseek_api_key or self.deepseek_api_key == "sk-placeholder-key":
            return json.dumps({
                "answer": "Анализ выполнен. Для получения полного ответа настройте API ключ DeepSeek.",
                "insights": ["Настройте API ключ", "Проверьте подключение"],
                "roi_message": "Не определено",
                "next_steps": ["Настройте API ключ в .env"],
                "confidence": 0.5
            }, ensure_ascii=False)

        try:
            async with aiohttp.ClientSession() as session:
                async with session.post(
                    self.deepseek_url,
                    headers={
                        "Authorization": f"Bearer {self.deepseek_api_key}",
                        "Content-Type": "application/json"
                    },
                    json={
                        "model": "deepseek-chat",
                        "messages": [{"role": "user", "content": prompt}],
                        "temperature": 0.7,
                        "max_tokens": 500
                    },
                    timeout=aiohttp.ClientTimeout(total=30)
                ) as resp:
                    if resp.status == 200:
                        data = await resp.json()
                        return data.get("choices", [{}])[0].get("message", {}).get("content", "")
                    else:
                        logger.error(f"DeepSeek API error: {resp.status}")
                        return json.dumps({
                            "answer": "Ошибка вызова DeepSeek API",
                            "insights": ["Проверьте API ключ"],
                            "roi_message": "Не определено",
                            "next_steps": ["Проверьте подключение к интернету"],
                            "confidence": 0.3
                        }, ensure_ascii=False)
        except Exception as e:
            logger.error(f"DeepSeek error: {e}")
            return json.dumps({
                "answer": "Ошибка вызова DeepSeek API",
                "insights": [str(e)],
                "roi_message": "Не определено",
                "next_steps": ["Проверьте подключение"],
                "confidence": 0.3
            }, ensure_ascii=False)

# Глобальный экземпляр
agent_service = AgentService()

def get_agent_service():
    """Возвращает глобальный экземпляр AgentService"""
    return agent_service
