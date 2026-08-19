# ============================================================================
# AGI PLATFORM v9.0 — ЧАСТЬ 9: ФИНАЛЬНАЯ
# ============================================================================

$ProjectRoot = "C:\AGIPlatform"

Write-Host "🏁 ЧАСТЬ 9: ФИНАЛЬНАЯ" -ForegroundColor Cyan

function New-File {
    param($path, $content)
    $fullPath = Join-Path $ProjectRoot $path
    $dir = Split-Path $fullPath -Parent
    if (!(Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $content | Out-File -FilePath $fullPath -Encoding UTF8 -Force
    Write-Host "  📄 $path" -ForegroundColor Yellow
}

Write-Host "`n📄 СОЗДАНИЕ ОСТАВШИХСЯ ФАЙЛОВ..." -ForegroundColor Cyan

$testDeepseekContent = @'
import pytest
from unittest.mock import AsyncMock, Mock, patch
from services.deepseek_service import DeepSeekService

class TestDeepSeekService:
    @pytest.fixture
    def service(self):
        with patch('openai.AsyncOpenAI') as mock:
            return DeepSeekService()
    
    @pytest.mark.asyncio
    async def test_chat_success(self, service):
        mock_response = Mock()
        mock_response.choices = [Mock()]
        mock_response.choices[0].message.content = "Test response"
        mock_response.choices[0].finish_reason = "stop"
        mock_response.model = "deepseek-chat"
        mock_response.usage = Mock()
        mock_response.usage.prompt_tokens = 10
        mock_response.usage.completion_tokens = 20
        mock_response.usage.total_tokens = 30
        service.client.chat.completions.create = AsyncMock(return_value=mock_response)
        result = await service.chat(messages=[{"role": "user", "content": "Hello"}])
        assert result["content"] == "Test response"
'@
New-File "apps/backend/tests/unit/test_deepseek.py" $testDeepseekContent

$testApiContent = @'
import pytest
from httpx import AsyncClient, ASGITransport
from app import app

@pytest.mark.asyncio
async def test_health():
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        response = await client.get("/health")
        assert response.status_code == 200
        assert response.json()["status"] == "healthy"
'@
New-File "apps/backend/tests/integration/test_api.py" $testApiContent

$agentRegistryContent = @'
import yaml
from pathlib import Path
from typing import Dict, Any, Optional, List
from config.logger import logger

class AgentRegistry:
    def __init__(self, registry_dir: str = "agents/registry"):
        self.registry_dir = Path(registry_dir)
        self._agents: Dict[str, Dict] = {}
        self._load_all()
    
    def _load_all(self):
        if not self.registry_dir.exists():
            logger.warning(f"Registry directory not found: {self.registry_dir}")
            return
        count = 0
        for file in self.registry_dir.glob("*.yaml"):
            try:
                with open(file, "r", encoding="utf-8") as f:
                    data = yaml.safe_load(f)
                    self._agents[data["id"]] = data
                    count += 1
            except Exception as e:
                logger.error(f"Failed to load agent {file}: {e}")
        logger.info(f"Loaded {count} agents")
    
    def get_agent(self, agent_id: str) -> Optional[Dict]:
        return self._agents.get(agent_id)
    
    def get_all_agents(self) -> List[Dict]:
        return list(self._agents.values())
    
    def get_stats(self) -> Dict[str, Any]:
        return {"total": len(self._agents)}
'@
New-File "apps/backend/services/agent_registry.py" $agentRegistryContent

$promptServiceContent = @'
import yaml
from pathlib import Path
from typing import Dict, Any, Optional
from config.logger import logger

class PromptService:
    def __init__(self, prompts_dir: str = "prompts"):
        self.prompts_dir = Path(prompts_dir)
        self._prompts: Dict[str, Dict] = {}
        self._load_all()
    
    def _load_all(self):
        if not self.prompts_dir.exists():
            logger.warning(f"Prompts directory not found: {self.prompts_dir}")
            return
        for file in self.prompts_dir.glob("**/*.yaml"):
            try:
                with open(file, "r", encoding="utf-8") as f:
                    data = yaml.safe_load(f)
                    name = file.stem
                    self._prompts[name] = data
            except Exception as e:
                logger.error(f"Failed to load prompt {file}: {e}")
        logger.info(f"Loaded {len(self._prompts)} prompts")
    
    def get_prompt(self, name: str) -> Optional[str]:
        data = self._prompts.get(name, {})
        return data.get("system", "")
'@
New-File "apps/backend/services/prompt_service.py" $promptServiceContent

$tokenCounterContent = @'
def count_tokens(text: str) -> int:
    if not text:
        return 0
    return len(text) // 4
'@
New-File "apps/backend/utils/token_counter.py" $tokenCounterContent

Write-Host "`n✅ ФИНАЛЬНАЯ ЧАСТЬ ГОТОВА!" -ForegroundColor Green
Write-Host "📁 Проект: $ProjectRoot" -ForegroundColor Yellow

Write-Host "`n🚀 ВСЕ ЧАСТИ УСТАНОВЛЕНЫ!" -ForegroundColor Cyan
Write-Host "`n📋 ДАЛЬНЕЙШИЕ ДЕЙСТВИЯ:" -ForegroundColor Yellow
Write-Host "  1. cd $ProjectRoot" -ForegroundColor Gray
Write-Host "  2. copy .env.example .env" -ForegroundColor Gray
Write-Host "  3. Заполните .env (DEEPSEEK_API_KEY, JWT_SECRET_KEY)" -ForegroundColor Gray
Write-Host "  4. cd apps/backend && pip install -r requirements/base.txt" -ForegroundColor Gray
Write-Host "  5. cd deployment/docker && docker-compose up -d" -ForegroundColor Gray
Write-Host "  6. python apps/backend/app.py" -ForegroundColor Gray
Write-Host "  7. Откройте http://localhost:5001/api/docs" -ForegroundColor Gray
Write-Host ""