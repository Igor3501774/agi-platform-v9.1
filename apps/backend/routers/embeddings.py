from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from typing import List, Optional
import logging

from backend.core.security import get_current_user
from backend.services.embedding_service import EmbeddingService

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/embed", tags=["embeddings"])

class EmbedRequest(BaseModel):
    texts: List[str] = Field(..., min_length=1, max_length=50)

class EmbedResponse(BaseModel):
    embeddings: List[List[float]]
    model: str = "bge-small-en-v1.5"

@router.post("/", response_model=EmbedResponse)
async def embed_texts(
    payload: EmbedRequest,
    current_user: Optional[dict] = Depends(get_current_user)
):
    if not payload.texts:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="texts list cannot be empty")

    try:
        service = EmbeddingService()
        vectors = await service.encode(payload.texts)
        return EmbedResponse(embeddings=vectors, model=service.model_name)
    except Exception as e:
        logger.error(f"Embedding failed: {e}", exc_info=True)
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e))