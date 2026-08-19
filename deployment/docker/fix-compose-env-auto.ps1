# ============================================================
# fix-compose-env-auto.ps1
# AGI Platform v9.0 — FIX COMPOSE ENV
# ============================================================

Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "  AGI Platform v9.0 — FIX COMPOSE ENV" -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host ""

$ComposePath = "C:\AGIPlatform\deployment\docker\docker-compose.yml"
$BackupPath = "$ComposePath.backup"

Write-Host "[1/4] Creating backup..." -ForegroundColor Yellow
Copy-Item -Path $ComposePath -Destination $BackupPath -Force
Write-Host "  OK Backup created: $BackupPath" -ForegroundColor Green

Write-Host "[2/4] Reading docker-compose.yml..." -ForegroundColor Yellow
$content = Get-Content -Path $ComposePath -Raw -Encoding UTF8
Write-Host "  OK File read ($($content.Length) chars)" -ForegroundColor Green

Write-Host "[3/4] Fixing docker-compose.yml..." -ForegroundColor Yellow

# 1. Remove environment section if exists
if ($content -match "environment:") {
    $content = $content -replace "(?s)(backend:.*?)\s+environment:.*?(\n\s+)(depends_on:|ports:|volumes:|restart:|$)", "`$1`$2`$3"
    Write-Host "  OK environment removed" -ForegroundColor Green
} else {
    Write-Host "  INFO environment not found" -ForegroundColor Gray
}

# 2. Add env_file if not exists
if ($content -notmatch "env_file:") {
    $content = $content -replace "(backend:.*?)(\n\s+)(depends_on:|ports:|volumes:|restart:)", "`$1`$2    env_file:`n      - .env`n`$2`$3"
    Write-Host "  OK env_file added" -ForegroundColor Green
} else {
    Write-Host "  INFO env_file already exists" -ForegroundColor Gray
}

# 3. Add ports if not exists
if ($content -notmatch "ports:") {
    $content = $content -replace "(backend:.*?)(\n\s+)(depends_on:|volumes:|restart:|$)", "`$1`$2    ports:`n      - `"8000:8000`"`n`$2`$3"
    Write-Host "  OK ports added" -ForegroundColor Green
} else {
    Write-Host "  INFO ports already exists" -ForegroundColor Gray
}

Write-Host "  OK File fixed" -ForegroundColor Green

Write-Host "[4/4] Saving file..." -ForegroundColor Yellow
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($ComposePath, $content, $utf8NoBom)
Write-Host "  OK File saved" -ForegroundColor Green

Write-Host ""
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "  DONE!" -ForegroundColor Green
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Checking fixes:" -ForegroundColor Yellow
$check = Get-Content -Path $ComposePath -Raw -Encoding UTF8

if ($check -match "env_file:") {
    Write-Host "  OK env_file added" -ForegroundColor Green
} else {
    Write-Host "  FAIL env_file not found!" -ForegroundColor Red
}

if ($check -match "ports:") {
    Write-Host "  OK ports added" -ForegroundColor Green
} else {
    Write-Host "  FAIL ports not found!" -ForegroundColor Red
}

if ($check -match "environment:") {
    Write-Host "  WARN environment still exists (remove manually if needed)" -ForegroundColor Yellow
} else {
    Write-Host "  OK environment removed" -ForegroundColor Green
}

Write-Host ""
Write-Host "NEXT STEPS:" -ForegroundColor Yellow
Write-Host "  docker compose stop backend" -ForegroundColor Gray
Write-Host "  docker compose build --no-cache backend" -ForegroundColor Gray
Write-Host "  docker compose up -d backend" -ForegroundColor Gray
Write-Host "  docker compose logs --tail=30 backend" -ForegroundColor Gray