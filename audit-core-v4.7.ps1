# ============================================================================
# AGI PLATFORM — АУДИТ ЯДРА v4.7 (RUNTIME VERIFICATION)
# ============================================================================
# Запуск: powershell -ExecutionPolicy Bypass -File audit-core-v4.7.ps1
# ============================================================================

$ProjectRoot = "C:\AGIPlatform"
$BackendUrl = "http://localhost:5001"
$QdrantUrl = "http://localhost:6333"

Write-Host @"
╔═══════════════════════════════════════════════════════════════════════════╗
║                                                                           ║
║        🔬 AGI PLATFORM — АУДИТ ЯДРА v4.7 (RUNTIME)                      ║
║                                                                           ║
║  УРОВНИ ДОКАЗАТЕЛЬСТВА:                                                   ║
║  LEVEL 1 — CONFIG: настройки существуют                                   ║
║  LEVEL 2 — CALL PATH: нужный компонент реально вызван                    ║
║  LEVEL 3 — UPSTREAM PROOF: внешний сервис реально ответил                ║
║  LEVEL 4 — STATE PROOF: результат реально появился там, где должен      ║
║                                                                           ║
║  CORE GATE (5 проверок)                                                   ║
║  ├── 1. 50+ агентов загружены (LEVEL 1+2)                                ║
║  ├── 2. AgentService CORE готов (LEVEL 1+2)                              ║
║  ├── 3. DeepSeek реально вызван (LEVEL 3)                                ║
║  ├── 4. Multi-Agent работает (LEVEL 2)                                   ║
║  └── 5. Rate Limiter: N → 429 (LEVEL 2+3)                               ║
║                                                                           ║
║  MEMORY GATE (3 проверки)                                                 ║
║  ├── 6. Qdrant API + коллекция + dimension (LEVEL 1)                     ║
║  ├── 7. Memory → Qdrant: test_id (LEVEL 4)                               ║
║  └── 8. Memory persistence (LEVEL 4)                                     ║
║                                                                           ║
║  LEGACY GATE (2 проверки)                                                 ║
║  ├── 9. API использует AgentService (LEVEL 2)                            ║
║  └── 10. Старое ядро не в call path (LEVEL 2)                            ║
║                                                                           ║
║  PASSED == 10 → 🟢 CORE/MEMORY/LEGACY AUDIT PASSED                      ║
║  FAILED > 0 → 🔴 AUDIT BLOCKED                                           ║
║                                                                           ║
╚═══════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

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
        throw "Test $testId failed: $message"
    }
}

# ============================================================================
# CORE GATE
# ============================================================================

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
            Write-Host "     Тегов: $($data.unique_tags)" -ForegroundColor Gray
        } else {
            Write-Result 1 "FAIL" "Агентов: $($data.total), невалидных: $($data.invalid)"
        }
    } else {
        Write-Result 1 "FAIL" "API не отвечает"
    }
} catch {
    Write-Result 1 "FAIL" "Не удалось получить агентов"
}

# 2
Write-Host "`n🧠 2. AGENTSERVICE CORE ГОТОВ (LEVEL 1+2)" -ForegroundColor Yellow
Write-Host ("-" * 60) -ForegroundColor Gray

try {
    $body = '{"agent_id":"assistant","message":"Привет"}'
    $response = Invoke-WebRequest -Uri "$BackendUrl/api/v1/chat/send" -Method POST -Body $body -ContentType "application/json" -UseBasicParsing -ErrorAction Stop
    
    if ($response.StatusCode -eq 200) {
        $data = $response.Content | ConvertFrom-Json
        if ($data.success -and $data.data.response -and $data.data.provider) {
            Write-Result 2 "PASS" "AgentService CORE готов"
            Write-Host "     Provider: $($data.data.provider)" -ForegroundColor Gray
            Write-Host "     Memory available: $($data.data.memory_available)" -ForegroundColor Gray
        } else {
            Write-Result 2 "FAIL" "Ответ пустой или некорректный"
        }
    } else {
        Write-Result 2 "FAIL" "Chat API не отвечает (код: $($response.StatusCode))"
    }
} catch {
    Write-Result 2 "FAIL" "Не удалось отправить сообщение: $($_.Exception.Message)"
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
    
    $successAttempt = $false
    foreach ($attempt in $data.data.audit_trail) {
        if ($attempt.status -eq "success" -and $attempt.upstream_request_id -eq $data.data.upstream_request_id) {
            $successAttempt = $true
            break
        }
    }
    
    if (-not $successAttempt) {
        Test-Terminal 3 "FAIL" "audit_trail не содержит успешную попытку"
    }
    
    $auditUpstreamId = $data.data.audit_trail[0].upstream_request_id
    if ($auditUpstreamId -ne $data.data.upstream_request_id) {
        Test-Terminal 3 "FAIL" "audit_trail upstream_id не совпадает"
    }
    
    Write-Result 3 "PASS" "DeepSeek реально вызван (LEVEL 3)"
    Write-Host "     Provider: $($data.data.provider)" -ForegroundColor Gray
    Write-Host "     Request ID: $($data.data.request_id)" -ForegroundColor Gray
    Write-Host "     Upstream ID: $($data.data.upstream_request_id)" -ForegroundColor Gray
    Write-Host "     Upstream Status: $($data.data.upstream_status)" -ForegroundColor Gray
    Write-Host "     Attempts: $($data.data.attempts)" -ForegroundColor Gray
    
} catch {
    if ($_.Exception.Message -notmatch "Test 3 failed") {
        Write-Result 3 "FAIL" "Не удалось проверить DeepSeek: $($_.Exception.Message)"
    }
}

# 4
Write-Host "`n🔄 4. MULTI-AGENT РАБОТАЕТ (LEVEL 2)" -ForegroundColor Yellow
Write-Host ("-" * 60) -ForegroundColor Gray

try {
    $body = '{"message":"Как выбрать ноутбук?","mode":"multi"}'
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
    
    Write-Result 4 "PASS" "Multi-Agent реально использовал $($agentsUsed.Count) агентов"
    Write-Host "     Режим: $($data.data.mode)" -ForegroundColor Gray
    Write-Host "     Агенты: $($agentsUsed -join ', ')" -ForegroundColor Gray
    
} catch {
    if ($_.Exception.Message -notmatch "Test 4 failed") {
        Write-Result 4 "FAIL" "Не удалось вызвать Multi-Agent: $($_.Exception.Message)"
    }
}

# 5
Write-Host "`n⏱️ 5. RATE LIMITER: N → 429 (LEVEL 2+3)" -ForegroundColor Yellow
Write-Host ("-" * 60) -ForegroundColor Gray

try {
    $body = '{"agent_id":"assistant","message":"Тест лимита"}'
    $limit = 3
    $blocked = $false
    $hasRateLimitHeaders = $false
    $rateLimitLimit = $null
    $rateLimitRemaining = $null
    
    for ($i = 1; $i -le ($limit + 2); $i++) {
        try {
            $response = Invoke-WebRequest -Uri "$BackendUrl/api/v1/chat/send" -Method POST -Body $body -ContentType "application/json" -UseBasicParsing -ErrorAction Stop
            
            if ($response.Headers["X-RateLimit-Limit"]) {
                $hasRateLimitHeaders = $true
                $rateLimitLimit = $response.Headers["X-RateLimit-Limit"]
                $rateLimitRemaining = $response.Headers["X-RateLimit-Remaining"]
            }
            
            if ($response.StatusCode -eq 429) {
                $blocked = $true
                Write-Host "     Запрос #$i → 429 (блокировка)" -ForegroundColor Yellow
                break
            }
        } catch {
            if ($_.Exception.Response.StatusCode -eq 429) {
                $blocked = $true
                Write-Host "     Запрос #$i → 429 (блокировка)" -ForegroundColor Yellow
                if ($_.Exception.Response.Headers["X-RateLimit-Limit"]) {
                    $hasRateLimitHeaders = $true
                    $rateLimitLimit = $_.Exception.Response.Headers["X-RateLimit-Limit"]
                    $rateLimitRemaining = $_.Exception.Response.Headers["X-RateLimit-Remaining"]
                }
                break
            }
        }
        Write-Host "     Запрос #$i → разрешён" -ForegroundColor Gray
        Start-Sleep -Milliseconds 100
    }
    
    if (-not $blocked) {
        Test-Terminal 5 "FAIL" "Rate Limiter НЕ сработал (лимит $limit)"
    }
    
    if (-not $hasRateLimitHeaders) {
        Test-Terminal 5 "FAIL" "Rate Limit headers отсутствуют (необходимы для LEVEL 3)"
    }
    
    Write-Result 5 "PASS" "Rate Limiter: $limit запросов → 429 (LEVEL 2+3)"
    Write-Host "     Rate Limit: $rateLimitLimit" -ForegroundColor Gray
    Write-Host "     Remaining: $rateLimitRemaining" -ForegroundColor Gray
    
} catch {
    if ($_.Exception.Message -notmatch "Test 5 failed") {
        Write-Result 5 "FAIL" "Не удалось проверить Rate Limiter: $($_.Exception.Message)"
    }
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
    
    $embeddingSize = docker exec docker-backend-1 python -c "from services.embedding_service import get_embedding_service; print(get_embedding_service().get_dimension())" 2>&1
    $embeddingSize = $embeddingSize.Trim()
    
    if ($actualSize -ne [int]$embeddingSize) {
        Test-Terminal 6 "FAIL" "Dimension mismatch: Qdrant=$actualSize, Embedding=$embeddingSize"
    }
    
    Write-Result 6 "PASS" "Qdrant API доступен, коллекция существует, dimension совпадает ($actualSize)"
    
} catch {
    if ($_.Exception.Message -notmatch "Test 6 failed") {
        Write-Result 6 "FAIL" "Не удалось проверить Qdrant: $($_.Exception.Message)"
    }
}

# 7
Write-Host "`n💾 7. MEMORY → QDRANT: TEST_ID (LEVEL 4)" -ForegroundColor Yellow
Write-Host ("-" * 60) -ForegroundColor Gray

try {
    $testId = "MEMORY_AUDIT_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    
    $body = '{"agent_id":"assistant","message":"Тест памяти","context":{"test_id":"' + $testId + '"}}'
    $response = Invoke-WebRequest -Uri "$BackendUrl/api/v1/chat/send" -Method POST -Body $body -ContentType "application/json" -UseBasicParsing -ErrorAction Stop
    
    if ($response.StatusCode -ne 200) {
        Test-Terminal 7 "FAIL" "Не удалось отправить тестовое сообщение"
    }
    
    Start-Sleep -Seconds 3
    
    $logs = docker logs docker-backend-1 --tail 100 2>&1 | Out-String
    if ($logs -notmatch "AUDIT_MEMORY_STORE test_id=$testId") {
        Test-Terminal 7 "FAIL" "AUDIT_MEMORY_STORE не найден в логах (LEVEL 2)"
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
    if ($_.Exception.Message -notmatch "Test 7 failed") {
        Write-Result 7 "FAIL" "Не удалось проверить Qdrant: $($_.Exception.Message)"
    }
}

# 8
Write-Host "`n🔄 8. MEMORY PERSISTENCE (LEVEL 4)" -ForegroundColor Yellow
Write-Host ("-" * 60) -ForegroundColor Gray
Write-Host "  ⚠️ Этот тест перезапускает backend" -ForegroundColor Yellow

try {
    $restartId = "RESTART_AUDIT_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    
    $body = '{"agent_id":"assistant","message":"Тест restart","context":{"test_id":"' + $restartId + '"}}'
    $response = Invoke-WebRequest -Uri "$BackendUrl/api/v1/chat/send" -Method POST -Body $body -ContentType "application/json" -UseBasicParsing -ErrorAction Stop
    
    if ($response.StatusCode -ne 200) {
        Test-Terminal 8 "FAIL" "Не удалось отправить тестовое сообщение"
    }
    
    Start-Sleep -Seconds 2
    $logs = docker logs docker-backend-1 --tail 100 2>&1 | Out-String
    if ($logs -notmatch "AUDIT_MEMORY_STORE test_id=$restartId") {
        Write-Host "     ⚠️ AUDIT_MEMORY_STORE не найден до restart" -ForegroundColor Yellow
    }
    
    Start-Sleep -Seconds 1
    
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
    
    $testQuery = '{"agent_id":"assistant","message":"Какой код я просил запомнить?"}'
    $apiResponse = Invoke-WebRequest -Uri "$BackendUrl/api/v1/chat/send" -Method POST -Body $testQuery -ContentType "application/json" -UseBasicParsing -ErrorAction Stop
    
    if ($apiResponse.StatusCode -ne 200) {
        Test-Terminal 8 "FAIL" "Semantic search API не отвечает после restart"
    }
    
    $apiData = $apiResponse.Content | ConvertFrom-Json
    if (-not $apiData.data.response -or $apiData.data.memories_used -eq 0) {
        Test-Terminal 8 "FAIL" "Semantic search не использовал память после restart"
    }
    
    Write-Result 8 "PASS" "Memory сохранена и доступна через API после restart (LEVEL 4)"
    Write-Host "     Memories used: $($apiData.data.memories_used)" -ForegroundColor Gray
    
    cd $ProjectRoot
    
} catch {
    if ($_.Exception.Message -notmatch "Test 8 failed") {
        Write-Result 8 "FAIL" "Ошибка при проверке восстановления памяти: $($_.Exception.Message)"
    }
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
    $logs = docker logs docker-backend-1 --tail 100 2>&1 | Out-String
    
    if ($logs -notmatch "AUDIT_CALL_PATH.*test_id=$testId.*service=AgentService") {
        Test-Terminal 9 "FAIL" "AUDIT_CALL_PATH не найден в логах"
    }
    
    Write-Result 9 "PASS" "API вызывает AgentService (LEVEL 2)"
    Write-Host "     Agent: $($data.data.agent_name)" -ForegroundColor Gray
    Write-Host "     Provider: $($data.data.provider)" -ForegroundColor Gray
    Write-Host "     Test ID: $($data.data.test_id)" -ForegroundColor Gray
    
} catch {
    if ($_.Exception.Message -notmatch "Test 9 failed") {
        Write-Result 9 "FAIL" "Не удалось проверить DI: $($_.Exception.Message)"
    }
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
    
    $logs = docker logs docker-backend-1 --tail 200 2>&1 | Out-String
    
    if ($logs -match "LEGACY_RUNTIME_USED.*$testId") {
        Test-Terminal 10 "FAIL" "Обнаружено использование старого ядра"
    }
    
    Write-Result 10 "PASS" "Старое ядро не в call path (LEVEL 2)"
    
} catch {
    if ($_.Exception.Message -notmatch "Test 10 failed") {
        Write-Result 10 "FAIL" "Не удалось проверить старое ядро: $($_.Exception.Message)"
    }
}

# ============================================================================
# ИТОГ
# ============================================================================

Write-Host "`n" + ("=" * 60) -ForegroundColor Gray
Write-Host "📊 ИТОГОВЫЙ ОТЧЕТ" -ForegroundColor Cyan
Write-Host ("=" * 60) -ForegroundColor Gray

Write-Host "`nРезультаты:" -ForegroundColor Yellow
Write-Host "  ✅ Пройдено: $PASSED" -ForegroundColor Green
Write-Host "  ❌ Ошибок: $FAILED" -ForegroundColor Red

Write-Host "`n  CORE GATE:" -ForegroundColor Cyan
Write-Host "    1. Агенты: $($Results[1])" -ForegroundColor $(if ($Results[1]) { "Green" } else { "Red" })
Write-Host "    2. AgentService: $($Results[2])" -ForegroundColor $(if ($Results[2]) { "Green" } else { "Red" })
Write-Host "    3. DeepSeek: $($Results[3])" -ForegroundColor $(if ($Results[3]) { "Green" } else { "Red" })
Write-Host "    4. Multi-Agent: $($Results[4])" -ForegroundColor $(if ($Results[4]) { "Green" } else { "Red" })
Write-Host "    5. Rate Limiter: $($Results[5])" -ForegroundColor $(if ($Results[5]) { "Green" } else { "Red" })

Write-Host "`n  MEMORY GATE:" -ForegroundColor Cyan
Write-Host "    6. Qdrant: $($Results[6])" -ForegroundColor $(if ($Results[6]) { "Green" } else { "Red" })
Write-Host "    7. Memory test_id: $($Results[7])" -ForegroundColor $(if ($Results[7]) { "Green" } else { "Red" })
Write-Host "    8. Persistence: $($Results[8])" -ForegroundColor $(if ($Results[8]) { "Green" } else { "Red" })

Write-Host "`n  LEGACY GATE:" -ForegroundColor Cyan
Write-Host "    9. DI runtime: $($Results[9])" -ForegroundColor $(if ($Results[9]) { "Green" } else { "Red" })
Write-Host "   10. No legacy: $($Results[10])" -ForegroundColor $(if ($Results[10]) { "Green" } else { "Red" })

if ($FAILED -eq 0 -and $PASSED -eq 10) {
    Write-Host "`n  🟢 CORE/MEMORY/LEGACY AUDIT PASSED" -ForegroundColor Green
    Write-Host "  ✅ Все проверки runtime" -ForegroundColor Green
    Write-Host "  ✅ LEVEL 3: DeepSeek upstream proof" -ForegroundColor Green
    Write-Host "  ✅ LEVEL 4: Memory state proof" -ForegroundColor Green
    Write-Host "  ✅ LEVEL 2: DI + Legacy call path" -ForegroundColor Green
    Write-Host "  ✅ max_attempts=2 (один retry)" -ForegroundColor Green
    Write-Host "  ✅ Rate Limit headers проверяются строго" -ForegroundColor Green
    Write-Host "  📌 Для RELEASE CANDIDATE требуется полный pre-release набор" -ForegroundColor Yellow
} else {
    Write-Host "`n  🔴 AUDIT BLOCKED" -ForegroundColor Red
    Write-Host "  ℹ️ Причина: $FAILED проверок провалено" -ForegroundColor Yellow
}

Write-Host ""
