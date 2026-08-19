# apps/backend/services/intelligence_pipeline.py
from typing import Dict, Any, Optional, List
import logging; logger = logging.getLogger(__name__)
from .agent_registry import AgentRegistry
from .agent_service import AgentService
from .multi_agent_system import MultiAgentSystem

class IntelligencePipeline:
    """Полный пайплайн: планирование → агенты → критика → синтез → ответ"""
    
    def __init__(
        self,
        registry: AgentRegistry,
        service: AgentService,
        multi_agent: MultiAgentSystem
    ):
        self.registry = registry
        self.service = service
        self.multi_agent = multi_agent

    async def process(
        self,
        query: str,
        user_id: str = "anonymous",
        mode: str = "auto"
    ) -> Dict[str, Any]:
        logger.info(f"IntelligencePipeline.process: query={query[:50]}..., mode={mode}")
        
        analysis = self._analyze_query(query)
        
        if mode == "single" or analysis["complexity"] == "simple":
            agent_id = self._select_best_agent(query)
            if agent_id:
                result = await self.service.chat(agent_id, query, user_id)
                return {
                    "mode": "single",
                    "agent": agent_id,
                    "response": result.get("response", ""),
                    "analysis": analysis
                }
        
        if mode == "multi" or analysis["complexity"] in ["medium", "complex"]:
            num_agents = 3 if analysis["complexity"] == "medium" else 5
            result = await self.multi_agent.solve(
                task=query,
                user_id=user_id,
                num_agents=num_agents
            )
            return {
                "mode": "multi",
                "result": result,
                "analysis": analysis
            }
        
        return {
            "mode": "fallback",
            "error": "Could not process query",
            "analysis": analysis
        }

    def _analyze_query(self, query: str) -> Dict[str, Any]:
        query_lower = query.lower()
        length = len(query)
        
        if length < 30:
            complexity = "simple"
        elif length < 100:
            complexity = "medium"
        else:
            complexity = "complex"
        
        categories = {
            "technology": ["программирование", "код", "сервер", "it"],
            "finance": ["финанс", "инвестиц", "деньг", "крипто"],
            "medical": ["здоров", "симптом", "болезн"],
            "legal": ["юрист", "закон", "право"],
            "psychology": ["психолог", "стресс", "отношени"]
        }
        
        category = "general"
        for cat, keywords in categories.items():
            if any(kw in query_lower for kw in keywords):
                category = cat
                break
        
        return {
            "complexity": complexity,
            "category": category,
            "length": length,
            "word_count": len(query.split())
        }

    def _select_best_agent(self, query: str) -> Optional[str]:
        analysis = self._analyze_query(query)
        category = analysis["category"]
        
        if category == "general":
            agents = self.registry.get_all_agents()
            return agents[0]["id"] if agents else None
        
        agents = self.registry.get_by_category(category)
        return agents[0]["id"] if agents else None
