"""
50 агентов для AGI Platform
"""

AGENTS_50 = [
    {"id": "agi_1", "name": "Александр", "role": "Стратегический консультант", "category": "business"},
    {"id": "agi_2", "name": "Мария", "role": "Эксперт по маркетингу", "category": "business"},
    {"id": "agi_3", "name": "Игорь", "role": "Финансовый аналитик", "category": "finance"},
    {"id": "agi_4", "name": "Татьяна", "role": "HR-консультант", "category": "business"},
    {"id": "agi_5", "name": "Виктория", "role": "Специалист по здоровью", "category": "health"},
    {"id": "agi_6", "name": "Екатерина", "role": "Креативный директор", "category": "creative"},
    {"id": "agi_7", "name": "Дмитрий", "role": "Юрист", "category": "legal"},
    {"id": "agi_8", "name": "Ольга", "role": "Преподаватель", "category": "education"},
    {"id": "agi_9", "name": "Сергей", "role": "Бизнес-консультант", "category": "business"},
    {"id": "agi_10", "name": "Анна", "role": "Финансовый консультант", "category": "finance"},
    {"id": "agi_11", "name": "Максим", "role": "IT-архитектор", "category": "technology"},
    {"id": "agi_12", "name": "Елена", "role": "Эксперт по масштабированию", "category": "business"},
    {"id": "agi_13", "name": "Виктор", "role": "Бизнес-коуч", "category": "business"},
    {"id": "agi_14", "name": "Наталья", "role": "Продуктовый менеджер", "category": "technology"},
    {"id": "agi_15", "name": "Владимир", "role": "Специалист по базам данных", "category": "technology"},
    {"id": "agi_16", "name": "Артем", "role": "Инвестиционный аналитик", "category": "finance"},
    {"id": "agi_17", "name": "Ирина", "role": "Бухгалтер", "category": "finance"},
    {"id": "agi_18", "name": "Константин", "role": "Риск-менеджер", "category": "finance"},
    {"id": "agi_19", "name": "Михаил", "role": "Фитнес-тренер", "category": "health"},
    {"id": "agi_20", "name": "Ксения", "role": "Нутрициолог", "category": "health"},
    {"id": "agi_21", "name": "Павел", "role": "Медицинский консультант", "category": "health"},
    {"id": "agi_22", "name": "Анастасия", "role": "Психолог", "category": "psychology"},
    {"id": "agi_23", "name": "Эльвира", "role": "Юридический консультант", "category": "legal"},
    {"id": "agi_24", "name": "Григорий", "role": "Специалист по договорам", "category": "legal"},
    {"id": "agi_25", "name": "Ева", "role": "Психолог-консультант", "category": "psychology"},
    {"id": "agi_26", "name": "Алина", "role": "Дизайнер", "category": "creative"},
    {"id": "agi_27", "name": "Вячеслав", "role": "Копирайтер", "category": "creative"},
    {"id": "agi_28", "name": "Катерина", "role": "SMM-специалист", "category": "creative"},
    {"id": "agi_29", "name": "Роман", "role": "Видеопродюсер", "category": "creative"},
    {"id": "agi_30", "name": "Таисия", "role": "Иллюстратор", "category": "creative"},
    {"id": "agi_31", "name": "Фёдор", "role": "Сторителлер", "category": "creative"},
    {"id": "agi_32", "name": "Людмила", "role": "Эксперт по обучению", "category": "education"},
    {"id": "agi_33", "name": "Денис", "role": "Методолог", "category": "education"},
    {"id": "agi_34", "name": "Евгений", "role": "Учёный", "category": "science"},
    {"id": "agi_35", "name": "Галина", "role": "Биолог", "category": "science"},
    {"id": "agi_36", "name": "Сергей", "role": "Астроном", "category": "science"},
    {"id": "agi_37", "name": "Михаил", "role": "Карьерный консультант", "category": "practical"},
    {"id": "agi_38", "name": "Анна", "role": "Тайм-менеджмент", "category": "practical"},
    {"id": "agi_39", "name": "Илья", "role": "Переговорщик", "category": "practical"},
    {"id": "agi_40", "name": "Евгения", "role": "Личная эффективность", "category": "practical"},
    {"id": "agi_41", "name": "Павел", "role": "Наставник", "category": "practical"},
    {"id": "agi_42", "name": "Георгий", "role": "Эксперт по путешествиям", "category": "outdoor"},
    {"id": "agi_43", "name": "Алексей", "role": "Cloud инженер", "category": "technology"},
    {"id": "agi_44", "name": "Екатерина", "role": "DevOps", "category": "technology"},
    {"id": "agi_45", "name": "Сергей", "role": "Data Scientist", "category": "technology"},
    {"id": "agi_46", "name": "Максим", "role": "Fullstack разработчик", "category": "technology"},
    {"id": "agi_47", "name": "Анна", "role": "Кибербезопасность", "category": "technology"},
    {"id": "agi_48", "name": "Дмитрий", "role": "Специалист по ИИ", "category": "technology"},
    {"id": "agi_49", "name": "Оксана", "role": "Эксперт по авторскому праву", "category": "legal"},
    {"id": "agi_50", "name": "Антон", "role": "Специалист по сну", "category": "health"},
]

def get_agent_by_id(agent_id: str):
    for agent in AGENTS_50:
        if agent["id"] == agent_id:
            return agent
    return None
