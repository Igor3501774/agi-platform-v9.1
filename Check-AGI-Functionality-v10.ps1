# ============================================
# Check-AGI-Functionality-v10.ps1
# Functional check of AGI Platform v10
# ============================================

$ErrorActionPreference = "Continue"

$BaseUrl = "http://localhost:8000"
$Root = "C:\AGIPlatform"
$ComposePath = Join-Path $Root "deployment\docker"
$LogDirectory = Join-Path $Root "logs"

$ApiTimeoutSec = 20
$ChatTimeoutSec = 90

$passed = 0
$failed = 0
$skipped = 0
$total = 0

$transcriptStarted = $false

$token = $null
$headers = @{}
$openapi = $null

$state = @{
    OpenAPI = $false
    JWT = $false
    Health = $false
    HealthValid = $false
    HealthDegraded = $false
    Agents = $false
    Categories = $false
    Chat = $false
    Embeddings = $false
    MemorySave = $false
    MemorySearch = $false
    Legal = $true
    InvalidTokenRejected = $false
    QdrantFunctional = $false
}

function Section {
    param([string]$Title)

    Write-Host ""
    Write-Host ("=" * 64) -ForegroundColor Cyan
    Write-Host $Title -ForegroundColor Cyan
    Write-Host ("=" * 64) -ForegroundColor Cyan
}

function Pass {
    param([string]$Message)

    Write-Host "  [PASS] $Message" -ForegroundColor Green
    $script:passed++
}

function Fail {
    param([string]$Message)

    Write-Host "  [FAIL] $Message" -ForegroundColor Red
    $script:failed++
}

function Skip {
    param([string]$Message)

    Write-Host "  [SKIP] $Message" -ForegroundColor Yellow
    $script:skipped++
}

function Get-ErrorBody {
    param($ErrorRecord)

    try {
        $response = $ErrorRecord.Exception.Response
        if ($null -eq $response) { return $null }
        $stream = $response.GetResponseStream()
        if ($null -eq $stream) { return $null }
        $reader = New-Object System.IO.StreamReader($stream)
        return $reader.ReadToEnd()
    } catch {
        return $null
    }
}

function Start-Log {
    try {
        New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
        $path = Join-Path $LogDirectory "functionality_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
        Start-Transcript -Path $path -Force | Out-Null
        $script:transcriptStarted = $true
        Write-Host "Log: $path" -ForegroundColor DarkGray
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

function Get-Operation {
    param($Spec, [string[]]$Paths, [string]$Method)

    if ($null -eq $Spec -or $null -eq $Spec.paths) { return $null }

    foreach ($path in $Paths) {
        $pathProperty = $Spec.paths.PSObject.Properties[$path]
        if ($null -eq $pathProperty) { continue }
        $methodProperty = $pathProperty.Value.PSObject.Properties[$Method.ToLowerInvariant()]
        if ($null -ne $methodProperty) { return $methodProperty.Value }
    }

    return $null
}

function Resolve-Schema {
    param($Spec, $Schema)

    $current = $Schema

    for ($i = 0; $i -lt 10; $i++) {
        if ($null -eq $current) { return $null }
        $ref = $current.'$ref'
        if ([string]::IsNullOrWhiteSpace($ref)) { return $current }
        if ($ref -notmatch '^#/components/schemas/(.+)$') { return $current }
        if ($null -eq $Spec.components -or $null -eq $Spec.components.schemas) { return $current }
        $name = $Matches[1]
        $property = $Spec.components.schemas.PSObject.Properties[$name]
        if ($null -eq $property) { return $current }
        $current = $property.Value
    }

    return $current
}

function Get-Items {
    param($Response)

    if ($null -ne $Response.results) { return @($Response.results) }
    if ($null -ne $Response.items) { return @($Response.items) }
    if ($Response -is [array]) { return @($Response) }
    return @($Response)
}

function Get-AgentItems {
    param($Response)

    if ($null -ne $Response.agents) { return @($Response.agents) }
    if ($null -ne $Response.items) { return @($Response.items) }
    if ($Response -is [array]) { return @($Response) }
    return @($Response)
}

function Get-ChatText {
    param($Response)

    foreach ($name in @("response", "message", "content", "answer", "text")) {
        $property = $Response.PSObject.Properties[$name]
        if ($null -ne $property -and -not [string]::IsNullOrWhiteSpace([string]$property.Value)) {
            return [string]$property.Value
        }
    }

    return $null
}

function Test-EmbeddingResponse {
    param($Response)

    foreach ($name in @("embeddings", "embedding", "data")) {
        $property = $Response.PSObject.Properties[$name]
        if ($null -ne $property -and $null -ne $property.Value -and @($property.Value).Count -gt 0) {
            return $true
        }
    }

    return $false
}

function Show-BackendLogs {
    if (-not (Test-Path -LiteralPath $ComposePath -PathType Container)) { return }

    Write-Host ""
    Write-Host "Backend logs:" -ForegroundColor Yellow

    Push-Location -LiteralPath $ComposePath
    try {
        docker compose logs --tail=100 backend
    } finally {
        Pop-Location
    }
}

Start-Log

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  AGI PLATFORM v10 - FUNCTIONALITY CHECK" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

# ============================================
# 1. OPENAPI
# ============================================

Section "1. API CONTRACT"

$total++

try {
    $openapi = Invoke-RestMethod -Uri "$BaseUrl/openapi.json" -Method Get -TimeoutSec $ApiTimeoutSec -ErrorAction Stop

    if ($null -eq $openapi.paths) {
        throw "OpenAPI does not contain paths"
    }

    $state.OpenAPI = $true
    Pass "OpenAPI available"
} catch {
    Fail "OpenAPI: $($_.Exception.Message)"
}

if (-not $state.OpenAPI) {
    $skipped += 10
    $total += 10
    Skip "Remaining API tests: OpenAPI unavailable"
} else {
    $expectedOperations = @(
        @{ Name = "POST /auth/token"; Paths = @("/auth/token", "/auth/token/"); Method = "POST" },
        @{ Name = "GET /health"; Paths = @("/health", "/health/"); Method = "GET" },
        @{ Name = "GET /api/agents"; Paths = @("/api/agents", "/api/agents/"); Method = "GET" },
        @{ Name = "POST /api/chat/send"; Paths = @("/api/chat/send", "/api/chat/send/"); Method = "POST" },
        @{ Name = "POST /api/v1/memory/save"; Paths = @("/api/v1/memory/save", "/api/v1/memory/save/"); Method = "POST" },
        @{ Name = "POST /api/v1/memory/search"; Paths = @("/api/v1/memory/search", "/api/v1/memory/search/"); Method = "POST" }
    )

    foreach ($operation in $expectedOperations) {
        $total++

        if ($null -ne (Get-Operation -Spec $openapi -Paths $operation.Paths -Method $operation.Method)) {
            Pass $operation.Name
        } else {
            Fail $operation.Name
        }
    }
}

# ============================================
# 2. AUTHENTICATION
# ============================================

Section "2. AUTHENTICATION"

$total++

try {
    $tokenResponse = Invoke-RestMethod -Uri "$BaseUrl/auth/token" -Method Post -ContentType "application/x-www-form-urlencoded" -Body "username=admin&password=admin" -TimeoutSec $ApiTimeoutSec -ErrorAction Stop

    $token = $tokenResponse.access_token

    if ([string]::IsNullOrWhiteSpace($token)) {
        throw "access_token is missing"
    }

    $headers = @{ Authorization = "Bearer $token" }

    $state.JWT = $true
    Pass "JWT received"
} catch {
    Fail "JWT: $($_.Exception.Message)"

    $errorBody = Get-ErrorBody $_
    if ($errorBody) { Write-Host "  API response: $errorBody" -ForegroundColor Yellow }
}

$total++

try {
    $badHeaders = @{ Authorization = "Bearer invalid-token" }

    Invoke-RestMethod -Uri "$BaseUrl/api/agents/" -Method Get -Headers $badHeaders -TimeoutSec $ApiTimeoutSec -ErrorAction Stop | Out-Null

    Fail "Invalid JWT was unexpectedly accepted"
} catch {
    $body = Get-ErrorBody $_

    if ($_.Exception.Response.StatusCode.value__ -in @(401, 403)) {
        $state.InvalidTokenRejected = $true
        Pass "Invalid JWT rejected"
    } else {
        Fail "Invalid JWT returned unexpected response"
    }
}

if (-not $state.JWT) {
    $skipped += 9
    $total += 9
    Skip "Protected functional tests: JWT unavailable"
}

# ============================================
# 3-8. FUNCTIONAL TESTS (only if JWT available)
# ============================================

if ($state.JWT) {
    # Health
    Section "3. HEALTH AND DEPENDENCIES"

    $total++

    try {
        $health = Invoke-RestMethod -Uri "$BaseUrl/health" -Method Get -TimeoutSec $ApiTimeoutSec -ErrorAction Stop

        switch ($health.status) {
            "ok" {
                $state.Health = $true
                $state.HealthValid = $true
                Pass "Health: ok"
            }
            "healthy" {
                $state.Health = $true
                $state.HealthValid = $true
                Pass "Health: healthy"
            }
            "degraded" {
                $state.HealthValid = $true
                $state.HealthDegraded = $true
                Pass "Health: degraded"
            }
            default {
                Fail "Unknown Health status: $($health.status)"
            }
        }

        if ($null -ne $health.dependencies) {
            Write-Host ""
            Write-Host "  Dependencies:" -ForegroundColor Gray
            $health.dependencies | ConvertTo-Json -Depth 5
        }
    } catch {
        Fail "Health: $($_.Exception.Message)"
    }

    # Agents
    Section "4. AGENTS"

    $total++

    try {
        $agentsResponse = Invoke-RestMethod -Uri "$BaseUrl/api/agents/" -Method Get -Headers $headers -TimeoutSec $ApiTimeoutSec -ErrorAction Stop

        $agentItems = Get-AgentItems $agentsResponse

        if ($agentItems.Count -ne 50) {
            throw "Expected 50 agents, got $($agentItems.Count)"
        }

        $state.Agents = $true
        Pass "50 agents loaded"
    } catch {
        Fail "Agents: $($_.Exception.Message)"
    }

    $total++

    try {
        $categoriesResponse = Invoke-RestMethod -Uri "$BaseUrl/api/agents/categories/" -Method Get -Headers $headers -TimeoutSec $ApiTimeoutSec -ErrorAction Stop

        $categoryItems = Get-Items $categoriesResponse

        if ($categoryItems.Count -eq 0) {
            throw "Categories list is empty"
        }

        $state.Categories = $true
        Pass "Categories loaded: $($categoryItems.Count)"
    } catch {
        Fail "Categories: $($_.Exception.Message)"
    }

    # Chat
    Section "5. CHAT"

    $total++

    try {
        $chatBody = @{
            agent_id = "agi_1"
            message = "Respond with one short sentence: OK."
        } | ConvertTo-Json -Depth 3

        $chatResponse = Invoke-RestMethod -Uri "$BaseUrl/api/chat/send" -Method Post -Headers $headers -Body $chatBody -ContentType "application/json" -TimeoutSec $ChatTimeoutSec -ErrorAction Stop

        $chatText = Get-ChatText $chatResponse

        if ([string]::IsNullOrWhiteSpace($chatText)) {
            throw "Chat returned empty response"
        }

        $state.Chat = $true
        Pass "Chat works"

        $preview = if ($chatText.Length -gt 120) { $chatText.Substring(0, 120) + "..." } else { $chatText }
        Write-Host "  Response: $preview" -ForegroundColor Gray
    } catch {
        Fail "Chat: $($_.Exception.Message)"

        $body = Get-ErrorBody $_
        if ($body) { Write-Host "  API response: $body" -ForegroundColor Yellow }
        Show-BackendLogs
    }

    # Embeddings
    Section "6. EMBEDDINGS"

    $embeddingPaths = @()

    if ($state.OpenAPI) {
        foreach ($property in $openapi.paths.PSObject.Properties) {
            $path = $property.Name
            $post = $property.Value.PSObject.Properties["post"]

            if ($null -ne $post -and $path -match "(?i)embed") {
                $embeddingPaths += $path
            }
        }
    }

    if ($embeddingPaths.Count -eq 0) {
        $skipped++
        $total++
        Skip "POST embeddings endpoint not found"
    } else {
        $total++

        $embeddingPath = $embeddingPaths[0]
        $formats = @("texts", "text")
        $embeddingPassed = $false

        foreach ($format in $formats) {
            try {
                if ($format -eq "texts") {
                    $embeddingBody = @{ texts = @("Functional test embeddings") } | ConvertTo-Json -Depth 5
                } else {
                    $embeddingBody = @{ text = "Functional test embeddings" } | ConvertTo-Json -Depth 5
                }

                $embeddingResponse = Invoke-RestMethod -Uri "$BaseUrl$embeddingPath" -Method Post -Headers $headers -Body $embeddingBody -ContentType "application/json" -TimeoutSec $ApiTimeoutSec -ErrorAction Stop

                if (-not (Test-EmbeddingResponse $embeddingResponse)) {
                    throw "Empty embedding response"
                }

                $state.Embeddings = $true
                $embeddingPassed = $true
                Pass "Embeddings work: $embeddingPath ($format)"
                break
            } catch {
                continue
            }
        }

        if (-not $embeddingPassed) {
            Fail "Embeddings did not return non-empty result"
        }
    }

    # Memory
    Section "7. MEMORY FUNCTIONALITY"

    $total++

    $marker = "AGI_FUNCTIONAL_$([Guid]::NewGuid().ToString('N'))"
    $memoryText = "Functional memory test with unique marker $marker"

    try {
        $saveBody = @{
            agent_id = "agi_1"
            text = $memoryText
            metadata = @{
                test = "functional"
                marker = $marker
            }
        } | ConvertTo-Json -Depth 5

        $saveResponse = Invoke-RestMethod -Uri "$BaseUrl/api/v1/memory/save" -Method Post -Headers $headers -Body $saveBody -ContentType "application/json" -TimeoutSec $ApiTimeoutSec -ErrorAction Stop

        if ($saveResponse.status -ne "success") {
            throw "Memory Save did not return status=success"
        }

        $state.MemorySave = $true
        Pass "Memory Save works"

        $searchBody = @{
            agent_id = "agi_1"
            query = $marker
            limit = 10
        } | ConvertTo-Json -Depth 5

        $searchResponse = Invoke-RestMethod -Uri "$BaseUrl/api/v1/memory/search" -Method Post -Headers $headers -Body $searchBody -ContentType "application/json" -TimeoutSec $ApiTimeoutSec -ErrorAction Stop

        $memoryItems = Get-Items $searchResponse

        $matchingItems = @(
            $memoryItems | Where-Object {
                $_.text -like "*$marker*"
            }
        )

        if ($matchingItems.Count -eq 0) {
            throw "Saved record not found"
        }

        $state.MemorySearch = $true
        Pass "Memory Search found saved record"
    } catch {
        Fail "Memory: $($_.Exception.Message)"

        $body = Get-ErrorBody $_
        if ($body) { Write-Host "  API response: $body" -ForegroundColor Yellow }
    }

    # Legal
    Section "8. LEGAL DOCUMENTS"

    $legalEndpoints = @(
        @{ Name = "terms"; Path = "/legal/terms" },
        @{ Name = "privacy"; Path = "/legal/privacy" },
        @{ Name = "consent"; Path = "/legal/consent" },
        @{ Name = "disclaimer"; Path = "/legal/disclaimer" }
    )

    foreach ($legal in $legalEndpoints) {
        $total++

        try {
            $legalResponse = Invoke-RestMethod -Uri "$BaseUrl$($legal.Path)" -Method Get -Headers $headers -TimeoutSec $ApiTimeoutSec -ErrorAction Stop

            $legalText = if ($legalResponse -is [string]) {
                $legalResponse
            } else {
                $legalResponse | ConvertTo-Json -Depth 10
            }

            if ($legalText.Length -lt 50) {
                throw "Document is empty or too short"
            }

            Pass "$($legal.Name) available"
        } catch {
            $state.Legal = $false
            Fail "$($legal.Name): $($_.Exception.Message)"
        }
    }

    # Qdrant
    Section "9. QDRANT FUNCTIONALITY"

    $total++

    try {
        Push-Location -LiteralPath $ComposePath

        try {
            $containerId = (docker compose ps -q backend).Trim()

            if (-not $containerId) {
                throw "Backend container ID not found"
            }

            $qdrantOutput = docker exec $containerId python -c "
import urllib.request
try:
    response = urllib.request.urlopen('http://qdrant:6333/healthz', timeout=10)
    print(response.read().decode())
except Exception as e:
    print(f'ERROR: {e}')
    raise
" 2>&1

            if ($LASTEXITCODE -eq 0 -and ($qdrantOutput -join "`n") -match "healthz|ok|passed") {
                $state.QdrantFunctional = $true
                Pass "Qdrant available from backend container"
            } else {
                Fail "Qdrant not responding from backend container"
                Write-Host ($qdrantOutput -join "`n") -ForegroundColor Yellow
            }
        } finally {
            Pop-Location
        }
    } catch {
        Fail "Qdrant functional check: $($_.Exception.Message)"
    }
}

# ============================================
# RESULTS
# ============================================

Section "FUNCTIONAL TEST RESULTS"

$executed = $total - $skipped
$percent = if ($executed -gt 0) { [math]::Round(($passed / $executed) * 100, 1) } else { 0 }

Write-Host ""
Write-Host "  [PASS] Passed: $passed" -ForegroundColor Green
Write-Host "  [FAIL] Failed: $failed" -ForegroundColor Red
Write-Host "  [SKIP] Skipped: $skipped" -ForegroundColor Yellow
Write-Host "  TOTAL: $total"
Write-Host "  EXECUTED: $executed"
Write-Host "  PERCENT: $percent%"

Write-Host ""
Write-Host "  OpenAPI: $(if ($state.OpenAPI) { '[OK]' } else { '[FAIL]' })"
Write-Host "  JWT: $(if ($state.JWT) { '[OK]' } else { '[FAIL]' })"
Write-Host "  Invalid JWT rejected: $(if ($state.InvalidTokenRejected) { '[OK]' } else { '[FAIL]' })"
Write-Host "  Health: $(if ($state.Health) { '[OK]' } elseif ($state.HealthDegraded) { '[WARN]' } else { '[FAIL]' })"
Write-Host "  Agents: $(if ($state.Agents) { '[OK]' } else { '[FAIL]' })"
Write-Host "  Categories: $(if ($state.Categories) { '[OK]' } else { '[FAIL]' })"
Write-Host "  Chat: $(if ($state.Chat) { '[OK]' } else { '[FAIL]' })"
Write-Host "  Embeddings: $(if ($state.Embeddings) { '[OK]' } else { '[FAIL]' })"
Write-Host "  Memory Save: $(if ($state.MemorySave) { '[OK]' } else { '[FAIL]' })"
Write-Host "  Memory Search: $(if ($state.MemorySearch) { '[OK]' } else { '[FAIL]' })"
Write-Host "  Legal: $(if ($state.Legal) { '[OK]' } else { '[FAIL]' })"
Write-Host "  Qdrant: $(if ($state.QdrantFunctional) { '[OK]' } else { '[FAIL]' })"

$critical = (
    -not $state.OpenAPI -or
    -not $state.JWT -or
    -not $state.HealthValid -or
    -not $state.Agents -or
    -not $state.Chat -or
    -not $state.MemorySave -or
    -not $state.MemorySearch -or
    -not $state.QdrantFunctional
)

$exitCode = 0

if ($critical) {
    Write-Host ""
    Write-Host "  [CRITICAL] FUNCTIONALITY FAILURE" -ForegroundColor Red
    $exitCode = 1
} elseif ($state.HealthDegraded) {
    Write-Host ""
    Write-Host "  [WARNING] SYSTEM DEGRADED" -ForegroundColor Yellow
    $exitCode = 2
} elseif ($failed -gt 0 -or $skipped -gt 0) {
    Write-Host ""
    Write-Host "  [WARNING] FUNCTIONAL TESTS HAVE ISSUES" -ForegroundColor Yellow
    $exitCode = 2
} else {
    Write-Host ""
    Write-Host "  [SUCCESS] ALL FUNCTIONAL TESTS PASSED" -ForegroundColor Green
    $exitCode = 0
}

Write-Host ""
Write-Host "  Exit code: $exitCode" -ForegroundColor Gray

Stop-Log

Write-Host ""
Read-Host "Press Enter to exit"

$global:LASTEXITCODE = $exitCode
return