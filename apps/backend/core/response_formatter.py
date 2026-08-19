from typing import Dict, List, Any, Optional
import json
import re

class ResponseFormatter:
    @staticmethod
    def format(response: Dict[str, Any]) -> Dict[str, Any]:
        return {
            "answer": response.get("answer", "Анализ выполнен"),
            "insights": response.get("insights", []),
            "roi_message": response.get("roi_message", "Потенциал роста не определён"),
            "next_steps": response.get("next_steps", []),
            "confidence": response.get("confidence", 0.85),
            "complexity": response.get("complexity", "unknown"),
            "model": response.get("model", "unknown"),
            "cached": response.get("cached", False),
            "upgrade_required": response.get("upgrade_required", False),
            "upgrade_message": response.get("upgrade_message", "")
        }
    
    @staticmethod
    def from_text(text: str, query: str = "") -> Dict[str, Any]:
        try:
            start = text.find('{')
            end = text.rfind('}') + 1
            if start != -1 and end > start:
                json_str = text[start:end]
                data = json.loads(json_str)
                return ResponseFormatter.format(data)
        except:
            pass
        
        return ResponseFormatter.format({
            "answer": text[:500] if text else "Анализ выполнен",
            "insights": ["Анализ выполнен успешно"],
            "next_steps": ["Обратитесь за детальной консультацией"],
            "confidence": 0.7,
            "complexity": "unknown"
        })
