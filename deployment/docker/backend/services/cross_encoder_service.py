from sentence_transformers import CrossEncoder
from typing import List, Tuple, Optional
import logging

logger = logging.getLogger(__name__)

class CrossEncoderService:
    def __init__(self, model_name: str = "cross-encoder/ms-marco-MiniLM-L-6"):
        try:
            self.model = CrossEncoder(model_name)
            self.available = True
            logger.info(f"? CrossEncoder loaded: {model_name}")
        except Exception as e:
            logger.warning(f"?? CrossEncoder failed: {e} — using fallback")
            self.model = None
            self.available = False

    def rank(self, query: str, candidates: List[str], top_k: int = 10) -> List[Tuple[str, float]]:
        if not self.available or not candidates:
            return [(c, 0.5) for c in candidates[:top_k]]
        
        pairs = [[query, c] for c in candidates]
        scores = self.model.predict(pairs)
        ranked = sorted(enumerate(scores), key=lambda x: x[1], reverse=True)[:top_k]
        return [(candidates[idx], float(score)) for idx, score in ranked]

cross_encoder_service = CrossEncoderService()
