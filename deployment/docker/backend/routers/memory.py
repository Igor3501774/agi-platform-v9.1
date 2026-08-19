from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from typing import Optional, Dict, Any
import logging
import uuid
from datetime import datetime

from backend.core.security import get_current_user

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/memory", tags=["memory"])

class MemorySaveRequest(BaseModel):
    agent_id: str
    text: str
    metadata: Optional[Dict[str, Any]] = {}

class MemorySearchRequest(BaseModel):
    agent_id: str
    query: str
    limit: int = 5

_memory_store = {}

@router.post("/save")
async def save_memory(
    request: MemorySaveRequest,
    current_user: dict = Depends(get_current_user)
):
    memory_id = str(uuid.uuid4())
    _memory_store[memory_id] = {
        "id": memory_id,
        "agent_id": request.agent_id,
        "text": request.text,
        "metadata": request.metadata,
        "created_at": datetime.now().isoformat()
    }
    return {
        "status": "success",
        "message": "Memory saved",
        "memory_id": memory_id,
        "agent_id": request.agent_id
    }

@router.post("/search")
async def search_memory(
    request: MemorySearchRequest,
    current_user: dict = Depends(get_current_user)
):
    results = []
    for mem_id, mem in _memory_store.items():
        if mem["agent_id"] == request.agent_id:
            if request.query.lower() in mem["text"].lower():
                results.append({
                    "id": mem_id,
                    "text": mem["text"],
                    "metadata": mem["metadata"],
                    "score": 0.95,
                    "created_at": mem["created_at"]
                })
    
    results = results[:request.limit]
    
    return {
        "results": results,
        "total": len(results),
        "agent_id": request.agent_id,
        "query": request.query
    }