from fastapi import APIRouter, Depends, HTTPException, status
from typing import List, Optional, Dict, Any
from pydantic import BaseModel

from backend.core.security import get_current_user
from backend.services.embedding_service import EmbeddingService
from backend.services.memory_service import save_to_memory, search_memory as search_memory_service

router = APIRouter(prefix="/api/v1/memory", tags=["memory"])

embedding_service = EmbeddingService()

class MemorySaveRequest(BaseModel):
    text: str
    metadata: Optional[Dict[str, Any]] = None

class MemorySearchRequest(BaseModel):
    query: str
    limit: int = 5

class MemoryItem(BaseModel):
    text: str
    score: float
    metadata: Optional[Dict[str, Any]] = None

@router.post("/save")
async def save_memory(
    request: MemorySaveRequest,
    current_user = Depends(get_current_user)
):
    """Сохранить в память"""
    try:
        embedding = await embedding_service.encode_single(request.text)
        
        save_to_memory(
            agent_id=current_user.get("username", "anonymous"),
            text=request.text,
            embedding=embedding,
            metadata=request.metadata
        )
        
        return {"status": "success", "text": request.text}
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )

@router.post("/search", response_model=List[MemoryItem])
async def search_memory(
    request: MemorySearchRequest,
    current_user = Depends(get_current_user)
):
    """Поиск в памяти"""
    try:
        query_embedding = await embedding_service.encode_single(request.query)
        
        results = search_memory_service(
            agent_id=current_user.get("username", "anonymous"),
            query_embedding=query_embedding,
            limit=request.limit
        )
        
        return [
            MemoryItem(
                text=r["text"],
                score=r["score"],
                metadata=r.get("metadata", {})
            )
            for r in results
        ]
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )