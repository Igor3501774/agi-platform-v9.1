import threading
from typing import List, Tuple
from config.settings import settings
from config.logger import logger

class CrossEncoderService:
    _instance = None
    _model = None
    _initialized = False
    _lock = threading.Lock()

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance

    def _ensure_initialized(self):
        if self._initialized:
            return
        with self._lock:
            if self._initialized:
                return
            try:
                from sentence_transformers import CrossEncoder
                self._model = CrossEncoder(settings.CROSS_ENCODER_MODEL)
                logger.info(f"Cross-Encoder model loaded: {settings.CROSS_ENCODER_MODEL}")
                self._initialized = True
            except Exception as e:
                logger.error(f"Failed to load CrossEncoder model: {e}")
                raise

    async def rerank(self, query: str, candidates: List[str], top_k: int = 5) -> List[Tuple[str, float]]:
        if not candidates:
            return []
        self._ensure_initialized()
        import asyncio
        return await asyncio.to_thread(self._rerank_sync, query, candidates, top_k)

    def _rerank_sync(self, query: str, candidates: List[str], top_k: int) -> List[Tuple[str, float]]:
        try:
            pairs = [(query, cand) for cand in candidates]
            scores = self._model.predict(pairs)
            ranked = sorted(zip(candidates, scores), key=lambda x: x[1], reverse=True)
            return ranked[:top_k]
        except Exception as e:
            logger.error(f"Reranking failed: {e}")
            return [(c, 0.0) for c in candidates[:top_k]]

cross_encoder_service = CrossEncoderService()
