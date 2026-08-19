from sentence_transformers import CrossEncoder
from typing import List, Tuple, Optional
import logging

logger = logging.getLogger(__name__)


class CrossEncoderService:
    def __init__(self, model_name: str = "cross-encoder/ms-marco-MiniLM-L-6-v2"):
        try:
            self.model = CrossEncoder(model_name)
            self.available = True
            logger.info(f"CrossEncoder loaded: {model_name}")
        except Exception as e:
            logger.warning(f"CrossEncoder failed: {e}, using fallback")
            self.model = None
            self.available = False

    def score(self, query: str, documents: List[str]) -> List[float]:
        if not self.available or self.model is None:
            return [0.5] * len(documents)
        pairs = [[query, doc] for doc in documents]
        return self.model.predict(pairs).tolist()


cross_encoder_service = CrossEncoderService()