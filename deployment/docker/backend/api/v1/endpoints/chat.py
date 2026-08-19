from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from typing import Optional, List
import uuid
import logging

from core.security import get_current_user
from services.agent_registry import get_registry
from services.agent_service import AgentService

logger = logging.getLogger(__name__)
router = APIRouter(tags=["chat"])

class ChatRequest(BaseModel):
    agent_id: str
    message: str
    session_id: Optional[str] = None

class ChatResponse(BaseModel):
    agent_id: str
    agent_name: str
    response: str
    session_id: str
    tokens_used: Optional[int] = 0

@router.post("/send", response_model=ChatResponse)
async def send_message(
    request: ChatRequest,
    current_user: dict = Depends(get_current_user)
):
    """Отправить сообщение агенту"""
    try:
        # Получаем агента
        registry = get_registry()
        await registry.ensure_loaded()
        agent = registry.get_agent(request.agent_id)
        
        if not agent:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Agent {request.agent_id} not found"
            )
        
        # Формируем ответ (заглушка для теста)
        agent_name = agent.get("name", "Agent")
        specialty = agent.get("specialty", "")
        
        response_text = f"Привет! Я {agent_name}, эксперт по {specialty}.\n\n"
        response_text += f"Ваш вопрос: '{request.message}'\n\n"
        response_text += "Это тестовый ответ от агента. Для реального ответа нужно подключить DeepSeek API."
        
        session_id = request.session_id or str(uuid.uuid4())
        
        return ChatResponse(
            agent_id=request.agent_id,
            agent_name=agent_name,
            response=response_text,
            session_id=session_id,
            tokens_used=0
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Chat error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )