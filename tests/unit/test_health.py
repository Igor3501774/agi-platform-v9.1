from fastapi.testclient import TestClient
import sys
from pathlib import Path

# Добавляем путь к приложению
sys.path.insert(0, str(Path(__file__).parent.parent / "apps" / "backend"))

from app import app

client = TestClient(app)

def test_health_endpoint():
    """Проверка, что /health возвращает 200 и статус healthy"""
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "healthy"
