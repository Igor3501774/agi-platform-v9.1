# ============================================================================
# AGI PLATFORM v9.0 — ПОЛНАЯ ПРОВЕРКА ПРОЕКТА (FIXED)
# ============================================================================

$ProjectRoot = "C:\AGIPlatform"

Write-Host "🔍 AGI PLATFORM v9.0 — ПОЛНАЯ ПРОВЕРКА" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Gray

# 1. DOCKER
Write-Host "`n🐳 1. ПРОВЕРКА DOCKER" -ForegroundColor Yellow
docker --version 2>$null
docker ps --format "table {{.Names}}\t{{.Status}}"

# 2. BACKEND
Write-Host "`n🚀 2. ПРОВЕРКА BACKEND" -ForegroundColor Yellow
try {
    $r = Invoke-WebRequest -Uri "http://localhost:5001/health" -UseBasicParsing -ErrorAction Stop
    Write-Host "  ✅ Backend: $(($r.Content | ConvertFrom-Json).status)" -ForegroundColor Green
} catch {
    Write-Host "  ❌ Backend не отвечает!" -ForegroundColor Red
}

# 3. AGENTS
Write-Host "`n🤖 3. ПРОВЕРКА АГЕНТОВ" -ForegroundColor Yellow
try {
    $r = Invoke-WebRequest -Uri "http://localhost:5001/api/v1/agents" -UseBasicParsing -ErrorAction Stop
    $agents = $r.Content | ConvertFrom-Json
    Write-Host "  ✅ Агентов: $($agents.agents.Count)" -ForegroundColor Green
} catch {
    Write-Host "  ❌ Агенты не загружены!" -ForegroundColor Red
}

# 4. STATS
Write-Host "`n📊 4. СТАТИСТИКА" -ForegroundColor Yellow
try {
    $r = Invoke-WebRequest -Uri "http://localhost:5001/api/v1/agents/stats" -UseBasicParsing -ErrorAction Stop
    $stats = $r.Content | ConvertFrom-Json
    Write-Host "  Всего: $($stats.total)" -ForegroundColor Gray
    Write-Host "  Премиум: $($stats.premium)" -ForegroundColor Gray
    Write-Host "  Безопасные: $($stats.safe)" -ForegroundColor Gray
} catch {
    Write-Host "  ❌ Статистика не доступна!" -ForegroundColor Red
}

# 5. ИТОГ
Write-Host "`n" + "=" * 60 -ForegroundColor Gray
Write-Host "✅ ПРОВЕРКА ЗАВЕРШЕНА!" -ForegroundColor Green
