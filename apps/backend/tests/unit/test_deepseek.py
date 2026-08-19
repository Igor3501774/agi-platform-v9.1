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
