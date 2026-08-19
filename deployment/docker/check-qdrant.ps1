$maxAttempts = 30
$attempt = 0
$healthy = $false

Write-Host "🔍 Проверка Qdrant health endpoint..."

while ($attempt -lt $maxAttempts -and -not $healthy) {
    $attempt++
    Write-Host "Попытка $attempt/$maxAttempts..."
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:6333/health" -Method Get -TimeoutSec 10 -UseBasicParsing
        if ($response.StatusCode -eq 200) {
            $healthy = $true
            Write-Host "✅ Qdrant HEALTHY (status $($response.StatusCode))"
        } else {
            Write-Host "⚠️ Qdrant вернул статус $($response.StatusCode)"
        }
    } catch {
        Write-Host "❌ Qdrant не отвечает: $($_.Exception.Message)"
    }
    Start-Sleep -Seconds 10
}

if (-not $healthy) {
    Write-Host "❌ Qdrant НЕ СТАЛ HEALTHY за $maxAttempts попыток"
    exit 1
} else {
    exit 0
}