from pydantic import BaseModel
from typing import Optional, List, Any

class MemorySaveRequest(BaseModel):
    """Запрос на сохранение в память"""
    text: str
    metadata: Optional[dict] = None
    user_id: Optional[str] = None

class MemorySearchRequest(BaseModel):
    """Запрос на поиск в памяти"""
    query: str
    limit: int = 5
    user_id: Optional[str] = None

class MemoryItem(BaseModel):
    """Элемент памяти"""
    text: str
    score: float
    metadata: Optional[dict] = None