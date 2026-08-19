from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from typing import Optional, List
import logging

from backend.core.security import get_current_user
from backend.services.agent_service import get_agent_service

logger = logging.getLogger(__name__)

router = APIRouter()

class ChatRequest(BaseModel):
    agent_id: str
    query: str
    # user_plan УДАЛЁН — берётся из JWT!

class ChatResponse(BaseModel):
    answer: str
    insights: List[str] = []
    roi_message: str = ""
    next_steps: List[str] = []
    confidence: float = 0.85
    complexity: str = "unknown"
    model: str = "unknown"
    cached: bool = False
    upgrade_required: bool = False
    upgrade_message: Optional[str] = None

@router.post("/send")
async def send_message(
    request: ChatRequest,
    current_user: dict = Depends(get_current_user)
):
    """Отправка сообщения агенту (тариф из JWT)"""
    try:
        service = get_agent_service()
        result = await service.process_query(
            agent_id=request.agent_id,
            query=request.query,
            user_plan=current_user["plan"]  # ← БЕРЁМ ИЗ JWT!
        )
        return result
    except Exception as e:
        logger.error(f"Chat error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Ошибка обработки запроса: {str(e)}"
        )

@router.get("/healthz")
async def healthz():
    return {"status": "alive", "message": "pong"}
