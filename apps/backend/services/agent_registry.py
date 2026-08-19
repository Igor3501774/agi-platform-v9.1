import logging
import asyncpg
from typing import List, Optional, Dict, Any
from .agent_definitions import AGENTS_50

logger = logging.getLogger(__name__)

class AgentRegistry:
    _instance = None
    _agents: Dict[str, Dict[str, Any]] = {}
    _loaded = False
    _db_pool = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance

    def __init__(self):
        # Загружаем агентов сразу при создании
        import asyncio
        try:
            loop = asyncio.get_event_loop()
            if loop.is_running():
                # Если цикл уже запущен, создаём задачу
                asyncio.create_task(self.ensure_loaded())
            else:
                loop.run_until_complete(self.ensure_loaded())
        except RuntimeError:
            # Если нет цикла, создаём новый
            asyncio.run(self.ensure_loaded())

    async def _get_db(self):
        if self._db_pool is None:
            self._db_pool = await asyncpg.create_pool(
                user="agi_user",
                password="agi_password_2026",
                database="agi_platform",
                host="postgres",
                port=5432
            )
        return self._db_pool

    async def ensure_loaded(self):
        if self._loaded:
            return
        try:
            pool = await self._get_db()
            async with pool.acquire() as conn:
                rows = await conn.fetch("SELECT id, name, specialty, description, category, is_premium, is_safe, icon, prompt_template, tags FROM agents")
                if rows:
                    for row in rows:
                        self._agents[row["id"]] = dict(row)
                    logger.info(f"✅ Загружено {len(self._agents)} агентов из БД")
                else:
                    # Загружаем из AGENTS_50
                    for agent in AGENTS_50:
                        self._agents[agent["id"]] = agent
                        await conn.execute("""
                            INSERT INTO agents (id, name, specialty, description, category, is_premium, is_safe, icon, prompt_template, tags)
                            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
                            ON CONFLICT (id) DO UPDATE SET
                                name = $2,
                                specialty = $3,
                                description = $4,
                                category = $5,
                                is_premium = $6,
                                is_safe = $7,
                                icon = $8,
                                prompt_template = $9,
                                tags = $10
                        """,
                            agent["id"],
                            agent["name"],
                            agent.get("specialty", agent.get("role", "")),
                            agent.get("description", ""),
                            agent.get("category", "general"),
                            agent.get("is_premium", False),
                            agent.get("is_safe", False),
                            agent.get("icon", "🤖"),
                            agent.get("prompt_template", ""),
                            agent.get("tags", [])
                        )
                    logger.info(f"✅ Загружено {len(self._agents)} агентов из AGENTS_50")
        except Exception as e:
            logger.error(f"❌ Ошибка БД: {e}, используем AGENTS_50")
            for agent in AGENTS_50:
                self._agents[agent["id"]] = agent
        self._loaded = True

    def get_agent(self, agent_id: str) -> Optional[Dict[str, Any]]:
        return self._agents.get(agent_id)

    def get_all_agents(self) -> List[Dict[str, Any]]:
        return list(self._agents.values())

    def get_stats(self):
        categories = {}
        premium = 0
        for agent in self._agents.values():
            cat = agent.get("category", "unknown")
            categories[cat] = categories.get(cat, 0) + 1
            if agent.get("is_premium"):
                premium += 1
        return {"total": len(self._agents), "categories": categories, "premium": premium}

_registry = None

def get_registry():
    global _registry
    if _registry is None:
        _registry = AgentRegistry()
    return _registry
