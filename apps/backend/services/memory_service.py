
class MemoryService:
    \"\"\"Сервис для работы с памятью агентов\"\"\"
    
    @staticmethod
    def save_to_memory(agent_id: str, text: str, embedding: List[float], metadata: Optional[dict] = None):
        return save_to_memory(agent_id, text, embedding, metadata)
    
    @staticmethod
    def search_memory(agent_id: str, query_embedding: List[float], limit: int = 10) -> List[dict]:
        return search_memory(agent_id, query_embedding, limit)
    
    @staticmethod
    def delete_from_memory(memory_id: str) -> bool:
        return delete_from_memory(memory_id)
    
    @staticmethod
    def ensure_collection():
        return ensure_collection()

import os
import time
import logging
from typing import List, Optional, Dict, Any

from qdrant_client import QdrantClient
from qdrant_client.http import models

logger = logging.getLogger(__name__)

QDRANT_URL = os.getenv("QDRANT_URL", "http://qdrant:6333")
COLLECTION_NAME = "agi_memory"
VECTOR_SIZE = int(os.getenv("QDRANT_VECTOR_SIZE", "768"))

client = QdrantClient(url=QDRANT_URL, timeout=10)

def ensure_collection():
    """Создаёт коллекцию если она не существует"""
    max_retries = 15
    for attempt in range(max_retries):
        try:
            if not client.collection_exists(collection_name=COLLECTION_NAME):
                logger.info(f"Creating collection {COLLECTION_NAME}...")
                client.create_collection(
                    collection_name=COLLECTION_NAME,
                    vectors_config=models.VectorParams(
                        size=VECTOR_SIZE,
                        distance=models.Distance.COSINE,
                    )
                )
                logger.info(f"Collection {COLLECTION_NAME} created")
            return True
        except Exception as e:
            logger.warning(f"Attempt {attempt + 1}/{max_retries} failed: {e}")
            if attempt == max_retries - 1:
                logger.error(f"Failed to create collection: {e}")
                raise e
            time.sleep(3)

def save_to_memory(agent_id: str, text: str, embedding: List[float], metadata: Optional[dict] = None):
    """Сохраняет текст в память"""
    try:
        ensure_collection()
        
        payload = {"agent_id": agent_id, "text": text}
        if metadata:
            payload.update(metadata)
        
        # ✅ Добавляем ID для отслеживания
        import uuid
        point_id = str(uuid.uuid4())
        
        client.upsert(
            collection_name=COLLECTION_NAME,
            points=[
                models.PointStruct(
                    id=point_id,
                    vector=embedding,
                    payload=payload,
                )
            ]
        )
        logger.info(f"Saved to memory: agent_id={agent_id}, text={text[:50]}...")
        return {"memory_id": point_id, "status": "success"}
    except Exception as e:
        logger.error(f"Failed to save to memory: {e}")
        raise e

def search_memory(agent_id: str, query_embedding: List[float], limit: int = 10) -> List[dict]:
    """Ищет в памяти по эмбеддингу"""
    try:
        ensure_collection()
        
        # ✅ Проверяем, что коллекция существует и содержит точки
        collection_info = client.get_collection(collection_name=COLLECTION_NAME)
        if collection_info.points_count == 0:
            logger.warning(f"Collection {COLLECTION_NAME} is empty")
            return []
        
        logger.info(f"Searching memory for agent_id={agent_id}, limit={limit}")
        
        results = client.search(
            collection_name=COLLECTION_NAME,
            query_vector=query_embedding,
            limit=limit,
            query_filter=models.Filter(
                must=[
                    models.FieldCondition(
                        key="agent_id",
                        match=models.MatchValue(value=agent_id),
                    )
                ]
            )
        )
        
        logger.info(f"Found {len(results)} results")
        
        return [
            {
                "text": r.payload.get("text", ""),
                "score": r.score,
                "id": r.id,
                "metadata": {k: v for k, v in r.payload.items() if k not in ["agent_id", "text"]}
            }
            for r in results
        ]
    except Exception as e:
        logger.error(f"Search memory error: {e}", exc_info=True)
        # ✅ Возвращаем пустой список, но логируем ошибку
        return []

def delete_from_memory(memory_id: str) -> bool:
    """Удаляет запись из памяти"""
    try:
        client.delete(
            collection_name=COLLECTION_NAME,
            points_selector=models.PointIdsList(points=[memory_id])
        )
        logger.info(f"Deleted memory {memory_id}")
        return True
    except Exception as e:
        logger.error(f"Failed to delete memory: {e}")
        return False

