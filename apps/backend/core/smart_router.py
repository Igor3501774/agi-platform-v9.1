from dataclasses import dataclass
from typing import Dict, Any
import re

@dataclass
class ComplexityResult:
    complexity: str
    score: int
    details: Dict[str, Any]

class SmartRouter:
    def __init__(self):
        # РАСШИРЕННЫЙ СПИСОК КЛЮЧЕВЫХ СЛОВ
        self.complex_keywords = [
            "стратегия", "стратегический", "рынок", "прогноз", "анализ",
            "план", "планирование", "маркетинг", "инвестиции", "риски",
            "конкуренты", "конкурентный", "тренды", "разработка",
            "архитектура", "оптимизация", "бизнес", "финансы",
            "управление", "эффективность", "внедрение", "интеграция",
            "трансформация", "дорожная карта", "roadmap", "бюджет",
            "монетизация", "масштабирование", "продажи", "клиенты",
            "продукт", "команда", "лидерство", "инновации",
            "аналитика", "бизнес-план", "конкурентный анализ",
            "выход на рынок", "go-to-market", "стратегия развития"
        ]
        self.simple_keywords = [
            "что такое", "как работает", "определение", "пример",
            "кто такой", "где найти", "сколько стоит",
            "what is", "how does", "define", "example",
            "who is", "where is", "how much"
        ]
    
    def estimate_complexity(self, query: str) -> ComplexityResult:
        query_lower = query.lower()
        score = 0
        details = {}
        
        # ДЛИНА ЗАПРОСА (ОЧЕНЬ ВАЖНО)
        if len(query) > 100:
            score += 5
            details["length"] = "very_long"
        elif len(query) > 70:
            score += 4
            details["length"] = "long"
        elif len(query) > 40:
            score += 3
            details["length"] = "medium"
        else:
            details["length"] = "short"
        
        # СЛОЖНЫЕ КЛЮЧЕВЫЕ СЛОВА
        complex_count = sum(1 for kw in self.complex_keywords if kw in query_lower)
        score += complex_count * 2
        details["complex_keywords"] = complex_count
        
        # ПРОСТЫЕ КЛЮЧЕВЫЕ СЛОВА (СНИЖАЮТ)
        simple_count = sum(1 for kw in self.simple_keywords if kw in query_lower)
        score -= simple_count * 2
        details["simple_keywords"] = simple_count
        
        # ВОПРОСЫ
        questions = query.count("?")
        if questions > 1:
            score += 1
            details["questions"] = questions
        
        # ЦИФРЫ
        if re.search(r"\d+", query):
            score += 1
            details["has_numbers"] = True
        
        # ЗАПЯТЫЕ (СЛОЖНЫЕ ПРЕДЛОЖЕНИЯ)
        commas = query.count(",")
        if commas > 2:
            score += 1
            details["commas"] = commas
        
        # ДЛИННЫЕ СЛОВА
        long_words = [w for w in query.split() if len(w) > 10]
        if long_words:
            score += len(long_words)
            details["long_words"] = len(long_words)
        
        # КЛАССИФИКАЦИЯ (СНИЖЕНЫ ПОРОГИ)
        if score <= 2:
            complexity = "simple"
        elif score <= 5:
            complexity = "medium"
        else:
            complexity = "complex"
        
        details["total_score"] = score
        return ComplexityResult(complexity=complexity, score=score, details=details)
    
    def should_use_cache(self, complexity: str) -> bool:
        return complexity == "simple"
    
    def get_recommended_model(self, complexity: str, user_plan: str = "free") -> str:
        if user_plan == "pro":
            return "deepseek-chat"
        elif complexity == "simple":
            return "smollm2:360m"
        else:
            return "phi3:mini"
    
    def should_upgrade(self, complexity: str, user_plan: str) -> bool:
        # PRO ПРЕДЛАГАЕТСЯ ДЛЯ medium И complex
        return complexity in ["complex", "medium"] and user_plan == "free"
