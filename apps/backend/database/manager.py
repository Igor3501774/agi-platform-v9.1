from contextlib import asynccontextmanager
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from config.settings import settings
from config.logger import logger
from .base import Base

class DatabaseManager:
    def __init__(self, database_url: str):
        self.database_url = database_url
        self._engine = None
        self._session_maker = None
    
    async def initialize(self):
        if self._engine:
            return
        self._engine = create_async_engine(self.database_url, pool_size=20, max_overflow=40, echo=False, pool_pre_ping=True)
        self._session_maker = async_sessionmaker(self._engine, class_=AsyncSession, expire_on_commit=False)
        async with self._engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
        logger.info("Database initialized")
    
    @asynccontextmanager
    async def session(self):
        if not self._session_maker:
            await self.initialize()
        async with self._session_maker() as session:
            try:
                yield session
                await session.commit()
            except Exception as e:
                await session.rollback()
                raise
            finally:
                await session.close()
    
    async def get_session(self):
        if not self._session_maker:
            await self.initialize()
        return self._session_maker()
    
    async def close(self):
        if self._engine:
            await self._engine.dispose()
