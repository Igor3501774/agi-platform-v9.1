from pydantic import BaseModel
from typing import Optional, List

class ChatRequest(BaseModel):
    """Запрос к агенту"""
    agent_id: str
    message: str
    session_id: Optional[str] = None

class ChatResponse(BaseModel):
    """Ответ от агента"""
    agent_id: str
    agent_name: str
    response: str
    session_id: str
    tokens_used: Optional[int] = None

class IntelligentChatRequest(BaseModel):
    """Запрос к Multi-Agent системе"""
    message: str
    session_id: Optional[str] = None
    agents: Optional[List[str]] = None  # Если None, выбираются автоматически