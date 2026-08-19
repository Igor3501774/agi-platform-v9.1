from contextlib import asynccontextmanager
from config.logger import logger

class UnitOfWork:
    def __init__(self, session_factory):
        self.session_factory = session_factory
        self._session = None
    
    @asynccontextmanager
    async def begin(self):
        async with self.session_factory() as session:
            self._session = session
            try:
                yield self
                await self.commit()
            except Exception as e:
                await self.rollback()
                logger.error(f"Transaction failed: {e}")
                raise
            finally:
                await self.close()
    
    async def commit(self):
        if self._session:
            await self._session.commit()
    
    async def rollback(self):
        if self._session:
            await self._session.rollback()
    
    async def close(self):
        if self._session:
            await self._session.close()
