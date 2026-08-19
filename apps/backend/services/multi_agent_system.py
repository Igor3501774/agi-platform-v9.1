import logging
from typing import List, Optional, Dict, Any
from .agent_registry import get_registry
from .agent_service import AgentService

logger = logging.getLogger(__name__)

class MultiAgentSystem:
    """РљРѕР»Р»РµРєС‚РёРІРЅР°СЏ СЂР°Р±РѕС‚Р° РЅРµСЃРєРѕР»СЊРєРёС… Р°РіРµРЅС‚РѕРІ"""
    
    def __init__(self):
        self.agent_service = AgentService()
    
    async def process(self, message: str, agent_ids: Optional[List[str]] = None) -> Dict[str, Any]:
        """РћР±СЂР°Р±Р°С‚С‹РІР°РµС‚ СЃРѕРѕР±С‰РµРЅРёРµ РЅРµСЃРєРѕР»СЊРєРёРјРё Р°РіРµРЅС‚Р°РјРё"""
        registry = get_registry()
        await registry.ensure_loaded()
        
        # Р•СЃР»Рё Р°РіРµРЅС‚С‹ РЅРµ СѓРєР°Р·Р°РЅС‹, РІС‹Р±РёСЂР°РµРј РІСЃРµС…
        if not agent_ids:
            agents = registry.get_all_agents()
            # Р‘РµСЂРµРј РїРµСЂРІС‹С… 3 РґР»СЏ РїСЂРёРјРµСЂР°
            agent_ids = [a["id"] for a in agents[:3]]
        
        results = []
        for agent_id in agent_ids:
            result = await self.agent_service.process_message(agent_id, message)
            results.append(result)
        
        # Р¤РѕСЂРјРёСЂСѓРµРј РєРѕР»Р»РµРєС‚РёРІРЅС‹Р№ РѕС‚РІРµС‚
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
                "message": "РќРµ СѓРґР°Р»РѕСЃСЊ РїРѕР»СѓС‡РёС‚СЊ РѕС‚РІРµС‚С‹ РѕС‚ Р°РіРµРЅС‚РѕРІ",
                "responses": results
            }
