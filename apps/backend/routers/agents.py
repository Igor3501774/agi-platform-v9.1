from fastapi import APIRouter, Depends, HTTPException, status
from typing import List, Dict, Any
import logging

from core.security import get_current_user
from services.agent_registry import get_registry
from models.agent import Agent

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/agents", tags=["agents"])

@router.get("")
async def get_agents(current_user: dict = Depends(get_current_user)):
    """???????? ?????? ???? ???????"""
    registry = get_registry()
    await registry.ensure_loaded()
    agents = registry.get_all_agents()
    return {"agents": agents, "total": len(agents)}

@router.get("/{agent_id}")
async def get_agent(
    agent_id: str,
    current_user: dict = Depends(get_current_user)
):
    """???????? ?????? ?? ID"""
    registry = get_registry()
    await registry.ensure_loaded()
    agent = registry.get_agent(agent_id)
    if not agent:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Agent {agent_id} not found"
        )
    return agent

@router.get("/categories")
async def get_categories(current_user: dict = Depends(get_current_user)):
    """???????? ?????? ???? ????????? ???????"""
    registry = get_registry()
    await registry.ensure_loaded()
    
    categories = set()
    for agent in registry.get_all_agents():
        # ? ??????????: ?????????? get() ??? ????????
        if isinstance(agent, dict):
            category = agent.get("category")
        else:
            category = getattr(agent, "category", None)
        
        if category:
            categories.add(category)
    
    return {"categories": sorted(list(categories))}

@router.get("/stats")
async def get_stats(current_user: dict = Depends(get_current_user)):
    """???????? ?????????? ?? ???????"""
    registry = get_registry()
    await registry.ensure_loaded()
    agents = registry.get_all_agents()
    
    total = len(agents)
    premium = 0
    safe = 0
    categories = {}
    
    for agent in agents:
        # ? ??????????: ???????? ?? ?????????
        if isinstance(agent, dict):
            if agent.get("is_premium", False):
                premium += 1
            if agent.get("is_safe", False):
                safe += 1
            category = agent.get("category", "unknown")
            categories[category] = categories.get(category, 0) + 1
        else:
            if getattr(agent, "is_premium", False):
                premium += 1
            if getattr(agent, "is_safe", False):
                safe += 1
            category = getattr(agent, "category", "unknown")
            categories[category] = categories.get(category, 0) + 1
    
    return {
        "total": total,
        "premium": premium,
        "free": total - premium,
        "safe": safe,
        "categories": categories
    }

@router.get("/premium")
async def get_premium_agents(current_user: dict = Depends(get_current_user)):
    """???????? ?????? ??????? ???????"""
    registry = get_registry()
    await registry.ensure_loaded()
    
    premium_agents = []
    for agent in registry.get_all_agents():
        if isinstance(agent, dict):
            if agent.get("is_premium", False):
                premium_agents.append(agent)
        else:
            if getattr(agent, "is_premium", False):
                premium_agents.append(agent)
    
    return {"agents": premium_agents, "total": len(premium_agents)}

@router.get("/free")
async def get_free_agents(current_user: dict = Depends(get_current_user)):
    """???????? ?????? ?????????? ???????"""
    registry = get_registry()
    await registry.ensure_loaded()
    
    free_agents = []
    for agent in registry.get_all_agents():
        if isinstance(agent, dict):
            if not agent.get("is_premium", False):
                free_agents.append(agent)
        else:
            if not getattr(agent, "is_premium", False):
                free_agents.append(agent)
    
    return {"agents": free_agents, "total": len(free_agents)}

