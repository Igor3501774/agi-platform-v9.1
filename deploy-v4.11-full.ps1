# =============================================================================
# AGI PLATFORM v4.11 — FULL DEPLOY & RUNTIME AUDIT (3-DAY FINAL)
# =============================================================================
# Запуск: powershell -ExecutionPolicy Bypass -File deploy-v4.11-full.ps1
# =============================================================================

$ProjectRoot = "C:\AGIPlatform"
$BackendPath = "$ProjectRoot\apps\backend"

Write-Host @"
╔═══════════════════════════════════════════════════════════════════════════╗
║                                                                           ║
║        🚀 AGI PLATFORM v4.11 — FULL DEPLOY & RUNTIME AUDIT              ║
║                                                                           ║
║  ДЕЙСТВИЯ:                                                                ║
║  1. Создание всех необходимых файлов (3-DAY FINAL)                       ║
║  2. Инициализация Qdrant (динамический размер)                            ║
║  3. Перезапуск контейнеров                                                ║
║  4. Запуск CORE/MEMORY/LEGACY аудита                                      ║
║                                                                           ║
╚═══════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

# =============================================================================
# 1. СОЗДАНИЕ ФАЙЛОВ (v4.11)
# =============================================================================

Write-Host "`n📁 1. СОЗДАНИЕ ФАЙЛОВ" -ForegroundColor Yellow
Write-Host ("=" * 60) -ForegroundColor Gray

# ----------------------------------------------------------------------------
# LLM_SERVICE.PY
# ----------------------------------------------------------------------------
Write-Host "`n  📄 Создание services/llm_service.py" -ForegroundColor Gray

@"
import asyncio
import logging
import uuid
from typing import Optional, Dict, Any, List

import httpx
from core.config import settings

logger = logging.getLogger(__name__)


class LLMService:

    def __init__(self):
        self.api_key = settings.DEEPSEEK_API_KEY
        self.model = settings.LLM_MODEL or "deepseek-chat"
        self.base_url = "https://api.deepseek.com/v1"
        self.client = httpx.AsyncClient(timeout=60.0)
        self._available = False
        self._provider = "unknown"
        self._last_request_id: Optional[str] = None

    async def check_availability(self) -> Dict[str, Any]:
        if not self.api_key:
            return {"available": False, "reason": "API key not configured"}

        try:
            response = await self.client.get(
                f"{self.base_url}/models",
                headers={"Authorization": f"Bearer {self.api_key}"},
                timeout=10.0
            )
            if response.status_code == 200:
                self._available = True
                self._provider = "deepseek"
                return {"available": True, "provider": "deepseek", "model": self.model}
            else:
                return {
                    "available": False,
                    "reason": f"API error: {response.status_code} - {response.text[:100]}"
                }
        except Exception as e:
            logger.error(f"LLM availability check failed: {e}")
            return {"available": False, "reason": str(e)}

    async def generate(
        self,
        prompt: str,
        system_prompt: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: int = 2000,
        **kwargs
    ) -> Dict[str, Any]:
        if not self.api_key:
            raise RuntimeError("DEEPSEEK_API_KEY not configured")

        request_id = str(uuid.uuid4())
        self._last_request_id = request_id

        messages = []
        if system_prompt:
            messages.append({"role": "system", "content": system_prompt})
        messages.append({"role": "user", "content": prompt})

        attempt_ids = []
        audit_trail = []
        last_error = None
        max_attempts = 2

        for attempt in range(max_attempts):
            attempt_id = str(uuid.uuid4())
            attempt_ids.append(attempt_id)
            attempt_start = asyncio.get_event_loop().time()

            try:
                logger.info(f"🔮 LLM request {request_id} attempt {attempt + 1}/{attempt_id}")

                response = await self.client.post(
                    f"{self.base_url}/chat/completions",
                    headers={
                        "Authorization": f"Bearer {self.api_key}",
                        "Content-Type": "application/json"
                    },
                    json={
                        "model": self.model,
                        "messages": messages,
                        "temperature": temperature,
                        "max_tokens": max_tokens,
                        **kwargs
                    }
                )

                attempt_duration = asyncio.get_event_loop().time() - attempt_start

                if response.status_code == 200:
                    data = response.json()
                    content = data["choices"][0]["message"]["content"]
                    upstream_request_id = data.get("id")
                    upstream_model = data.get("model", self.model)
                    upstream_usage = data.get("usage", {})

                    audit_trail.append({
                        "attempt": attempt + 1,
                        "attempt_id": attempt_id,
                        "status": "success",
                        "timestamp": attempt_start,
                        "duration": attempt_duration,
                        "upstream_request_id": upstream_request_id,
                        "upstream_status": response.status_code
                    })

                    logger.info(f"✅ LLM request {request_id} attempt {attempt + 1}: success")

                    return {
                        "content": content,
                        "provider": "deepseek",
                        "model": self.model,
                        "request_id": request_id,
                        "attempts": attempt + 1,
                        "attempt_ids": attempt_ids,
                        "upstream_status": response.status_code,
                        "upstream_request_id": upstream_request_id,
                        "upstream_model": upstream_model,
                        "upstream_usage": upstream_usage,
                        "audit_trail": audit_trail
                    }
                else:
                    error_msg = f"DeepSeek API error: {response.status_code} - {response.text[:200]}"
                    logger.error(f"❌ LLM request {request_id} attempt {attempt + 1}: {error_msg}")
                    
                    audit_trail.append({
                        "attempt": attempt + 1,
                        "attempt_id": attempt_id,
                        "status": "failed",
                        "timestamp": attempt_start,
                        "duration": attempt_duration,
                        "error": error_msg,
                        "upstream_status": response.status_code
                    })
                    
                    last_error = RuntimeError(error_msg)
                    if attempt < max_attempts - 1:
                        await asyncio.sleep(2 ** attempt)

            except Exception as e:
                attempt_duration = asyncio.get_event_loop().time() - attempt_start
                logger.error(f"❌ LLM request {request_id} attempt {attempt + 1}: {e}")
                
                audit_trail.append({
                    "attempt": attempt + 1,
                    "attempt_id": attempt_id,
                    "status": "error",
                    "timestamp": attempt_start,
                    "duration": attempt_duration,
                    "error": str(e)
                })
                
                last_error = e
                if attempt < max_attempts - 1:
                    await asyncio.sleep(2 ** attempt)

        audit_trail.append({
            "status": "final_failure",
            "timestamp": asyncio.get_event_loop().time(),
            "error": str(last_error) if last_error else "All attempts failed"
        })

        raise last_error or RuntimeError(f"LLM request {request_id} failed after {max_attempts} attempts")

    async def generate_simple(self, prompt: str) -> str:
        result = await self.generate(prompt)
        return result.get("content", "")

    def get_last_request_id(self) -> Optional[str]:
        return self._last_request_id


_llm_service: Optional[LLMService] = None


def get_llm_service() -> LLMService:
    global _llm_service
    if _llm_service is None:
        _llm_service = LLMService()
    return _llm_service
"@ | Out-File -FilePath "$BackendPath\services\llm_service.py" -Encoding UTF8

Write-Host "     ✅ services/llm_service.py создан" -ForegroundColor Green

# ----------------------------------------------------------------------------
# AGENT_SERVICE.PY
# ----------------------------------------------------------------------------
Write-Host "`n  📄 Создание services/agent_service.py" -ForegroundColor Gray

@"
import asyncio
import logging
from typing import Optional, Dict, Any, List
from datetime import datetime

from services.agent_registry import get_registry
from services.llm_service import get_llm_service
from services.memory_service import get_memory_service
from services.embedding_service import get_embedding_service
from core.config import settings

logger = logging.getLogger(__name__)


class AgentService:
    def __init__(self):
        self.registry = get_registry()
        self.llm_service = get_llm_service()
        self.memory_service = get_memory_service()
        self.embedding_service = get_embedding_service()
        self._initialized = False
        self._memory_available = False
        self._init_error: Optional[str] = None
        self._lock = asyncio.Lock()

    @property
    def is_core_ready(self) -> bool:
        return self._initialized

    @property
    def is_memory_ready(self) -> bool:
        return self._memory_available

    async def ensure_initialized(self) -> None:
        if self._initialized:
            return

        async with self._lock:
            if self._initialized:
                return

            errors = []

            try:
                await self.registry.ensure_loaded()
                logger.info("✅ AgentRegistry загружен")
            except Exception as e:
                errors.append(f"Registry: {e}")
                logger.error(f"❌ Registry error: {e}")

            try:
                llm_status = await self.llm_service.check_availability()
                if llm_status.get("available", False):
                    logger.info(
                        f"✅ LLM Service доступен: "
                        f"{llm_status.get('provider')}/{llm_status.get('model')}"
                    )
                else:
                    errors.append(f"LLM: {llm_status.get('reason', 'unavailable')}")
                    logger.error(f"❌ LLM error: {llm_status.get('reason')}")
            except Exception as e:
                errors.append(f"LLM: {e}")
                logger.error(f"❌ LLM error: {e}")

            if errors:
                self._init_error = "; ".join(errors)
                raise RuntimeError(f"AgentService CORE initialization failed: {self._init_error}")

            self._initialized = True
            logger.info("✅ AgentService CORE инициализирован")

            asyncio.create_task(self._init_memory())

    async def _init_memory(self) -> None:
        try:
            await self.embedding_service.ensure_loaded()
            logger.info(f"✅ EmbeddingService загружен (размер: {self.embedding_service.get_dimension()})")

            await self.memory_service.ensure_initialized()
            self._memory_available = True
            logger.info("✅ MemoryService инициализирован")
        except Exception as e:
            self._memory_available = False
            logger.warning(f"⚠️ Memory недоступна: {e}")

    async def process_message(
        self,
        agent_id: str,
        message: str,
        user_id: Optional[str] = None,
        context: Optional[Dict[str, Any]] = None
    ) -> Dict[str, Any]:
        start_time = datetime.utcnow()

        await self.ensure_initialized()

        test_id = context.get("test_id") if context else None
        if test_id:
            audit_entry = (
                f"AUDIT_CALL_PATH test_id={test_id} "
                f"service=AgentService method=process_message "
                f"agent_id={agent_id} timestamp={datetime.utcnow().isoformat()}"
            )
            logger.info(audit_entry)

        agent = await self.registry.get_agent(agent_id)

        if not agent:
            clean_id = agent_id.replace("agi_", "").replace("agent_", "")
            agent = await self.registry.get_agent(clean_id)

        if not agent:
            all_agents = await self.registry.get_all_agents()
            for a in all_agents:
                if a.get("name", "").lower() == agent_id.lower():
                    agent = a
                    break

        if not agent:
            raise ValueError(f"Agent '{agent_id}' not found")

        resolved_agent_id = agent.get("id", agent_id)

        agent_name = agent.get("name", "Ассистент")
        system_prompt = agent.get("system_prompt", "Ты полезный AI-ассистент.")
        description = agent.get("description", "")
        category = agent.get("category", "general")

        memories = []
        memory_used = False
        if self._memory_available:
            try:
                memories = await self.memory_service.search(
                    query=message,
                    agent_id=resolved_agent_id,
                    limit=5,
                    score_threshold=0.5,
                    audit_mode=bool(test_id)
                )
                memory_used = len(memories) > 0
            except Exception as e:
                if test_id:
                    raise
                logger.warning(f"Memory search failed: {e}")

        context_text = ""
        if memories:
            context_lines = []
            for i, m in enumerate(memories[:5], 1):
                text = m.get("text", "").strip()
                if text:
                    context_lines.append(f"{i}. {text}")
            if context_lines:
                context_text = "\n".join(context_lines)
                
            if test_id and any("test_id" in m for m in memories):
                logger.info(f"AUDIT_MEMORY_CONTEXT_INJECTED test_id={test_id}")

        prompt_parts = [
            f"Ты агент '{agent_name}'.",
            f"Категория: {category}.",
            f"Описание: {description}",
            f"Инструкция: {system_prompt}",
        ]

        if context_text:
            prompt_parts.append(f"\nКонтекст из памяти:\n{context_text}")

        if context:
            clean_context = {k: v for k, v in context.items() if k != "test_id"}
            if clean_context:
                prompt_parts.append(f"\nДополнительный контекст: {clean_context}")

        prompt_parts.append(f"\nПользователь: {message}")
        prompt_parts.append("\nДай профессиональный, подробный и полезный ответ.")

        prompt = "\n".join(prompt_parts)

        response = ""
        llm_response = None
        try:
            llm_response = await self.llm_service.generate(
                prompt=prompt,
                system_prompt=f"Ты {agent_name}. {description}",
                temperature=0.7,
                max_tokens=2000
            )
            response = llm_response.get("content", "")
            provider = llm_response.get("provider", "unknown")
            model = llm_response.get("model", "unknown")
            request_id = llm_response.get("request_id")
            upstream_request_id = llm_response.get("upstream_request_id")
            upstream_status = llm_response.get("upstream_status")
            attempts = llm_response.get("attempts", 0)
            audit_trail = llm_response.get("audit_trail", [])
            
            logger.debug(
                f"LLM ответ: provider={provider}, request_id={request_id}, "
                f"upstream_id={upstream_request_id}, upstream_status={upstream_status}"
            )
        except Exception as e:
            logger.error(f"LLM error: {e}")
            raise RuntimeError(f"LLM generation failed: {e}")

        if self._memory_available:
            try:
                memory_id = await self.memory_service.store(
                    agent_id=resolved_agent_id,
                    text=f"Вопрос: {message}\nОтвет: {response[:500]}",
                    metadata={
                        "user_id": user_id or "anonymous",
                        "type": "conversation",
                        "category": category,
                        "provider": provider,
                        "request_id": request_id,
                        "upstream_request_id": upstream_request_id,
                        "timestamp": datetime.utcnow().isoformat()
                    },
                    test_id=test_id
                )
                if test_id:
                    logger.info(f"AUDIT_MEMORY_STORE test_id={test_id} memory_id={memory_id}")
            except Exception as e:
                logger.warning(f"Memory store failed: {e}")

        return {
            "agent_id": resolved_agent_id,
            "agent_name": agent_name,
            "response": response,
            "category": category,
            "memories_used": len(memories),
            "memory_available": self._memory_available,
            "provider": provider,
            "model": model,
            "request_id": request_id,
            "upstream_request_id": upstream_request_id,
            "upstream_status": upstream_status,
            "attempts": attempts,
            "audit_trail": audit_trail,
            "test_id": test_id,
            "response_time": (datetime.utcnow() - start_time).total_seconds(),
            "timestamp": datetime.utcnow().isoformat()
        }

    async def get_agent_info(self, agent_id: str) -> Optional[Dict[str, Any]]:
        await self.ensure_initialized()
        return await self.registry.get_agent(agent_id)

    async def list_agents(
        self,
        category: Optional[str] = None,
        premium: Optional[bool] = None,
        safe_only: bool = False
    ) -> List[Dict[str, Any]]:
        await self.ensure_initialized()

        if category:
            return await self.registry.get_by_category(category)
        elif premium is not None:
            return await self.registry.get_by_premium(premium)
        elif safe_only:
            return await self.registry.get_by_safe()
        else:
            return await self.registry.get_all_agents()


_agent_service: Optional[AgentService] = None


def get_agent_service() -> AgentService:
    global _agent_service
    if _agent_service is None:
        _agent_service = AgentService()
    return _agent_service
"@ | Out-File -FilePath "$BackendPath\services\agent_service.py" -Encoding UTF8

Write-Host "     ✅ services/agent_service.py создан" -ForegroundColor Green

# ----------------------------------------------------------------------------
# MEMORY_SERVICE.PY
# ----------------------------------------------------------------------------
Write-Host "`n  📄 Создание services/memory_service.py" -ForegroundColor Gray

@"
import asyncio
import logging
import uuid
from datetime import datetime
from typing import Optional, List, Dict, Any, Tuple

from qdrant_client import QdrantClient
from qdrant_client.http import models
from qdrant_client.http.models import (
    Distance, VectorParams, PointStruct, Filter,
    FieldCondition, MatchValue, ScrollResult
)

from core.config import settings
from services.embedding_service import get_embedding_service

logger = logging.getLogger(__name__)


class QdrantAdapter:
    \"\"\"Адаптер для разных версий Qdrant API\"\"\"
    
    def __init__(self, client: QdrantClient):
        self.client = client
        self._has_search = hasattr(client, "search")
        self._has_query_points = hasattr(client, "query_points")
        self._version = self._detect_version()
    
    def _detect_version(self) -> str:
        try:
            import qdrant_client
            return qdrant_client.__version__
        except:
            return "unknown"
    
    def get_version(self) -> str:
        return self._version
    
    def search(self, collection_name: str, query_vector: List[float], **kwargs):
        if self._has_search:
            try:
                return self.client.search(
                    collection_name=collection_name,
                    query_vector=query_vector,
                    **kwargs
                )
            except Exception as e:
                logger.debug(f"search() failed: {e}, trying query_points()")
                if self._has_query_points:
                    result = self.client.query_points(
                        collection_name=collection_name,
                        query=query_vector,
                        **kwargs
                    )
                    return result.points
                raise
        elif self._has_query_points:
            result = self.client.query_points(
                collection_name=collection_name,
                query=query_vector,
                **kwargs
            )
            return result.points
        else:
            raise RuntimeError("No compatible search API found")
    
    def get_collection_info(self, collection_name: str):
        info = self.client.get_collection(collection_name)
        
        try:
            vector_size = info.config.params.vectors.size
        except AttributeError:
            try:
                vector_size = info.config.params.vectors_config.size
            except AttributeError:
                raise RuntimeError("Cannot determine vector dimension")
        
        return {
            "points_count": info.points_count,
            "vectors_count": info.vectors_count,
            "vector_size": vector_size,
            "indexes": getattr(info.config.params, "payload_indexes", [])
        }


class MemoryService:

    def __init__(self):
        self.client: Optional[QdrantClient] = None
        self.adapter: Optional[QdrantAdapter] = None
        self.collection_name = "memory_vectors"
        self.embedding_service = get_embedding_service()
        self._initialized = False
        self._lock = asyncio.Lock()
        self._vector_size: Optional[int] = None
        self._max_retries = 3

    async def get_vector_size(self) -> int:
        if self._vector_size is None:
            await self.embedding_service.ensure_loaded()
            self._vector_size = self.embedding_service.get_dimension()
        return self._vector_size

    async def _ensure_test_id_index(self) -> None:
        try:
            self.client.create_payload_index(
                collection_name=self.collection_name,
                field_name="test_id",
                field_schema="keyword"
            )
            logger.info("✅ Индекс test_id создан")
        except Exception as e:
            if "already exists" in str(e).lower():
                logger.info("✅ Индекс test_id уже существует")
            else:
                logger.error(f"❌ Не удалось создать индекс test_id: {e}")
                raise RuntimeError(f"test_id index creation failed: {e}")

    async def initialize(self) -> None:
        if self._initialized:
            return

        async with self._lock:
            if self._initialized:
                return

            for attempt in range(self._max_retries):
                try:
                    self.client = QdrantClient(
                        host=settings.QDRANT_HOST or "localhost",
                        port=int(settings.QDRANT_PORT or 6333),
                        timeout=30.0,
                        prefer_grpc=False
                    )
                    self.adapter = QdrantAdapter(self.client)
                    
                    logger.info(f"📦 Qdrant client version: {self.adapter.get_version()}")

                    self.client.get_collections()
                    vec_size = await self.get_vector_size()

                    collections = self.client.get_collections().collections
                    exists = any(c.name == self.collection_name for c in collections)

                    if not exists:
                        self.client.create_collection(
                            collection_name=self.collection_name,
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
                        logger.info(f"✅ Создана коллекция: {self.collection_name} (размер: {vec_size})")
                        await self._ensure_test_id_index()
                    else:
                        info = self.adapter.get_collection_info(self.collection_name)
                        actual_size = info["vector_size"]
                        
                        if actual_size != vec_size:
                            raise RuntimeError(
                                f"Qdrant vector dimension mismatch: "
                                f"collection={actual_size}, embedding={vec_size}"
                            )
                        logger.info(f"✅ Коллекция уже существует: {self.collection_name} (размер: {actual_size})")
                        
                        has_test_id_index = any(
                            idx.field_name == "test_id" 
                            for idx in info.get("indexes", [])
                        )
                        if not has_test_id_index:
                            logger.warning("⚠️ Индекс test_id отсутствует, создаю...")
                            await self._ensure_test_id_index()

                    self._initialized = True
                    logger.info("✅ MemoryService полностью инициализирован")
                    return

                except Exception as e:
                    logger.error(f"❌ Попытка {attempt + 1}/{self._max_retries} ошибка: {e}")
                    if attempt < self._max_retries - 1:
                        await asyncio.sleep(2 ** attempt)
                    else:
                        raise

    async def ensure_initialized(self) -> None:
        if not self._initialized:
            await self.initialize()

    async def store(
        self,
        agent_id: str,
        text: str,
        metadata: Optional[Dict[str, Any]] = None,
        embedding: Optional[List[float]] = None,
        test_id: Optional[str] = None
    ) -> str:
        await self.ensure_initialized()

        memory_id = str(uuid.uuid4())
        now = datetime.utcnow().isoformat()

        if embedding is None:
            embedding = await self.embedding_service.embed(text)

        expected_size = await self.get_vector_size()
        if len(embedding) != expected_size:
            raise ValueError(
                f"Размер эмбеддинга {len(embedding)} не соответствует "
                f"размеру коллекции {expected_size}"
            )

        payload = {
            "agent_id": agent_id,
            "content": text,
            "timestamp": now,
            "memory_id": memory_id,
            "created_at": now,
            "text_length": len(text),
        }

        if test_id:
            payload["test_id"] = test_id
            logger.debug(f"🧪 Сохранён test_id в payload: {test_id}")

        if metadata:
            payload["metadata"] = metadata
            if "category" in metadata:
                payload["category"] = metadata["category"]
            if "type" in metadata:
                payload["type"] = metadata["type"]

        try:
            self.client.upsert(
                collection_name=self.collection_name,
                points=[
                    PointStruct(
                        id=memory_id,
                        vector=embedding,
                        payload=payload
                    )
                ]
            )
            
            if test_id:
                logger.info(f"AUDIT_MEMORY_STORE test_id={test_id} memory_id={memory_id} agent_id={agent_id}")
            
            logger.debug(f"💾 Память сохранена: {memory_id} для агента {agent_id}")
            return memory_id

        except Exception as e:
            logger.error(f"❌ Ошибка сохранения памяти: {e}")
            raise

    async def search(
        self,
        query: str,
        agent_id: Optional[str] = None,
        limit: int = 10,
        score_threshold: float = 0.5,
        filter_metadata: Optional[Dict[str, Any]] = None,
        audit_mode: bool = False
    ) -> List[Dict[str, Any]]:
        await self.ensure_initialized()

        try:
            query_embedding = await self.embedding_service.embed(query)

            must_conditions = []

            if agent_id:
                must_conditions.append(
                    FieldCondition(
                        key="agent_id",
                        match=MatchValue(value=agent_id)
                    )
                )

            if filter_metadata:
                for key, value in filter_metadata.items():
                    must_conditions.append(
                        FieldCondition(
                            key=f"metadata.{key}",
                            match=MatchValue(value=value)
                        )
                    )

            filter_condition = Filter(must=must_conditions) if must_conditions else None

            search_result = self.adapter.search(
                collection_name=self.collection_name,
                query_vector=query_embedding,
                limit=limit,
                query_filter=filter_condition,
                score_threshold=score_threshold,
                with_payload=True
            )

            results = []
            retrieved_test_ids = []
            retrieved_memory_ids = []
            
            for point in search_result:
                result = {
                    "id": point.id,
                    "score": point.score,
                    "text": point.payload.get("content", ""),
                    "agent_id": point.payload.get("agent_id", ""),
                    "timestamp": point.payload.get("timestamp", ""),
                    "created_at": point.payload.get("created_at", ""),
                    "memory_id": point.payload.get("memory_id", ""),
                }
                if "metadata" in point.payload:
                    result["metadata"] = point.payload["metadata"]
                if "category" in point.payload:
                    result["category"] = point.payload["category"]
                if "test_id" in point.payload:
                    result["test_id"] = point.payload["test_id"]
                    retrieved_test_ids.append(point.payload["test_id"])
                if "memory_id" in point.payload:
                    retrieved_memory_ids.append(point.payload["memory_id"])
                results.append(result)

            if retrieved_test_ids:
                logger.info(f"AUDIT_MEMORY_RETRIEVAL test_ids={','.join(retrieved_test_ids)}")
                
            if retrieved_memory_ids and retrieved_test_ids:
                logger.info(
                    f"AUDIT_MEMORY_CONTEXT_INJECTED test_ids={','.join(retrieved_test_ids)} "
                    f"memory_ids={','.join(retrieved_memory_ids[:3])}"
                )

            logger.debug(f"🔍 Найдено {len(results)} результатов по запросу")
            return results

        except Exception as e:
            logger.error(f"❌ Ошибка поиска: {e}")
            if audit_mode:
                raise
            return []

    async def search_by_test_id(
        self,
        test_id: str,
        agent_id: Optional[str] = None,
        limit: int = 10,
        audit_mode: bool = False
    ) -> List[Dict[str, Any]]:
        await self.ensure_initialized()

        try:
            must_conditions = [
                FieldCondition(
                    key="test_id",
                    match=MatchValue(value=test_id)
                )
            ]

            if agent_id:
                must_conditions.append(
                    FieldCondition(
                        key="agent_id",
                        match=MatchValue(value=agent_id)
                    )
                )

            filter_condition = Filter(must=must_conditions)

            scroll_result = self.client.scroll(
                collection_name=self.collection_name,
                scroll_filter=filter_condition,
                limit=limit,
                with_payload=True,
                with_vectors=False
            )

            points, _ = scroll_result

            results = []
            for point in points:
                results.append({
                    "id": point.id,
                    "text": point.payload.get("content", ""),
                    "agent_id": point.payload.get("agent_id", ""),
                    "timestamp": point.payload.get("timestamp", ""),
                    "created_at": point.payload.get("created_at", ""),
                    "test_id": point.payload.get("test_id", ""),
                    "memory_id": point.payload.get("memory_id", ""),
                    "metadata": point.payload.get("metadata", {})
                })

            if audit_mode and not results:
                raise RuntimeError(f"test_id={test_id} not found in Qdrant")

            return results

        except Exception as e:
            logger.error(f"❌ Ошибка поиска по test_id: {e}")
            if audit_mode:
                raise
            return []

    async def get_stats(self) -> Dict[str, Any]:
        await self.ensure_initialized()

        try:
            info = self.adapter.get_collection_info(self.collection_name)

            return {
                "collection_name": self.collection_name,
                "points_count": info["points_count"],
                "vectors_count": info["vectors_count"],
                "vector_size": info["vector_size"],
                "qdrant_version": self.adapter.get_version(),
                "status": "healthy"
            }
        except Exception as e:
            logger.error(f"❌ Ошибка получения статистики: {e}")
            return {
                "collection_name": self.collection_name,
                "status": "error",
                "error": str(e)
            }


_memory_service: Optional[MemoryService] = None


def get_memory_service() -> MemoryService:
    global _memory_service
    if _memory_service is None:
        _memory_service = MemoryService()
    return _memory_service
"@ | Out-File -FilePath "$BackendPath\services\memory_service.py" -Encoding UTF8

Write-Host "     ✅ services/memory_service.py создан" -ForegroundColor Green

# ----------------------------------------------------------------------------
# INIT_QDRANT.PY
# ----------------------------------------------------------------------------
Write-Host "`n  📄 Создание scripts/init_qdrant.py" -ForegroundColor Gray

if (-not (Test-Path "$BackendPath\scripts")) {
    New-Item -ItemType Directory -Path "$BackendPath\scripts" -Force | Out-Null
}

@"
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
"@ | Out-File -FilePath "$BackendPath\scripts\init_qdrant.py" -Encoding UTF8

Write-Host "     ✅ scripts/init_qdrant.py создан" -ForegroundColor Green

# =============================================================================
# 2. ИНИЦИАЛИЗАЦИЯ QDRANT
# =============================================================================

Write-Host "`n🔧 2. ИНИЦИАЛИЗАЦИЯ QDRANT" -ForegroundColor Yellow
Write-Host ("=" * 60) -ForegroundColor Gray

Push-Location $BackendPath
$env:PYTHONPATH = "."
python scripts\init_qdrant.py
$QDRANT_EXIT = $LASTEXITCODE
Pop-Location

if ($QDRANT_EXIT -ne 0) {
    Write-Host "  ❌ Qdrant инициализация не удалась (код: $QDRANT_EXIT)" -ForegroundColor Red
    Write-Host "`n"
    Write-Host "Нажмите Enter для выхода..." -ForegroundColor Yellow
    Read-Host
    exit 1
}

Write-Host "  ✅ Qdrant инициализирован" -ForegroundColor Green

# =============================================================================
# 3. ПЕРЕЗАПУСК КОНТЕЙНЕРОВ
# =============================================================================

Write-Host "`n🐳 3. ПЕРЕЗАПУСК КОНТЕЙНЕРОВ" -ForegroundColor Yellow
Write-Host ("=" * 60) -ForegroundColor Gray

cd $ProjectRoot\deployment\docker
docker-compose restart backend

Write-Host "  ⏳ Ожидание запуска (30 сек)..." -ForegroundColor Gray
Start-Sleep -Seconds 30

try {
    $health = Invoke-WebRequest -Uri "http://localhost:5001/health" -UseBasicParsing -ErrorAction Stop
    if ($health.StatusCode -eq 200) {
        Write-Host "  ✅ Backend запущен" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️ Backend не отвечает (код: $($health.StatusCode))" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ⚠️ Backend не отвечает: $($_.Exception.Message)" -ForegroundColor Yellow
}

# =============================================================================
# 4. ЗАПУСК АУДИТА
# =============================================================================

Write-Host "`n🔬 4. ЗАПУСК АУДИТА v4.11" -ForegroundColor Yellow
Write-Host ("=" * 60) -ForegroundColor Gray

$auditScript = "$ProjectRoot\audit-core-v4.11.ps1"

if (-not (Test-Path $auditScript)) {
    Write-Host "  ❌ Файл не найден: $auditScript" -ForegroundColor Red
    Write-Host "`n"
    Write-Host "Нажмите Enter для выхода..." -ForegroundColor Yellow
    Read-Host
    exit 1
}

powershell -ExecutionPolicy Bypass -File $auditScript
$AUDIT_EXIT = $LASTEXITCODE

if ($AUDIT_EXIT -ne 0) {
    Write-Host "`n"
    Write-Host "❌ DEPLOY BLOCKED: AUDIT FAILED (код: $AUDIT_EXIT)" -ForegroundColor Red
    Write-Host "`n"
    Write-Host "Нажмите Enter для выхода..." -ForegroundColor Yellow
    Read-Host
    exit 1
}

# =============================================================================
# 5. ЗАВЕРШЕНИЕ
# =============================================================================

Write-Host "`n"
Write-Host "✅ DEPLOY + AUDIT PASSED" -ForegroundColor Green
Write-Host "📍 Логи: docker logs docker-backend-1" -ForegroundColor Gray
Write-Host "📍 Аудит: audit-core-v4.11.ps1" -ForegroundColor Gray
Write-Host ""

Write-Host "Нажмите Enter для выхода..." -ForegroundColor Yellow
Read-Host
