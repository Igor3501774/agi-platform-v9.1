import logging
from typing import Dict, Any, List

logger = logging.getLogger(__name__)

class Critic:
    async def evaluate(self, responses: List[Dict[str, Any]]) -> Dict[str, Any]:
        if not responses:
            return {"score": 0, "reasons": ["Нет ответов для оценки"], "best": None}
        
        scores = []
        for r in responses:
            score = 0
            response_text = r.get("response", "")
            tokens = r.get("tokens_used", 0)
            
            # Оценка по длине
            if len(response_text) > 50:
                score += 2
            if len(response_text) > 200:
                score += 1
            
            # Оценка по структуре
            if "\n" in response_text:
                score += 1
            if any(marker in response_text for marker in ["1.", "2.", "3."]):
                score += 2
            
            # Оценка по токенам
            if tokens > 50:
                score += 1
            
            scores.append({"agent": r.get("agent_name"), "score": score, "response": response_text})
        
        best = max(scores, key=lambda x: x["score"])
        reasons = [f"Лучший ответ: {best['agent']} (оценка: {best['score']})"]
        
        return {
            "score": best["score"],
            "best": best["agent"],
            "best_response": best["response"],
            "reasons": reasons,
            "all_scores": scores
        }

critic = Critic()