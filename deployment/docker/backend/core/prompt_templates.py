class PromptTemplates:
    @staticmethod
    def get_prompt(agent_name: str, agent_category: str, agent_role: str, 
                   query: str, complexity: str = "medium", context: str = "") -> str:
        return f"""Ты {agent_name} — {agent_role}.

Вопрос пользователя: {query}

Требования:
1. Отвечай на русском языке
2. Дай конкретные цифры и оценки где возможно
3. Предложи практические шаги

Формат ответа (JSON):
{{
    "answer": "детальный анализ вопроса",
    "insights": ["инсайт 1", "инсайт 2", "инсайт 3"],
    "roi_message": "финансовая оценка",
    "next_steps": ["шаг 1", "шаг 2", "шаг 3"],
    "confidence": 0.85
}}"""
