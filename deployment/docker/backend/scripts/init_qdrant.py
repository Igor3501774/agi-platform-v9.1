#!/usr/bin/env python3
import asyncio
import logging
import sys
import os
from pathlib import Path

BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

try:
    from core.config import settings
except:
    class Settings:
        QDRANT_HOST = os.getenv("QDRANT_HOST", "localhost")
        QDRANT_PORT = os.getenv("QDRANT_PORT", 6333)
    settings = Settings()

from qdrant_client import QdrantClient
from qdrant_client.http.models import VectorParams, Distance

try:
    from services.embedding_service import get_embedding_service
except:
    class Dummy:
        async def ensure_loaded(self): pass
        def get_dimension(self): return 384
    def get_embedding_service(): return Dummy()

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


async def init_qdrant():
    logger.info("🚀 Инициализация Qdrant...")

    try:
        embedding_service = get_embedding_service()
        await embedding_service.ensure_loaded()
        vec_size = embedding_service.get_dimension()
        logger.info(f"📊 Размер эмбеддинга: {vec_size}")

        client = QdrantClient(
            host=settings.QDRANT_HOST or "localhost",
            port=int(settings.QDRANT_PORT or 6333),
            timeout=30.0,
            prefer_grpc=False
        )

        collections = client.get_collections()
        logger.info(f"✅ Подключено к Qdrant. Коллекций: {len(collections.collections)}")

        collection_name = "memory_vectors"
        exists = any(c.name == collection_name for c in collections.collections)

        if exists:
            try:
                info = client.get_collection(collection_name)
                actual_size = info.config.params.vectors.size
            except AttributeError:
                actual_size = info.vectors_count
                logger.warning(f"⚠️ Используется fallback для определения размера: {actual_size}")

            if actual_size != vec_size:
                logger.error(f"❌ Dimension mismatch: collection={actual_size}, embedding={vec_size}")
                logger.error("   Требуется пересоздать коллекцию с правильным размером")
                sys.exit(1)

            logger.info(f"✅ Коллекция {collection_name} уже существует (размер: {actual_size})")
            logger.info(f"   Точки: {info.points_count}")
            logger.info(f"   Векторы: {info.vectors_count}")
            
            try:
                indexes = info.config.params.payload_indexes
                hasTestId = any(idx.field_name == "test_id" for idx in indexes)
                if not hasTestId:
                    client.create_payload_index(
                        collection_name=collection_name,
                        field_name="test_id",
                        field_schema="keyword"
                    )
                    logger.info("✅ Индекс test_id создан для существующей коллекции")
            except Exception as e:
                logger.warning(f"⚠️ Не удалось проверить/создать индекс test_id: {e}")
            
            return

        logger.info(f"📦 Создание коллекции {collection_name} (размер: {vec_size})...")
        client.create_collection(
            collection_name=collection_name,
            vectors_config=VectorParams(
                size=vec_size,
                distance=Distance.COSINE
            ),
            optimizers_config={
                "default_segment_number": 2,
                "memmap_threshold": 20000
            },
            wal_config={
                "wal_capacity_mb": 32
            }
        )
        logger.info(f"✅ Коллекция {collection_name} создана")

        logger.info("📊 Создание индексов...")
        for field in ["agent_id", "timestamp", "test_id", "category"]:
            try:
                client.create_payload_index(
                    collection_name=collection_name,
                    field_name=field,
                    field_schema="keyword"
                )
            except Exception as e:
                logger.warning(f"⚠️ Не удалось создать индекс для {field}: {e}")
        logger.info("✅ Индексы созданы")

        logger.info(f"🎉 Qdrant полностью инициализирован (размер: {vec_size})")

    except Exception as e:
        logger.error(f"❌ Ошибка: {e}")
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(init_qdrant())
