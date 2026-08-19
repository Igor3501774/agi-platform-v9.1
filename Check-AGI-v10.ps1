# ============================================
# CHECK-AGI-v10.ps1
# AGI Platform v10.0 Full Check
# ============================================

$ErrorActionPreference = "Continue"

$BaseUrl = "http://localhost:8000"
$Root = "C:\AGIPlatform"
$AndroidRoot = Join-Path $Root "apps\android"
$ComposePath = Join-Path $Root "deployment\docker"
$LogDirectory = Join-Path $Root "logs"

$ApiTimeoutSec = 15
$ChatTimeoutSec = 90

$testsPassed = 0
$testsFailed = 0
$testsSkipped = 0
$totalTests = 0

$healthOk = $false
$healthValid = $false
$tokenOk = $false
$agentsOk = $false
$categoriesOk = $false
$chatOk = $false
$memorySaveOk = $false
$memorySearchOk = $false
$legalOk = $true
$openapiOk = $false
$apkOk = $false
$composeOk = $true
$transcriptStarted = $false

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host $Title -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor Cyan
}

function Pass-Test {
    param([string]$Message)
    Write-Host "  [PASS] $Message" -ForegroundColor Green
    $script:testsPassed++
}

function Fail-Test {
    param([string]$Message)
    Write-Host "  [FAIL] $Message" -ForegroundColor Red
    $script:testsFailed++
}

function Skip-Test {
    param([string]$Message)
    Write-Host "  [SKIP] $Message" -ForegroundColor Yellow
    $script:testsSkipped++
}

function Get-HttpErrorBody {
    param($ErrorRecord)
    try {
        $response = $ErrorRecord.Exception.Response
        if ($null -eq $response) { return $null }
        $stream = $response.GetResponseStream()
        if ($null -eq $stream) { return $null }
        $reader = New-Object System.IO.StreamReader($stream)
        return $reader.ReadToEnd()
    } catch { return $null }
}

function Get-Operation {
    param($OpenApi, [string[]]$Candidates, [string]$Method)
    if ($null -eq $OpenApi -or $null -eq $OpenApi.paths) { return $null }
    foreach ($candidate in $Candidates) {
        $pathProperty = $OpenApi.paths.PSObject.Properties[$candidate]
        if ($null -eq $pathProperty) { continue }
        $methodProperty = $pathProperty.Value.PSObject.Properties[$Method.ToLowerInvariant()]
        if ($null -ne $methodProperty) { return $methodProperty.Value }
    }
    return $null
}

function Write-BackendLogs {
    if (-not (Test-Path -LiteralPath $ComposePath -PathType Container)) { return }
    Write-Host ""
    Write-Host "  Backend logs:" -ForegroundColor Yellow
    Push-Location -LiteralPath $ComposePath
    try {
        docker compose logs --tail=80 backend
    } finally {
        Pop-Location
    }
}

function Start-Log {
    try {
        New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
        $logPath = Join-Path $LogDirectory "check_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
        Start-Transcript -Path $logPath -Force | Out-Null
        $script:transcriptStarted = $true
        Write-Host "Log: $logPath" -ForegroundColor DarkGray
    } catch {
        Write-Host "Cannot start transcript: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

function Stop-Log {
    if ($script:transcriptStarted) {
        try { Stop-Transcript | Out-Null } catch { }
        $script:transcriptStarted = $false
    }
}

function Get-AgentList {
    param($Response)
    if ($null -ne $Response.agents) { return @($Response.agents) }
    if ($null -ne $Response.items) { return @($Response.items) }
    if ($Response -is [array]) { return @($Response) }
    return @($Response)
}

function Get-MemoryItems {
    param($Response)
    if ($null -ne $Response.results) { return @($Response.results) }
    if ($null -ne $Response.items) { return @($Response.items) }
    if ($Response -is [array]) { return @($Response) }
    return @($Response)
}

Start-Log

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  AGI PLATFORM v10.0 - FULL CHECK" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

# ============================================
# SECTION 1: FILE STRUCTURE
# ============================================

Write-Section "SECTION 1: FILE STRUCTURE"

$requiredFiles = @(
    "apps\backend\main.py",
    "apps\backend\routers\agents.py",
    "apps\backend\routers\chat.py",
    "apps\backend\routers\memory.py",
    "apps\backend\routers\legal.py",
    "apps\backend\services\agent_definitions.py",
    "apps\backend\services\memory_service.py",
    "legal\terms_of_service.txt",
    "legal\privacy_policy.txt",
    "legal\consent_152_fz.txt",
    "legal\disclaimer.txt",
    "apps\android\app\build.gradle.kts",
    "apps\android\settings.gradle.kts",
    "apps\android\app\src\main\AndroidManifest.xml"
)

Write-Host "`n[1.1] Checking key files..." -ForegroundColor Yellow
foreach ($file in $requiredFiles) {
    $totalTests++
    $path = Join-Path $Root $file
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        $size = (Get-Item -LiteralPath $path).Length
        Pass-Test "$file ($size bytes)"
    } else {
        Fail-Test "$file - MISSING"
    }
}

$androidFiles = @(
    "app\src\main\java\com\agi\platform\AGIApplication.kt",
    "app\src\main\java\com\agi\platform\MainActivity.kt",
    "app\src\main\java\com\agi\platform\core\database\AppDatabase.kt",
    "app\src\main\java\com\agi\platform\core\database\MessageDao.kt",
    "app\src\main\java\com\agi\platform\core\database\MessageEntity.kt",
    "app\src\main\java\com\agi\platform\core\network\ApiService.kt",
    "app\src\main\java\com\agi\platform\core\speech\SpeechRecognizer.kt",
    "app\src\main\java\com\agi\platform\core\utils\ImageUtils.kt",
    "app\src\main\java\com\agi\platform\presentation\screens\AgentsScreen.kt",
    "app\src\main\java\com\agi\platform\presentation\screens\ChatScreen.kt",
    "app\src\main\java\com\agi\platform\presentation\screens\SubscriptionScreen.kt",
    "app\src\main\java\com\agi\platform\presentation\viewmodel\AgentsViewModel.kt",
    "app\src\main\java\com\agi\platform\presentation\viewmodel\ChatViewModel.kt"
)

Write-Host "`n[1.2] Checking Android files..." -ForegroundColor Yellow
foreach ($file in $androidFiles) {
    $totalTests++
    $path = Join-Path $AndroidRoot $file
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        Pass-Test $file
    } else {
        Fail-Test "$file - MISSING"
    }
}

Write-Host "`n[1.3] Checking APK..." -ForegroundColor Yellow
$apkPath = Join-Path $AndroidRoot "app\build\outputs\apk\debug\app-debug.apk"
$totalTests++
if (Test-Path -LiteralPath $apkPath -PathType Leaf) {
    $apkSize = (Get-Item -LiteralPath $apkPath).Length
    if ($apkSize -gt 100KB) {
        $apkOk = $true
        Pass-Test "APK found ($([math]::Round($apkSize / 1MB, 2)) MB)"
    } else {
        Fail-Test "APK too small: $apkSize bytes"
    }
} else {
    Fail-Test "APK not found: $apkPath"
}

# ============================================
# SECTION 2: DOCKER COMPOSE
# ============================================

Write-Section "SECTION 2: DOCKER COMPOSE"

$services = @("backend", "postgres", "redis", "qdrant")

if (-not (Test-Path -LiteralPath $ComposePath -PathType Container)) {
    $totalTests++
    $composeOk = $false
    Fail-Test "Compose directory missing: $ComposePath"
} else {
    Push-Location -LiteralPath $ComposePath
    try {
        foreach ($service in $services) {
            $totalTests++
            $status = @(docker compose ps --status running $service --format "{{.State}}" 2>$null) -join "`n"
            if ($status.Trim() -eq "running") {
                Pass-Test "$service - running"
            } else {
                $state = @(docker compose ps --all $service --format "{{.State}}" 2>$null) -join "`n"
                $composeOk = $false
                if ($state.Trim()) {
                    Fail-Test "$service - $state"
                } else {
                    Fail-Test "$service - not found"
                }
            }
        }
    } finally {
        Pop-Location
    }
}

# ============================================
# SECTION 3: OPENAPI
# ============================================

Write-Section "SECTION 3: OPENAPI"

$openapi = $null
$paths = @()
$totalTests++

try {
    $openapi = Invoke-RestMethod -Uri "$BaseUrl/openapi.json" -Method Get -TimeoutSec $ApiTimeoutSec -ErrorAction Stop
    $paths = @($openapi.paths.PSObject.Properties.Name)
    $openapiOk = $true
    Pass-Test "OpenAPI received ($($paths.Count) routes)"
} catch {
    Fail-Test "OpenAPI unavailable: $($_.Exception.Message)"
}

if ($openapiOk) {
    $expectedOperations = @(
        @{ Name = "POST /auth/token"; Paths = @("/auth/token", "/auth/token/"); Method = "POST" },
        @{ Name = "GET /health"; Paths = @("/health", "/health/"); Method = "GET" },
        @{ Name = "GET /api/agents"; Paths = @("/api/agents", "/api/agents/"); Method = "GET" },
        @{ Name = "POST /api/chat/send"; Paths = @("/api/chat/send", "/api/chat/send/"); Method = "POST" },
        @{ Name = "POST /api/v1/memory/save"; Paths = @("/api/v1/memory/save", "/api/v1/memory/save/"); Method = "POST" },
        @{ Name = "POST /api/v1/memory/search"; Paths = @("/api/v1/memory/search", "/api/v1/memory/search/"); Method = "POST" }
    )

    foreach ($operation in $expectedOperations) {
        $totalTests++
        $found = Get-Operation -OpenApi $openapi -Candidates $operation.Paths -Method $operation.Method
        if ($null -ne $found) {
            Pass-Test $operation.Name
        } else {
            Fail-Test $operation.Name
        }
    }

    $totalTests++
    try {
        $docs = Invoke-WebRequest -Uri "$BaseUrl/docs" -Method Get -TimeoutSec $ApiTimeoutSec -ErrorAction Stop
        if ($docs.StatusCode -eq 200) {
            Pass-Test "Swagger UI available"
        } else {
            Fail-Test "Swagger UI: HTTP $($docs.StatusCode)"
        }
    } catch {
        Fail-Test "Swagger UI unavailable: $($_.Exception.Message)"
    }
} else {
    $totalTests += 7
    $testsSkipped += 7
    Skip-Test "OpenAPI routes"
    Skip-Test "Swagger UI"
}

# ============================================
# SECTION 4: API
# ============================================

Write-Section "SECTION 4: API"

# Health
$totalTests++
$health = $null
try {
    $health = Invoke-RestMethod -Uri "$BaseUrl/health" -Method Get -TimeoutSec $ApiTimeoutSec -ErrorAction Stop
    switch ($health.status) {
        "ok" { $healthOk = $true; $healthValid = $true; Pass-Test "Health: ok" }
        "healthy" { $healthOk = $true; $healthValid = $true; Pass-Test "Health: healthy" }
        "degraded" { $healthValid = $true; Pass-Test "Health: degraded" }
        default { Fail-Test "Unknown Health status: $($health.status)" }
    }
} catch {
    Fail-Test "Health FAILED: $($_.Exception.Message)"
}

# JWT
$totalTests++
$token = $null
$headers = @{}
try {
    $tokenResponse = Invoke-RestMethod -Uri "$BaseUrl/auth/token" -Method Post -ContentType "application/x-www-form-urlencoded" -Body "username=admin&password=admin" -TimeoutSec $ApiTimeoutSec -ErrorAction Stop
    $token = $tokenResponse.access_token
    if ([string]::IsNullOrWhiteSpace($token)) { throw "access_token missing" }
    $headers = @{ Authorization = "Bearer $token" }
    $tokenOk = $true
    Pass-Test "JWT received"
} catch {
    Fail-Test "JWT FAILED: $($_.Exception.Message)"
    $errorBody = Get-HttpErrorBody $_
    if ($errorBody) { Write-Host "     API response: $errorBody" -ForegroundColor Yellow }
}

if (-not $tokenOk) {
    $testsSkipped += 5
    $totalTests += 5
    Skip-Test "Agents"
    Skip-Test "Categories"
    Skip-Test "Chat"
    Skip-Test "Memory"
    Skip-Test "Legal"
}

if ($tokenOk) {
    # Agents
    $totalTests++
    try {
        $agents = Invoke-RestMethod -Uri "$BaseUrl/api/agents/" -Method Get -Headers $headers -TimeoutSec $ApiTimeoutSec -ErrorAction Stop
        $agentList = Get-AgentList $agents
        if ($agentList.Count -eq 50) {
            $agentsOk = $true
            Pass-Test "Agents: 50"
        } else {
            Fail-Test "Agents: $($agentList.Count), expected 50"
        }
    } catch {
        Fail-Test "Agents FAILED: $($_.Exception.Message)"
    }

    # Categories
    $totalTests++
    try {
        $categories = Invoke-RestMethod -Uri "$BaseUrl/api/agents/categories/" -Method Get -Headers $headers -TimeoutSec $ApiTimeoutSec -ErrorAction Stop
        $categoryList = if ($null -ne $categories.categories) { @($categories.categories) } elseif ($categories -is [array]) { @($categories) } else { @($categories) }
        if ($categoryList.Count -gt 0) {
            $categoriesOk = $true
            Pass-Test "Categories: $($categoryList.Count)"
            Write-Host "     $($categoryList -join ', ')" -ForegroundColor Gray
        } else {
            Fail-Test "Categories empty"
        }
    } catch {
        Fail-Test "Categories FAILED: $($_.Exception.Message)"
    }

    # Chat
    $totalTests++
    try {
        $chatBody = @{ agent_id = "agi_1"; message = "Respond with one short sentence: OK." } | ConvertTo-Json -Depth 3
        $chatResult = Invoke-RestMethod -Uri "$BaseUrl/api/chat/send" -Method Post -Headers $headers -Body $chatBody -ContentType "application/json" -TimeoutSec $ChatTimeoutSec -ErrorAction Stop
        
        $chatText = $null
        foreach ($name in @("response", "message", "content", "answer")) {
            $property = $chatResult.PSObject.Properties[$name]
            if ($null -ne $property -and -not [string]::IsNullOrWhiteSpace([string]$property.Value)) {
                $chatText = [string]$property.Value
                break
            }
        }
        
        if ([string]::IsNullOrWhiteSpace($chatText)) { throw "Empty Chat response" }
        $chatOk = $true
        Pass-Test "Chat works"
        $preview = if ($chatText.Length -gt 120) { $chatText.Substring(0, 120) + "..." } else { $chatText }
        Write-Host "     Response: $preview" -ForegroundColor Gray
    } catch {
        Fail-Test "Chat FAILED: $($_.Exception.Message)"
        $errorBody = Get-HttpErrorBody $_
        if ($errorBody) { Write-Host "     API response: $errorBody" -ForegroundColor Yellow }
        Write-BackendLogs
    }

    # Memory Save + Search
    $totalTests++
    $memoryMarker = "AGI_V10_$([Guid]::NewGuid().ToString('N'))"
    $testText = "Smoke test record $memoryMarker"

    try {
        $saveBody = @{ agent_id = "agi_1"; text = $testText; metadata = @{ test = "smoke"; marker = $memoryMarker } } | ConvertTo-Json -Depth 5
        $saveResult = Invoke-RestMethod -Uri "$BaseUrl/api/v1/memory/save" -Method Post -Headers $headers -Body $saveBody -ContentType "application/json" -TimeoutSec $ApiTimeoutSec -ErrorAction Stop
        
        if ($saveResult.status -ne "success") { throw "Memory Save unexpected response" }
        Write-Host "  [PASS] Memory Save works" -ForegroundColor Green

        $searchBody = @{ agent_id = "agi_1"; query = $memoryMarker; limit = 10 } | ConvertTo-Json -Depth 5
        $searchResult = Invoke-RestMethod -Uri "$BaseUrl/api/v1/memory/search" -Method Post -Headers $headers -Body $searchBody -ContentType "application/json" -TimeoutSec $ApiTimeoutSec -ErrorAction Stop
        
        $searchItems = Get-MemoryItems $searchResult
        $found = @($searchItems | Where-Object { $_.text -like "*$memoryMarker*" })
        
        if ($found.Count -eq 0) { throw "Memory Search did not find record; results: $($searchItems.Count)" }
        
        $memorySaveOk = $true
        $memorySearchOk = $true
        Pass-Test "Memory Save + Search: marker found"
    } catch {
        Fail-Test "Memory FAILED: $($_.Exception.Message)"
        $errorBody = Get-HttpErrorBody $_
        if ($errorBody) { Write-Host "     API response: $errorBody" -ForegroundColor Yellow }
    }

    # Legal Documents
    Write-Host "`n[4.6] Legal documents..." -ForegroundColor Yellow
    $legalDocs = @(
        @{ Name = "terms"; Path = "/legal/terms" },
        @{ Name = "privacy"; Path = "/legal/privacy" },
        @{ Name = "consent"; Path = "/legal/consent" },
        @{ Name = "disclaimer"; Path = "/legal/disclaimer" }
    )

    foreach ($doc in $legalDocs) {
        $totalTests++
        try {
            $response = Invoke-RestMethod -Uri "$BaseUrl$($doc.Path)" -Method Get -Headers $headers -TimeoutSec $ApiTimeoutSec -ErrorAction Stop
            $content = if ($response -is [string]) { $response } else { $response | ConvertTo-Json -Depth 5 }
            if ($content.Length -gt 50) {
                Pass-Test "$($doc.Name) available"
            } else {
                $legalOk = $false
                Fail-Test "$($doc.Name) empty"
            }
        } catch {
            $legalOk = $false
            Fail-Test "$($doc.Name): $($_.Exception.Message)"
        }
    }
}

# ============================================
# RESULTS
# ============================================

Write-Section "RESULTS"

$totalExecuted = $totalTests - $testsSkipped
$passPercent = if ($totalExecuted -gt 0) { [math]::Round(($testsPassed / $totalExecuted) * 100, 1) } else { 0 }

Write-Host ""
Write-Host "  [PASS] $testsPassed" -ForegroundColor Green
Write-Host "  [FAIL] $testsFailed" -ForegroundColor Red
Write-Host "  [SKIP] $testsSkipped" -ForegroundColor Yellow
Write-Host "  TOTAL: $totalTests"
Write-Host "  EXECUTED: $totalExecuted"
Write-Host "  PERCENT: $passPercent%"

Write-Host ""
Write-Host "  APK: $(if ($apkOk) { 'OK' } else { 'FAIL' })"
Write-Host "  Compose: $(if ($composeOk) { 'OK' } else { 'FAIL' })"
Write-Host "  OpenAPI: $(if ($openapiOk) { 'OK' } else { 'FAIL' })"
Write-Host "  Health: $(if ($healthOk) { 'OK' } else { 'WARN' })"
Write-Host "  JWT: $(if ($tokenOk) { 'OK' } else { 'FAIL' })"
Write-Host "  Agents: $(if ($agentsOk) { 'OK' } else { 'FAIL' })"
Write-Host "  Categories: $(if ($categoriesOk) { 'OK' } else { 'FAIL' })"
Write-Host "  Chat: $(if ($chatOk) { 'OK' } else { 'FAIL' })"
Write-Host "  Memory Save: $(if ($memorySaveOk) { 'OK' } else { 'FAIL' })"
Write-Host "  Memory Search: $(if ($memorySearchOk) { 'OK' } else { 'FAIL' })"
Write-Host "  Legal: $(if ($legalOk) { 'OK' } else { 'FAIL' })"

$criticalFailure = (
    -not $composeOk -or
    -not $healthValid -or
    -not $tokenOk -or
    -not $chatOk -or
    -not $memorySaveOk -or
    -not $memorySearchOk
)

$finalExitCode = 0

if ($criticalFailure) {
    Write-Host ""
    Write-Host "  [CRITICAL] CHECK FAILED" -ForegroundColor Red
    $finalExitCode = 1
} elseif ($testsFailed -gt 0 -or $testsSkipped -gt 0) {
    Write-Host ""
    Write-Host "  [WARNING] SOME TESTS FAILED OR SKIPPED" -ForegroundColor Yellow
    $finalExitCode = 2
} else {
    Write-Host ""
    Write-Host "  [SUCCESS] AGI PLATFORM v10.0 FULLY READY!" -ForegroundColor Green
    Write-Host "  APK: $apkPath" -ForegroundColor Gray
    $finalExitCode = 0
}

Write-Host ""
Write-Host "  Exit code: $finalExitCode" -ForegroundColor Gray

Stop-Log

Write-Host ""
Read-Host "Press Enter to exit"

$global:LASTEXITCODE = $finalExitCode
return