from fastapi import APIRouter, HTTPException
from typing import List, Optional
from services.agent_registry import registry

router = APIRouter(prefix="/agents", tags=["Agents"])

@router.get("/")
async def get_agents():
    agents = await registry.get_all_agents()
    return {"agents": agents}

@router.get("/stats")
async def get_stats():
    return await registry.get_stats()

@router.get("/category/{category}")
async def get_agents_by_category(category: str):
    agents = await registry.get_by_category(category)
    return {"agents": agents, "category": category, "count": len(agents)}

@router.get("/premium/{is_premium}")
async def get_agents_by_premium(is_premium: bool):
    agents = await registry.get_by_premium(is_premium)
    return {"agents": agents, "is_premium": is_premium, "count": len(agents)}

@router.get("/safe")
async def get_safe_agents():
    agents = await registry.get_by_safe(True)
    return {"agents": agents}

@router.get("/{agent_id}")
async def get_agent(agent_id: str):
    agent = await registry.get_agent(agent_id)
    if agent:
        return agent
    raise HTTPException(status_code=404, detail=f"Agent {agent_id} not found")
