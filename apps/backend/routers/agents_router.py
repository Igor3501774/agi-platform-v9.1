from fastapi import APIRouter, Depends, HTTPException, status
from typing import List
from pydantic import BaseModel

from core.security import get_current_user

router = APIRouter(prefix="/agents", tags=["agents"])

class AgentListItem(BaseModel):
    id: str
    name: str
    specialty: str
    description: str
    category: str
    is_premium: bool
    is_safe: bool
    icon: str = "??"

@router.get("/", response_model=List[AgentListItem])
async def list_agents(current_user: dict = Depends(get_current_user)):
    try:
        from services.agent_registry import get_registry
        registry = get_registry()
        await registry.ensure_loaded()
        agents = registry.get_all_agents()
        return [
            AgentListItem(
                id=a["id"],
                name=a["name"],
                specialty=a.get("specialty", ""),
                description=a.get("description", ""),
                category=a.get("category", "general"),
                is_premium=a.get("is_premium", False),
                is_safe=a.get("is_safe", False),
                icon=a.get("icon", "??")
            )
            for a in agents
        ]
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e))

@router.get("/{agent_id}", response_model=AgentListItem)
async def get_agent(agent_id: str, current_user: dict = Depends(get_current_user)):
    try:
        from services.agent_registry import get_registry
        registry = get_registry()
        await registry.ensure_loaded()
        agent = registry.get_agent(agent_id)
        if not agent:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Agent not found")
        return AgentListItem(
            id=agent["id"],
            name=agent["name"],
            specialty=agent.get("specialty", ""),
            description=agent.get("description", ""),
            category=agent.get("category", "general"),
            is_premium=agent.get("is_premium", False),
            is_safe=agent.get("is_safe", False),
            icon=agent.get("icon", "??")
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e))
