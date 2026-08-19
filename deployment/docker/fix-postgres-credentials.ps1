# ============================================================
# fix-postgres-credentials.ps1
# AGI Platform v9.0 — FIX POSTGRES CREDENTIALS
# ============================================================

$ErrorActionPreference = "Stop"

$DockerPath = "C:\AGIPlatform\deployment\docker"
$EnvPath = Join-Path $DockerPath ".env"
$BackendPath = "C:\AGIPlatform\apps\backend"
$DatabasePath = Join-Path $BackendPath "database.py"

$dbUser = "agi"
$dbPassword = "postgres"
$dbName = "agi"

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Invoke-DockerQuiet {
    param([Parameter(Mandatory)][string[]]$Arguments)
    $oldPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = @(& docker @Arguments 2>&1)
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $oldPreference
    }
    $text = ($output | ForEach-Object { [string]$_ }) -join "`n"
    [PSCustomObject]@{ Output = $text.Trim(); ExitCode = $exitCode }
}

function Show-DockerDiagnostics {
    param([Parameter(Mandatory)][string[]]$Arguments)
    $oldPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & docker @Arguments
    $ErrorActionPreference = $oldPreference
}

Write-Host "[1/17] Checking paths..." -ForegroundColor Yellow
if (-not (Test-Path $DockerPath)) { throw "Docker path not found: $DockerPath" }
if (-not (Test-Path $BackendPath)) { throw "Backend path not found: $BackendPath" }
Set-Location $DockerPath
Write-Host "  OK Paths verified" -ForegroundColor Green

Write-Host "[2/17] Checking Docker Compose..." -ForegroundColor Yellow
$versionResult = Invoke-DockerQuiet @("compose", "version")
if ($versionResult.ExitCode -ne 0) { throw "Docker Compose not available" }
Write-Host "  OK Docker Compose available" -ForegroundColor Green

Write-Host "[3/17] Checking services..." -ForegroundColor Yellow
$servicesResult = Invoke-DockerQuiet @("compose", "config", "--services")
if ($servicesResult.ExitCode -ne 0) { throw "Failed to get services list" }
$services = $servicesResult.Output -split "`r?`n" | ForEach-Object { $_.Trim() }
if ($services -notcontains "db") { throw "Service 'db' not found. Available: $($services -join ', ')" }
if ($services -notcontains "backend") { throw "Service 'backend' not found. Available: $($services -join ', ')" }
Write-Host "  OK Services found: $($services -join ', ')" -ForegroundColor Green

Write-Host "[4/17] Creating .env..." -ForegroundColor Yellow
$envContent = @"
JWT_SECRET=supersecretkey_change_in_production_1234567890abcdef
POSTGRES_USER=$dbUser
POSTGRES_PASSWORD=$dbPassword
POSTGRES_DB=$dbName
DATABASE_URL=postgresql://$dbUser`:$dbPassword@db:5432/$dbName
REDIS_URL=redis://redis:6379/0
QDRANT_URL=http://qdrant:6333
QDRANT_VECTOR_SIZE=768
"@
[System.IO.File]::WriteAllText($EnvPath, $envContent, $utf8NoBom)
Write-Host "  OK .env created" -ForegroundColor Green

Write-Host "[5/17] Checking Compose config..." -ForegroundColor Yellow
$configResult = Invoke-DockerQuiet @("compose", "config")
if ($configResult.ExitCode -ne 0) { throw "Compose config invalid" }
if ($configResult.Output -notmatch "DATABASE_URL") { throw "DATABASE_URL not found in Compose config" }
Write-Host "  OK DATABASE_URL present" -ForegroundColor Green

Write-Host "[6/17] Checking Compose variables..." -ForegroundColor Yellow
$envResult = Invoke-DockerQuiet @("compose", "config", "--environment")
if ($envResult.ExitCode -ne 0) { throw "Failed to get environment variables" }
$composeEnv = $envResult.Output
if ($composeEnv -notmatch "(?m)^POSTGRES_USER=$dbUser$") { throw "Compose does not use POSTGRES_USER=$dbUser" }
if ($composeEnv -notmatch "(?m)^POSTGRES_DB=$dbName$") { throw "Compose does not use POSTGRES_DB=$dbName" }
Write-Host "  OK Compose variables correct" -ForegroundColor Green

Write-Host "[7/17] Checking DATABASE_URL propagation..." -ForegroundColor Yellow
$checkCode = @'
import os
import sys
from urllib.parse import urlsplit
value = os.getenv("DATABASE_URL", "")
parsed = urlsplit(value)
ok = (parsed.scheme == "postgresql" and parsed.username == "agi" and parsed.hostname == "db" and parsed.port == 5432 and parsed.path == "/agi" and bool(parsed.password) and not parsed.query and not parsed.fragment)
sys.exit(0 if ok else 1)
'@
$checkResult = Invoke-DockerQuiet @("compose", "run", "--rm", "--no-deps", "--entrypoint", "python", "backend", "-c", $checkCode)
if ($checkResult.ExitCode -ne 0) {
    Write-Host "  FAIL DATABASE_URL not propagated!" -ForegroundColor Red
    throw "DATABASE_URL not propagated. Restart cancelled."
}
Write-Host "  OK DATABASE_URL propagated" -ForegroundColor Green

Write-Host "[8/17] Updating database.py..." -ForegroundColor Yellow
$databaseContent = @'
import os
from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker
DATABASE_URL = os.environ["DATABASE_URL"]
engine = create_engine(DATABASE_URL, pool_pre_ping=True)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
'@
[System.IO.File]::WriteAllText($DatabasePath, $databaseContent, $utf8NoBom)
Write-Host "  OK database.py updated" -ForegroundColor Green

Write-Host "[9/17] Checking port..." -ForegroundColor Yellow
$portResult = Invoke-DockerQuiet @("compose", "port", "backend", "8000")
$publishedPort = $portResult.Output.Trim()
if ($portResult.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($publishedPort) -or $publishedPort -notmatch ":\d+$") {
    throw "Port 8000 not published"
}
Write-Host "  OK API port published: $publishedPort" -ForegroundColor Green

Write-Host "[10/17] Checking volumes..." -ForegroundColor Yellow
$volumesResult = Invoke-DockerQuiet @("compose", "volumes")
if ($volumesResult.ExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($volumesResult.Output)) {
    Write-Host "  Project volumes:" -ForegroundColor Yellow
    Write-Host $volumesResult.Output -ForegroundColor Gray
} else {
    Write-Host "  No volumes" -ForegroundColor Gray
}

Write-Host "[11/17] Preparing restart..." -ForegroundColor Yellow
Write-Host "  WARNING: Volumes will be removed!" -ForegroundColor Red
Write-Host "  WARNING: PostgreSQL and other service data will be lost!" -ForegroundColor Red
Write-Host ""
$confirmation = Read-Host "Enter DELETE to continue"
if ($confirmation -ne "DELETE") {
    Write-Host "Operation cancelled" -ForegroundColor Yellow
    exit 0
}

Write-Host "[12/17] Restarting containers..." -ForegroundColor Yellow
Write-Host "  Stopping..." -ForegroundColor Gray
$downResult = Invoke-DockerQuiet @("compose", "down", "-v")
if ($downResult.ExitCode -ne 0) { throw "Failed to stop containers" }
Write-Host "  Rebuilding..." -ForegroundColor Gray
$buildResult = Invoke-DockerQuiet @("compose", "build", "--no-cache")
if ($buildResult.ExitCode -ne 0) { throw "Build failed" }
Write-Host "  Starting..." -ForegroundColor Gray
$upResult = Invoke-DockerQuiet @("compose", "up", "-d")
if ($upResult.ExitCode -ne 0) { throw "Startup failed" }

Write-Host "[13/17] Waiting for db container..." -ForegroundColor Yellow
$dbId = $null
for ($i = 1; $i -le 30; $i++) {
    $dbIdResult = Invoke-DockerQuiet @("compose", "ps", "-q", "db")
    $candidateId = $dbIdResult.Output.Trim()
    if ($dbIdResult.ExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($candidateId)) {
        $dbId = $candidateId
        break
    }
    Write-Host "  db container creating: $i/30" -ForegroundColor DarkGray
    Start-Sleep -Seconds 2
}
if ([string]::IsNullOrWhiteSpace($dbId)) {
    Show-DockerDiagnostics @("compose", "ps")
    throw "Failed to get db container ID"
}
Write-Host "  OK db container ID: $dbId" -ForegroundColor Green

Write-Host "[14/17] Waiting for PostgreSQL..." -ForegroundColor Yellow
$dbReady = $false
for ($i = 1; $i -le 30; $i++) {
    Start-Sleep -Seconds 2
    $stateResult = Invoke-DockerQuiet @("inspect", "-f", "{{.State.Status}}", $dbId)
    $healthResult = Invoke-DockerQuiet @("inspect", "-f", "{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}", $dbId)
    $state = $stateResult.Output.Trim()
    $health = $healthResult.Output.Trim()
    $ready = $false
    if ($state -eq "running" -and $health -eq "healthy") {
        $ready = $true
    } elseif ($state -eq "running" -and $health -eq "no-healthcheck") {
        $readyResult = Invoke-DockerQuiet @("exec", $dbId, "pg_isready", "-U", $dbUser, "-d", $dbName)
        if ($readyResult.ExitCode -eq 0) { $ready = $true }
    }
    if ($ready) {
        $dbReady = $true
        Write-Host "  OK PostgreSQL ready" -ForegroundColor Green
        break
    }
    Write-Host "  Attempt $i/30: state=$state health=$health" -ForegroundColor DarkGray
}
if (-not $dbReady) {
    Write-Host "  FAIL PostgreSQL not ready!" -ForegroundColor Red
    Show-DockerDiagnostics @("compose", "logs", "--tail=50", "db")
    throw "PostgreSQL not ready"
}

Write-Host "  Checking authentication..." -ForegroundColor Gray
$authResult = Invoke-DockerQuiet @("exec", "-e", "PGPASSWORD=$dbPassword", $dbId, "psql", "-h", "127.0.0.1", "-U", $dbUser, "-d", $dbName, "-tAc", "SELECT 1")
$authValue = ([string]$authResult.Output).Trim()
if ($authResult.ExitCode -ne 0 -or $authValue -ne "1") {
    throw "Authentication check failed"
}
Write-Host "  OK User $dbUser connects to $dbName" -ForegroundColor Green

Write-Host "  Checking PostgreSQL environment..." -ForegroundColor Gray
$dbEnvResult = Invoke-DockerQuiet @("inspect", "--format", "{{range .Config.Env}}{{println .}}{{end}}", $dbId)
if ($dbEnvResult.ExitCode -ne 0) { throw "Failed to read db environment" }
$dbEnvLines = $dbEnvResult.Output -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
if (-not ($dbEnvLines -contains "POSTGRES_USER=$dbUser")) { throw "POSTGRES_USER mismatch" }
if (-not ($dbEnvLines -contains "POSTGRES_DB=$dbName")) { throw "POSTGRES_DB mismatch" }
Write-Host "  OK PostgreSQL environment verified" -ForegroundColor Green

Write-Host "[15/17] Checking backend..." -ForegroundColor Yellow
$backendId = $null
for ($i = 1; $i -le 30; $i++) {
    $backendIdResult = Invoke-DockerQuiet @("compose", "ps", "-q", "backend")
    $candidateId = $backendIdResult.Output.Trim()
    if ($backendIdResult.ExitCode -eq 0 -and -not [string]::IsNullOrWhiteSpace($candidateId)) {
        $backendId = $candidateId
        break
    }
    Start-Sleep -Seconds 2
}
if ([string]::IsNullOrWhiteSpace($backendId)) {
    Show-DockerDiagnostics @("compose", "ps")
    throw "Failed to get backend container ID"
}
Write-Host "  OK backend container ID: $backendId" -ForegroundColor Green

$backendReady = $false
for ($i = 1; $i -le 30; $i++) {
    $backendStateResult = Invoke-DockerQuiet @("inspect", "-f", "{{.State.Status}}", $backendId)
    $backendState = $backendStateResult.Output.Trim()
    if ($backendState -eq "running") {
        $backendReady = $true
        break
    }
    Write-Host "  Backend state=$backendState, attempt $i/30" -ForegroundColor DarkGray
    Start-Sleep -Seconds 2
}
if (-not $backendReady) {
    Show-DockerDiagnostics @("compose", "logs", "--tail=100", "backend")
    throw "Backend did not become running"
}

$backendStateResult = Invoke-DockerQuiet @("inspect", "-f", "{{.State.Status}}", $backendId)
$backendHealthResult = Invoke-DockerQuiet @("inspect", "-f", "{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}", $backendId)
$backendState = $backendStateResult.Output.Trim()
$backendHealth = $backendHealthResult.Output.Trim()
if ($backendState -ne "running") {
    Write-Host "FAIL Backend not running: state=$backendState health=$backendHealth" -ForegroundColor Red
    Show-DockerDiagnostics @("compose", "logs", "--tail=100", "backend")
    throw "Backend not running"
}
if ($backendHealth -eq "unhealthy") {
    Write-Host "FAIL Backend unhealthy" -ForegroundColor Red
    Show-DockerDiagnostics @("compose", "logs", "--tail=100", "backend")
    throw "Backend unhealthy"
}
Write-Host "  OK Backend running: state=$backendState health=$backendHealth" -ForegroundColor Green

Write-Host "  Checking backend environment..." -ForegroundColor Gray
$backendEnvResult = Invoke-DockerQuiet @("inspect", "--format", "{{range .Config.Env}}{{println .}}{{end}}", $backendId)
if ($backendEnvResult.ExitCode -ne 0) { throw "Failed to get backend environment" }
$backendEnvLines = $backendEnvResult.Output -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
$databaseLine = $backendEnvLines | Where-Object { $_ -like "DATABASE_URL=*" } | Select-Object -First 1
if ($null -eq $databaseLine) {
    Write-Host "  FAIL DATABASE_URL missing in backend environment!" -ForegroundColor Red
    throw "DATABASE_URL missing in backend environment"
}
$databaseValue = ([string]$databaseLine -replace "^DATABASE_URL=", "").Trim()
$prefix = "postgresql://${dbUser}:"
$suffix = "@db:5432/${dbName}"
if (-not $databaseValue.StartsWith($prefix) -or -not $databaseValue.EndsWith($suffix)) {
    Write-Host "  FAIL DATABASE_URL points to unexpected parameters!" -ForegroundColor Red
    throw "DATABASE_URL points to unexpected parameters"
}
$encodedPassword = $databaseValue.Substring($prefix.Length, $databaseValue.Length - $prefix.Length - $suffix.Length)
if ([string]::IsNullOrWhiteSpace($encodedPassword)) { throw "DATABASE_URL missing password" }
Write-Host "  OK DATABASE_URL points to db/$dbName" -ForegroundColor Green

Write-Host "  Checking database.py..." -ForegroundColor Gray
$fileResult = Invoke-DockerQuiet @("exec", $backendId, "sed", "-n", "1,15p", "/app/backend/database.py")
if ($fileResult.ExitCode -ne 0) { throw "Failed to read database.py" }
if ($fileResult.Output -notmatch 'os\.environ\["DATABASE_URL"\]') {
    throw "database.py does not use DATABASE_URL"
}
Write-Host "  OK database.py uses DATABASE_URL" -ForegroundColor Green

Write-Host "  Checking DATABASE_URL in Python..." -ForegroundColor Gray
$pythonCode = "import os,sys; sys.exit(0 if os.getenv('DATABASE_URL') else 1)"
$pythonResult = Invoke-DockerQuiet @("exec", $backendId, "python", "-c", $pythonCode)
if ($pythonResult.ExitCode -ne 0) { throw "DATABASE_URL not available in Python" }
Write-Host "  OK DATABASE_URL available in Python" -ForegroundColor Green

Write-Host "[16/17] Checking SQLAlchemy..." -ForegroundColor Yellow
$dbProbeCode = @"
import os
from sqlalchemy import create_engine, text
engine = create_engine(os.environ["DATABASE_URL"], pool_pre_ping=True)
with engine.connect() as connection:
    value = connection.execute(text("SELECT 1")).scalar()
raise SystemExit(0 if value == 1 else 1)
"@
$dbProbeResult = Invoke-DockerQuiet @("exec", $backendId, "python", "-c", $dbProbeCode)
if ($dbProbeResult.ExitCode -ne 0) { throw "Backend cannot connect to PostgreSQL" }
Write-Host "  OK Backend connects to PostgreSQL" -ForegroundColor Green

Write-Host "  Waiting for API..." -ForegroundColor Gray
$apiReady = $false
for ($i = 1; $i -le 30; $i++) {
    try {
        Invoke-RestMethod -Uri "http://localhost:8000/health" -Method Get -TimeoutSec 3 | Out-Null
        $apiReady = $true
        Write-Host "  OK API ready in $i attempts" -ForegroundColor Green
        break
    } catch {
        Write-Host "  Waiting for API: $i/30" -ForegroundColor DarkGray
        Start-Sleep -Seconds 2
    }
}
if (-not $apiReady) {
    Write-Host "  FAIL Backend API not available!" -ForegroundColor Red
    Show-DockerDiagnostics @("compose", "logs", "--tail=100", "backend")
    throw "Backend API not available"
}

Write-Host ""
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "  CHECKING API" -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host ""

Show-DockerDiagnostics @("compose", "ps")
Write-Host ""

$healthOk = $false
Write-Host "[1/3] Checking /health..." -ForegroundColor Yellow
try {
    $health = Invoke-RestMethod -Uri "http://localhost:8000/health" -Method Get -TimeoutSec 10
    $healthOk = $true
    Write-Host "  OK Health: $($health | ConvertTo-Json -Compress)" -ForegroundColor Green
} catch {
    Write-Host "  FAIL Health: $($_.Exception.Message)" -ForegroundColor Red
    Show-DockerDiagnostics @("compose", "logs", "--tail=50", "backend")
}

$tokenOk = $false
$token = $null
Write-Host "[2/3] Getting token..." -ForegroundColor Yellow
try {
    $form = @{ username = "admin"; password = "admin" }
    $tokenResponse = Invoke-RestMethod -Uri "http://localhost:8000/auth/token" -Method Post -Body $form -ContentType "application/x-www-form-urlencoded" -TimeoutSec 10
    $token = $tokenResponse.access_token
    if ([string]::IsNullOrWhiteSpace($token)) { throw "Response does not contain access_token" }
    $tokenOk = $true
    Write-Host "  OK Token received" -ForegroundColor Green
} catch {
    Write-Host "  FAIL Token error: $($_.Exception.Message)" -ForegroundColor Red
}

$agentsOk = $false
if ($token) {
    Write-Host "[3/3] Checking /api/agents..." -ForegroundColor Yellow
    try {
        $agentsResponse = Invoke-RestMethod -Uri "http://localhost:8000/api/agents/" -Method Get -Headers @{ Authorization = "Bearer $token" } -TimeoutSec 10
        if ($agentsResponse -is [System.Array]) { $count = @($agentsResponse).Count }
        elseif ($null -ne $agentsResponse.items) { $count = @($agentsResponse.items).Count }
        elseif ($null -ne $agentsResponse.agents) { $count = @($agentsResponse.agents).Count }
        elseif ($null -ne $agentsResponse.total) { $count = [int]$agentsResponse.total }
        else { $count = 0 }
        $agentsOk = $true
        if ($count -gt 0) { Write-Host "  OK /api/agents works! Found: $count" -ForegroundColor Green }
        else { Write-Host "  WARNING /api/agents returned empty list" -ForegroundColor Yellow }
    } catch {
        Write-Host "  FAIL /api/agents error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "  CHECK COMPLETE" -ForegroundColor Green
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "FINAL STATUS:" -ForegroundColor Yellow
Write-Host "  Health: $(if ($healthOk) { 'OK' } else { 'FAIL' })" -ForegroundColor $(if ($healthOk) { 'Green' } else { 'Red' })
Write-Host "  Token: $(if ($tokenOk) { 'OK' } else { 'FAIL' })" -ForegroundColor $(if ($tokenOk) { 'Green' } else { 'Red' })
Write-Host "  Agents: $(if ($agentsOk) { 'OK' } else { 'FAIL' })" -ForegroundColor $(if ($agentsOk) { 'Green' } else { 'Red' })

if (-not $healthOk -or -not $tokenOk -or -not $agentsOk) {
    Write-Host ""
    Write-Host "FAIL: Some checks failed." -ForegroundColor Red
    Show-DockerDiagnostics @("compose", "logs", "--tail=50", "backend")
    exit 1
}

Write-Host ""
Write-Host "ALL CHECKS PASSED!" -ForegroundColor Green
exit 0