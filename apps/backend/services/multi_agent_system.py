import logging
from typing import List, Optional, Dict, Any
from backend.services.agent_registry import get_registry
from backend.services.agent_service import AgentService

logger = logging.getLogger(__name__)

class MultiAgentSystem:
    """Коллективная работа нескольких агентов"""
    
    def __init__(self):
        self.agent_service = AgentService()
    
    async def process(self, message: str, agent_ids: Optional[List[str]] = None) -> Dict[str, Any]:
        """Обрабатывает сообщение несколькими агентами"""
        registry = get_registry()
        await registry.ensure_loaded()
        
        # Если агенты не указаны, выбираем всех
        if not agent_ids:
            agents = registry.get_all_agents()
            # Берем первых 3 для примера
            agent_ids = [a["id"] for a in agents[:3]]
        
        results = []
        for agent_id in agent_ids:
            result = await self.agent_service.process_message(agent_id, message)
            results.append(result)
        
        # Формируем коллективный ответ
        responses = [r.get("response", "") for r in results if "error" not in r]
        if responses:
            combined = "\n\n---\n\n".join(responses)
            return {
                "status": "success",
                "responses": results,
                "combined_response": combined
            }
        else:
            return {
                "status": "error",
                "message": "Не удалось получить ответы от агентов",
                "responses": results
            }