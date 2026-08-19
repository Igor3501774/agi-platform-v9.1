# ============================================================================
# AGI PLATFORM — АУДИТ ЯДРА v4.11 (RUNTIME VERIFICATION)
# ============================================================================
# Запуск: powershell -ExecutionPolicy Bypass -File audit-core-v4.11.ps1
# ============================================================================

$ProjectRoot = "C:\AGIPlatform"
$BackendUrl = "http://localhost:5001"
$QdrantUrl = "http://localhost:6333"

$BackendContainer = docker-compose ps -q backend 2>$null
if (-not $BackendContainer) {
    $BackendContainer = "docker-backend-1"
}

$global:AuditFatalError = $null
$Results = @{}
$PASSED = 0
$FAILED = 0

function Write-Result {
    param($testId, $status, $message, $details = "")
    if ($status -eq "PASS") {
        Write-Host "  ✅ $message" -ForegroundColor Green
        $Results[$testId] = $true
        $script:PASSED++
    } elseif ($status -eq "FAIL") {
        Write-Host "  ❌ $message" -ForegroundColor Red
        $Results[$testId] = $false
        $script:FAILED++
    }
    if ($details) {
        Write-Host "     $details" -ForegroundColor Gray
    }
}

function Test-Terminal {
    param($testId, $status, $message, $details = "")
    Write-Result -testId $testId -status $status -message $message -details $details
    if ($status -eq "FAIL") {
        throw [System.Exception]"TERMINAL_FAIL_${testId}_${message}"
    }
}

# ============================================================================
# MAIN
# ============================================================================

try {

Write-Host @"
╔═══════════════════════════════════════════════════════════════════════════╗
║                                                                           ║
║        🔬 AGI PLATFORM — АУДИТ ЯДРА v4.11 (RUNTIME)                     ║
║                                                                           ║
║  УРОВНИ ДОКАЗАТЕЛЬСТВА:                                                   ║
║  LEVEL 1 — CONFIG: настройки существуют                                   ║
║  LEVEL 2 — CALL PATH: нужный компонент реально вызван                    ║
║  LEVEL 3 — UPSTREAM PROOF: внешний сервис реально ответил                ║
║  LEVEL 4 — STATE PROOF: результат реально появился там, где должен      ║
║                                                                           ║
║  ⚠️ TERMINAL FAIL: любая критическая проверка останавливает аудит      ║
║  Все 10 тестов являются TERMINAL                                         ║
║  ✅ Итоговый отчёт печатается даже при TERMINAL FAIL                     ║
║                                                                           ║
╚═══════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

# CORE GATE
Write-Host "`n" + ("=" * 60) -ForegroundColor Gray
Write-Host "🔷 CORE GATE" -ForegroundColor Cyan
Write-Host ("=" * 60) -ForegroundColor Gray

# 1
Write-Host "`n🤖 1. 50+ АГЕНТОВ ЗАГРУЖЕНЫ (LEVEL 1+2)" -ForegroundColor Yellow
Write-Host ("-" * 60) -ForegroundColor Gray

try {
    $response = Invoke-WebRequest -Uri "$BackendUrl/api/v1/agents/stats" -UseBasicParsing -ErrorAction Stop
    if ($response.StatusCode -eq 200) {
        $data = $response.Content | ConvertFrom-Json
        if ($data.total -ge 50 -and $data.invalid -eq 0) {
            Write-Result 1 "PASS" "50+ агентов загружены, все валидны ($($data.total))"
            Write-Host "     Категории: $($data.categories.PSObject.Properties.Count)" -ForegroundColor Gray
        } else {
            Test-Terminal 1 "FAIL" "Агентов: $($data.total), невалидных: $($data.invalid)"
        }
    } else {
        Test-Terminal 1 "FAIL" "API не отвечает"
    }
} catch {
    if ($_.Exception.Message -match "TERMINAL_FAIL") { throw }
    Test-Terminal 1 "FAIL" "Не удалось получить агентов: $($_.Exception.Message)"
}

# 2
Write-Host "`n🧠 2. AGENTSERVICE ФУНКЦИОНАЛЬНО ОТВЕЧАЕТ (LEVEL 1)" -ForegroundColor Yellow
Write-Host ("-" * 60) -ForegroundColor Gray

try {
    $body = '{"agent_id":"assistant","message":"Привет"}'
    $response = Invoke-WebRequest -Uri "$BackendUrl/api/v1/chat/send" -Method POST -Body $body -ContentType "application/json" -UseBasicParsing -ErrorAction Stop
    
    if ($response.StatusCode -eq 200) {
        $data = $response.Content | ConvertFrom-Json
        if ($data.success -and $data.data.response -and $data.data.provider) {
            Write-Result 2 "PASS" "AgentService функционально отвечает"
            Write-Host "     Provider: $($data.data.provider)" -ForegroundColor Gray
        } else {
            Test-Terminal 2 "FAIL" "Ответ пустой или некорректный"
        }
    } else {
        Test-Terminal 2 "FAIL" "Chat API не отвечает (код: $($response.StatusCode))"
    }
} catch {
    if ($_.Exception.Message -match "TERMINAL_FAIL") { throw }
    Test-Terminal 2 "FAIL" "Не удалось отправить сообщение: $($_.Exception.Message)"
}

# 3
Write-Host "`n🤖 3. DEEPSEEK РЕАЛЬНО ВЫЗВАН (LEVEL 3)" -ForegroundColor Yellow
Write-Host ("-" * 60) -ForegroundColor Gray

try {
    $testId = "DEEPSEEK_AUDIT_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    $body = '{"agent_id":"assistant","message":"Ответь одним словом: ' + $testId + '","context":{"test_id":"' + $testId + '"}}'
    $response = Invoke-WebRequest -Uri "$BackendUrl/api/v1/chat/send" -Method POST -Body $body -ContentType "application/json" -UseBasicParsing -ErrorAction Stop
    
    if ($response.StatusCode -ne 200) {
        Test-Terminal 3 "FAIL" "API не отвечает"
    }
    
    $data = $response.Content | ConvertFrom-Json
    
    if ($data.data.provider -ne "deepseek") {
        Test-Terminal 3 "FAIL" "Используется другой провайдер: $($data.data.provider)"
    }
    
    if (-not $data.data.request_id) {
        Test-Terminal 3 "FAIL" "request_id отсутствует"
    }
    
    if (-not $data.data.upstream_request_id) {
        Test-Terminal 3 "FAIL" "upstream_request_id отсутствует"
    }
    
    if ($data.data.upstream_status -ne 200) {
        Test-Terminal 3 "FAIL" "Upstream status: $($data.data.upstream_status)"
    }
    
    if (-not $data.data.audit_trail -or $data.data.audit_trail.Count -eq 0) {
        Test-Terminal 3 "FAIL" "audit_trail отсутствует"
    }
    
    $successAttempt = $null
    foreach ($attempt in $data.data.audit_trail) {
        if ($attempt.status -eq "success" -and $attempt.upstream_request_id) {
            $successAttempt = $attempt
            break
        }
    }
    
    if (-not $successAttempt) {
        Test-Terminal 3 "FAIL" "Успешная upstream-попытка не найдена в audit_trail"
    }
    
    if ($successAttempt.upstream_request_id -ne $data.data.upstream_request_id) {
        Test-Terminal 3 "FAIL" "upstream_request_id не совпадает с успешной попыткой"
    }
    
    Write-Result 3 "PASS" "DeepSeek реально вызван (LEVEL 3)"
    Write-Host "     Upstream ID: $($data.data.upstream_request_id)" -ForegroundColor Gray
    Write-Host "     Attempts: $($data.data.attempts)" -ForegroundColor Gray
    
} catch {
    if ($_.Exception.Message -match "TERMINAL_FAIL") { throw }
    Test-Terminal 3 "FAIL" "Не удалось проверить DeepSeek: $($_.Exception.Message)"
}

# 4
Write-Host "`n🔄 4. MULTI-AGENT РЕАЛЬНО ВЫПОЛНЕН (LEVEL 2)" -ForegroundColor Yellow
Write-Host ("-" * 60) -ForegroundColor Gray

try {
    $testId = "MULTI_AUDIT_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    $body = '{"message":"Как выбрать ноутбук?","mode":"multi","context":{"test_id":"' + $testId + '"}}'
    $response = Invoke-WebRequest -Uri "$BackendUrl/api/v1/chat/intelligent" -Method POST -Body $body -ContentType "application/json" -UseBasicParsing -ErrorAction Stop
    
    if ($response.StatusCode -ne 200) {
        Test-Terminal 4 "FAIL" "Intelligent Chat не отвечает"
    }
    
    $data = $response.Content | ConvertFrom-Json
    $agentsUsed = @($data.data.agents_used)
    
    if (-not $data.success) {
        Test-Terminal 4 "FAIL" "Multi-Agent не вернул success"
    }
    
    if (-not $data.data.response) {
        Test-Terminal 4 "FAIL" "Multi-Agent не вернул ответ"
    }
    
    if ($agentsUsed.Count -lt 2) {
        Test-Terminal 4 "FAIL" "Multi-Agent использовал только $($agentsUsed.Count) агента (ожидалось >= 2)"
    }
    
    Start-Sleep -Seconds 2
    $logs = docker logs $BackendContainer --tail 300 2>&1 | Out-String
    
    $agentCallCount = 0
    foreach ($agent in $agentsUsed) {
        if ($logs -match "AUDIT_CALL_PATH.*test_id=$testId.*agent_id=$agent") {
            $agentCallCount++
        }
    }
    
    if ($agentCallCount -lt 2) {
        Test-Terminal 4 "FAIL" "Найдено только $agentCallCount агентов в логах (ожидалось >= 2)"
    }
    
    Write-Result 4 "PASS" "Multi-Agent реально выполнен ($($agentsUsed.Count) агентов)"
    Write-Host "     Агенты: $($agentsUsed -join ', ')" -ForegroundColor Gray
    
} catch {
    if ($_.Exception.Message -match "TERMINAL_FAIL") { throw }
    Test-Terminal 4 "FAIL" "Не удалось вызвать Multi-Agent: $($_.Exception.Message)"
}

# 5
Write-Host "`n⏱️ 5. RATE LIMITER (LEVEL 2+3)" -ForegroundColor Yellow
Write-Host ("-" * 60) -ForegroundColor Gray

try {
    $rateTestId = "RATE_AUDIT_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    $body = '{"agent_id":"assistant","message":"' + $rateTestId + '","context":{"test_id":"' + $rateTestId + '"}}'
    $limit = 3
    $blocked = $false
    $allowedCount = 0
    $hasRateLimitHeaders = $false
    $rateLimitSource = $null
    $rateLimitLimit = $null
    
    for ($i = 1; $i -le ($limit + 2); $i++) {
        try {
            $response = Invoke-WebRequest -Uri "$BackendUrl/api/v1/chat/send" -Method POST -Body $body -ContentType "application/json" -UseBasicParsing -ErrorAction Stop
            
            if ($response.Headers["X-RateLimit-Source"]) {
                $hasRateLimitHeaders = $true
                $rateLimitSource = $response.Headers["X-RateLimit-Source"]
                $rateLimitLimit = $response.Headers["X-RateLimit-Limit"]
            }
            
            if ($response.StatusCode -eq 429) {
                $blocked = $true
                Write-Host "     Запрос #$i → 429 (блокировка)" -ForegroundColor Yellow
                break
            }
            $allowedCount++
            Write-Host "     Запрос #$i → разрешён ($allowedCount)" -ForegroundColor Gray
        } catch {
            if ($_.Exception.Response.StatusCode -eq 429) {
                $blocked = $true
                Write-Host "     Запрос #$i → 429 (блокировка)" -ForegroundColor Yellow
                if ($_.Exception.Response.Headers["X-RateLimit-Source"]) {
                    $hasRateLimitHeaders = $true
                    $rateLimitSource = $_.Exception.Response.Headers["X-RateLimit-Source"]
                    $rateLimitLimit = $_.Exception.Response.Headers["X-RateLimit-Limit"]
                }
                break
            }
            Write-Host "     Запрос #$i → ошибка: $($_.Exception.Message)" -ForegroundColor Red
        }
        Start-Sleep -Milliseconds 100
    }
    
    if ($allowedCount -ne $limit) {
        Test-Terminal 5 "FAIL" "Разрешено $allowedCount запросов, ожидалось $limit"
    }
    
    if (-not $blocked) {
        Test-Terminal 5 "FAIL" "Rate Limiter НЕ сработал (лимит $limit)"
    }
    
    if (-not $hasRateLimitHeaders) {
        Test-Terminal 5 "FAIL" "X-RateLimit-* headers отсутствуют"
    }
    
    if ($rateLimitSource -ne "agi-platform") {
        Test-Terminal 5 "FAIL" "X-RateLimit-Source = $rateLimitSource, ожидалось agi-platform"
    }
    
    Write-Result 5 "PASS" "Rate Limiter подтверждён (source=$rateLimitSource, limit=$rateLimitLimit)"
    Write-Host "     Rate Limit: $rateLimitLimit" -ForegroundColor Gray
    
} catch {
    if ($_.Exception.Message -match "TERMINAL_FAIL") { throw }
    Test-Terminal 5 "FAIL" "Не удалось проверить Rate Limiter: $($_.Exception.Message)"
}

# ============================================================================
# MEMORY GATE
# ============================================================================

Write-Host "`n" + ("=" * 60) -ForegroundColor Gray
Write-Host "🔶 MEMORY GATE" -ForegroundColor Cyan
Write-Host ("=" * 60) -ForegroundColor Gray

# 6
Write-Host "`n🗄️ 6. QDRANT API + КОЛЛЕКЦИЯ + DIMENSION (LEVEL 1)" -ForegroundColor Yellow
Write-Host ("-" * 60) -ForegroundColor Gray

try {
    $response = Invoke-WebRequest -Uri "$QdrantUrl/collections" -UseBasicParsing -ErrorAction Stop
    
    if ($response.StatusCode -ne 200) {
        Test-Terminal 6 "FAIL" "Qdrant API не отвечает"
    }
    
    $data = $response.Content | ConvertFrom-Json
    $collections = $data.result.collections
    $exists = $false
    foreach ($c in $collections) {
        if ($c.name -eq "memory_vectors") {
            $exists = $true
            break
        }
    }
    
    if (-not $exists) {
        Test-Terminal 6 "FAIL" "Коллекция memory_vectors НЕ СУЩЕСТВУЕТ!"
    }
    
    $info = Invoke-WebRequest -Uri "$QdrantUrl/collections/memory_vectors" -UseBasicParsing -ErrorAction Stop
    $infoData = $info.Content | ConvertFrom-Json
    $actualSize = $infoData.result.config.params.vectors.size
    
    $embeddingSize = docker exec $BackendContainer python -c "from services.embedding_service import get_embedding_service; print(get_embedding_service().get_dimension())" 2>&1
    $embeddingSize = $embeddingSize.Trim()
    
    if ($actualSize -ne [int]$embeddingSize) {
        Test-Terminal 6 "FAIL" "Dimension mismatch: Qdrant=$actualSize, Embedding=$embeddingSize"
    }
    
    Write-Result 6 "PASS" "Qdrant API доступен, коллекция существует, dimension совпадает ($actualSize)"
    
} catch {
    if ($_.Exception.Message -match "TERMINAL_FAIL") { throw }
    Test-Terminal 6 "FAIL" "Не удалось проверить Qdrant: $($_.Exception.Message)"
}

# 7
Write-Host "`n💾 7. MEMORY → QDRANT: TEST_ID (LEVEL 4)" -ForegroundColor Yellow
Write-Host ("-" * 60) -ForegroundColor Gray

try {
    $testId = "MEMORY_AUDIT_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    
    $body = '{"agent_id":"assistant","message":"Тест памяти: ' + $testId + '","context":{"test_id":"' + $testId + '"}}'
    $response = Invoke-WebRequest -Uri "$BackendUrl/api/v1/chat/send" -Method POST -Body $body -ContentType "application/json" -UseBasicParsing -ErrorAction Stop
    
    if ($response.StatusCode -ne 200) {
        Test-Terminal 7 "FAIL" "Не удалось отправить тестовое сообщение"
    }
    
    Start-Sleep -Seconds 3
    
    $logs = docker logs $BackendContainer --tail 100 2>&1 | Out-String
    if ($logs -notmatch "AUDIT_MEMORY_STORE test_id=$testId") {
        Test-Terminal 7 "FAIL" "AUDIT_MEMORY_STORE не найден в логах (LEVEL 2)"
    }
    
    try {
        $testSearch = docker exec $BackendContainer python -c "
from services.memory_service import get_memory_service
import asyncio
async def test():
    svc = get_memory_service()
    await svc.ensure_initialized()
    result = await svc.search_by_test_id('$testId', audit_mode=True)
    print(f'found {len(result)} results')
asyncio.run(test())
" 2>&1
        if ($testSearch -notmatch "found [1-9]") {
            Test-Terminal 7 "FAIL" "search_by_test_id(audit_mode=True) не нашёл test_id"
        }
    } catch {
        Test-Terminal 7 "FAIL" "search_by_test_id(audit_mode=True) выбросил исключение: $($_.Exception.Message)"
    }
    
    $searchBody = @"
{
    "filter": {
        "must": [
            {
                "key": "test_id",
                "match": {
                    "value": "$testId"
                }
            }
        ]
    },
    "limit": 10
}
"@
    $search = Invoke-WebRequest -Uri "$QdrantUrl/collections/memory_vectors/points/scroll" -Method POST -Body $searchBody -ContentType "application/json" -UseBasicParsing -ErrorAction Stop
    
    if ($search.StatusCode -ne 200) {
        Test-Terminal 7 "FAIL" "Не удалось выполнить поиск в Qdrant"
    }
    
    $data = $search.Content | ConvertFrom-Json
    if (-not $data.result.points -or $data.result.points.Count -eq 0) {
        Test-Terminal 7 "FAIL" "Тестовый ID НЕ НАЙДЕН в Qdrant!"
    }
    
    $found = $false
    foreach ($point in $data.result.points) {
        if ($point.payload.test_id -eq $testId) {
            $found = $true
            break
        }
    }
    
    if (-not $found) {
        Test-Terminal 7 "FAIL" "test_id не найден в payload Qdrant"
    }
    
    Write-Result 7 "PASS" "Тестовый ID найден в Qdrant через test_id (LEVEL 4)"
    Write-Host "     Найдено точек: $($data.result.points.Count)" -ForegroundColor Gray
    
} catch {
    if ($_.Exception.Message -match "TERMINAL_FAIL") { throw }
    Test-Terminal 7 "FAIL" "Не удалось проверить Qdrant: $($_.Exception.Message)"
}

# 8
Write-Host "`n🔄 8. MEMORY RETRIEVAL + PERSISTENCE (LEVEL 4)" -ForegroundColor Yellow
Write-Host ("-" * 60) -ForegroundColor Gray
Write-Host "  ⚠️ Этот тест перезапускает backend" -ForegroundColor Yellow

try {
    $restartId = "RESTART_AUDIT_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    
    $body = '{"agent_id":"assistant","message":"Запомни контрольный код: ' + $restartId + '","context":{"test_id":"' + $restartId + '"}}'
    $response = Invoke-WebRequest -Uri "$BackendUrl/api/v1/chat/send" -Method POST -Body $body -ContentType "application/json" -UseBasicParsing -ErrorAction Stop
    
    if ($response.StatusCode -ne 200) {
        Test-Terminal 8 "FAIL" "Не удалось отправить тестовое сообщение"
    }
    
    Start-Sleep -Seconds 2
    
    Write-Host "  ⏳ Перезапуск backend..." -ForegroundColor Yellow
    cd $ProjectRoot\deployment\docker
    docker-compose restart backend 2>&1 | Out-Null
    Start-Sleep -Seconds 20
    
    $health = Invoke-WebRequest -Uri "$BackendUrl/health" -UseBasicParsing -ErrorAction Stop
    if ($health.StatusCode -ne 200) {
        Test-Terminal 8 "FAIL" "Backend не поднялся после restart!"
    }
    
    $searchBody = @"
{
    "filter": {
        "must": [
            {
                "key": "test_id",
                "match": {
                    "value": "$restartId"
                }
            }
        ]
    },
    "limit": 10
}
"@
    $search = Invoke-WebRequest -Uri "$QdrantUrl/collections/memory_vectors/points/scroll" -Method POST -Body $searchBody -ContentType "application/json" -UseBasicParsing -ErrorAction Stop
    
    if ($search.StatusCode -ne 200) {
        Test-Terminal 8 "FAIL" "Не удалось проверить память после restart"
    }
    
    $data = $search.Content | ConvertFrom-Json
    if (-not $data.result.points -or $data.result.points.Count -eq 0) {
        Test-Terminal 8 "FAIL" "Memory НЕ СОХРАНИЛАСЬ после restart!"
    }
    
    $testQuery = '{"agent_id":"assistant","message":"Какой контрольный код я просил запомнить?"}'
    $apiResponse = Invoke-WebRequest -Uri "$BackendUrl/api/v1/chat/send" -Method POST -Body $testQuery -ContentType "application/json" -UseBasicParsing -ErrorAction Stop
    
    if ($apiResponse.StatusCode -ne 200) {
        Test-Terminal 8 "FAIL" "Semantic search API не отвечает после restart"
    }
    
    $apiData = $apiResponse.Content | ConvertFrom-Json
    
    if ($apiData.data.response -notmatch $restartId) {
        Test-Terminal 8 "FAIL" "Semantic search не вернул контрольный код $restartId"
    }
    
    Start-Sleep -Seconds 2
    $logs = docker logs $BackendContainer --tail 200 2>&1 | Out-String
    
    if ($logs -notmatch "AUDIT_MEMORY_RETRIEVAL.*test_ids=.*$restartId") {
        Test-Terminal 8 "FAIL" "AUDIT_MEMORY_RETRIEVAL не найден (память не использована)"
    }
    
    if ($logs -notmatch "AUDIT_MEMORY_CONTEXT_INJECTED.*test_ids=.*$restartId") {
        Write-Host "     ⚠️ AUDIT_MEMORY_CONTEXT_INJECTED не найден" -ForegroundColor Yellow
    }
    
    Write-Result 8 "PASS" "Memory сохранена и реально использована после restart (LEVEL 4)"
    Write-Host "     Контрольный код найден в ответе" -ForegroundColor Gray
    
    cd $ProjectRoot
    
} catch {
    if ($_.Exception.Message -match "TERMINAL_FAIL") { throw }
    Test-Terminal 8 "FAIL" "Ошибка при проверке восстановления памяти: $($_.Exception.Message)"
}

# ============================================================================
# LEGACY GATE
# ============================================================================

Write-Host "`n" + ("=" * 60) -ForegroundColor Gray
Write-Host "🔷 LEGACY GATE" -ForegroundColor Cyan
Write-Host ("=" * 60) -ForegroundColor Gray

# 9
Write-Host "`n🚀 9. API ИСПОЛЬЗУЕТ AGENTSERVICE (LEVEL 2)" -ForegroundColor Yellow
Write-Host ("-" * 60) -ForegroundColor Gray

try {
    $testId = "DI_AUDIT_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    $body = '{"agent_id":"assistant","message":"Тест DI","context":{"test_id":"' + $testId + '"}}'
    $response = Invoke-WebRequest -Uri "$BackendUrl/api/v1/chat/send" -Method POST -Body $body -ContentType "application/json" -UseBasicParsing -ErrorAction Stop
    
    if ($response.StatusCode -ne 200) {
        Test-Terminal 9 "FAIL" "API не отвечает"
    }
    
    $data = $response.Content | ConvertFrom-Json
    
    if ($data.data.test_id -ne $testId) {
        Test-Terminal 9 "FAIL" "test_id не совпадает"
    }
    
    Start-Sleep -Seconds 2
    $logs = docker logs $BackendContainer --tail 100 2>&1 | Out-String
    
    if ($logs -notmatch "AUDIT_CALL_PATH.*test_id=$testId.*service=AgentService") {
        Test-Terminal 9 "FAIL" "AUDIT_CALL_PATH не найден в логах"
    }
    
    Write-Result 9 "PASS" "API вызывает AgentService (LEVEL 2)"
    Write-Host "     Agent: $($data.data.agent_name)" -ForegroundColor Gray
    
} catch {
    if ($_.Exception.Message -match "TERMINAL_FAIL") { throw }
    Test-Terminal 9 "FAIL" "Не удалось проверить DI: $($_.Exception.Message)"
}

# 10
Write-Host "`n🧹 10. СТАРОЕ ЯДРО НЕ В CALL PATH (LEVEL 2)" -ForegroundColor Yellow
Write-Host ("-" * 60) -ForegroundColor Gray

try {
    $testId = "LEGACY_AUDIT_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    
    $body = '{"agent_id":"assistant","message":"Тест legacy","context":{"test_id":"' + $testId + '"}}'
    $response = Invoke-WebRequest -Uri "$BackendUrl/api/v1/chat/send" -Method POST -Body $body -ContentType "application/json" -UseBasicParsing -ErrorAction Stop
    
    if ($response.StatusCode -ne 200) {
        Test-Terminal 10 "FAIL" "API не отвечает"
    }
    
    Start-Sleep -Seconds 2
    
    $logs = docker logs $BackendContainer --tail 300 2>&1 | Out-String
    
    if ($logs -notmatch "AUDIT_CALL_PATH.*test_id=$testId.*service=AgentService") {
        Test-Terminal 10 "FAIL" "AUDIT_CALL_PATH не найден для test_id=$testId"
    }
    
    if ($logs -match "LEGACY_RUNTIME_USED.*$testId") {
        Test-Terminal 10 "FAIL" "Обнаружено использование старого ядра"
    }
    
    Write-Result 10 "PASS" "Старое ядро не в call path (LEVEL 2)"
    
} catch {
    if ($_.Exception.Message -match "TERMINAL_FAIL") { throw }
    Test-Terminal 10 "FAIL" "Не удалось проверить старое ядро: $($_.Exception.Message)"
}

} catch {
    $global:AuditFatalError = $_
    throw
}

# ============================================================================
# ИТОГ (ВСЕГДА ВЫПОЛНЯЕТСЯ)
# ============================================================================

finally {

Write-Host "`n" + ("=" * 60) -ForegroundColor Gray
Write-Host "📊 ИТОГОВЫЙ ОТЧЕТ" -ForegroundColor Cyan
Write-Host ("=" * 60) -ForegroundColor Gray

Write-Host "`nРезультаты:" -ForegroundColor Yellow
Write-Host "  ✅ Пройдено: $PASSED" -ForegroundColor Green
Write-Host "  ❌ Ошибок: $FAILED" -ForegroundColor Red

if ($global:AuditFatalError) {
    Write-Host "`n  ⚠️ АУДИТ ОСТАНОВЛЕН КРИТИЧЕСКОЙ ОШИБКОЙ" -ForegroundColor Yellow
    Write-Host "     $($global:AuditFatalError.Message)" -ForegroundColor Gray
}

Write-Host "`n  CORE GATE:" -ForegroundColor Cyan
Write-Host "    1. Агенты: $($Results[1])" -ForegroundColor $(if ($Results[1]) { "Green" } else { "Red" })
Write-Host "    2. AgentService: $($Results[2])" -ForegroundColor $(if ($Results[2]) { "Green" } else { "Red" })
Write-Host "    3. DeepSeek: $($Results[3])" -ForegroundColor $(if ($Results[3]) { "Green" } else { "Red" })
Write-Host "    4. Multi-Agent: $($Results[4])" -ForegroundColor $(if ($Results[4]) { "Green" } else { "Red" })
Write-Host "    5. Rate Limiter: $($Results[5])" -ForegroundColor $(if ($Results[5]) { "Green" } else { "Red" })

Write-Host "`n  MEMORY GATE:" -ForegroundColor Cyan
Write-Host "    6. Qdrant: $($Results[6])" -ForegroundColor $(if ($Results[6]) { "Green" } else { "Red" })
Write-Host "    7. Memory test_id: $($Results[7])" -ForegroundColor $(if ($Results[7]) { "Green" } else { "Red" })
Write-Host "    8. Memory retrieval: $($Results[8])" -ForegroundColor $(if ($Results[8]) { "Green" } else { "Red" })

Write-Host "`n  LEGACY GATE:" -ForegroundColor Cyan
Write-Host "    9. DI runtime: $($Results[9])" -ForegroundColor $(if ($Results[9]) { "Green" } else { "Red" })
Write-Host "   10. No legacy: $($Results[10])" -ForegroundColor $(if ($Results[10]) { "Green" } else { "Red" })

if ($global:AuditFatalError) {
    Write-Host "`n  🔴 AUDIT TERMINATED BY FATAL ERROR" -ForegroundColor Red
    Write-Host "  ℹ️ Критическая проверка провалена" -ForegroundColor Yellow
    exit 1
} elseif ($FAILED -eq 0 -and $PASSED -eq 10) {
    Write-Host "`n  🟢 CORE/MEMORY/LEGACY AUDIT PASSED" -ForegroundColor Green
    Write-Host "  ✅ Все проверки runtime" -ForegroundColor Green
    Write-Host "  ✅ LEVEL 3: DeepSeek upstream proof" -ForegroundColor Green
    Write-Host "  ✅ LEVEL 4: Memory retrieval proof (terminal FAIL)" -ForegroundColor Green
    Write-Host "  ✅ LEVEL 3: Rate Limiter source header proof" -ForegroundColor Green
    Write-Host "  ✅ LEVEL 2: Multi-Agent call chain proof" -ForegroundColor Green
    Write-Host "  ✅ Все 10 тестов TERMINAL" -ForegroundColor Green
    Write-Host "  ✅ search_by_test_id(audit_mode=True) проверен" -ForegroundColor Green
    Write-Host "  ✅ AUDIT_MEMORY_CONTEXT_INJECTED добавлен" -ForegroundColor Green
    Write-Host "  ✅ Итоговый отчёт печатается всегда" -ForegroundColor Green
    Write-Host "  📌 Для RELEASE CANDIDATE требуется полный pre-release набор" -ForegroundColor Yellow
    exit 0
} else {
    Write-Host "`n  🔴 AUDIT BLOCKED" -ForegroundColor Red
    Write-Host "  ℹ️ Причина: $FAILED проверок провалено" -ForegroundColor Yellow
    exit 1
}

Write-Host ""

}

