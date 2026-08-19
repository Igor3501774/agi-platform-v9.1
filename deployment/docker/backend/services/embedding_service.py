import os
import logging
import numpy as np
from typing import List, Optional

logger = logging.getLogger(__name__)

# Пытаемся импортировать sentence-transformers
try:
    from sentence_transformers import SentenceTransformer
    HAS_TRANSFORMERS = True
except ImportError:
    HAS_TRANSFORMERS = False
    logger.warning("sentence-transformers not installed, using fallback embeddings")

class EmbeddingService:
    def __init__(self):
        self.model_name = os.getenv("EMBEDDING_MODEL", "all-MiniLM-L6-v2")
        self.model = None
        if HAS_TRANSFORMERS:
            try:
                self.model = SentenceTransformer(self.model_name)
                logger.info(f"Loaded embedding model: {self.model_name}")
            except Exception as e:
                logger.error(f"Failed to load embedding model: {e}")
                self.model = None
    
    async def encode(self, texts: List[str]) -> List[List[float]]:
        """Получить эмбеддинги для списка текстов"""
        if not texts:
            return []
        
        # Пробуем локальную модель
        if self.model:
            try:
                embeddings = self.model.encode(texts, convert_to_numpy=True)
                return embeddings.tolist()
            except Exception as e:
                logger.error(f"Local embedding failed: {e}")
        
        # Fallback: случайные векторы
        logger.warning("Using fallback embeddings (random vectors)")
        dim = 384
        return [[float(np.random.random()) for _ in range(dim)] for _ in texts]
    
    async def embed(self, text: str) -> List[float]:
        """Получить эмбеддинг для одного текста"""
        result = await self.encode([text])
        return result[0] if result else []

# Глобальный экземпляр
_service = None

def get_embedding_service():
    global _service
    if _service is None:
        _service = EmbeddingService()
    return _service

# ✅ Функции для совместимости
async def get_embeddings(text: str) -> List[float]:
    service = get_embedding_service()
    return await service.embed(text)

async def get_embeddings_batch(texts: List[str]) -> List[List[float]]:
    service = get_embedding_service()
    return await service.encode(texts)
