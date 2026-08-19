Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  🚀 RELEASE GATE v9.0 — AGI Platform" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$checks = @{
    "Backend" = { try { (Invoke-WebRequest -Uri "http://localhost:5001/health" -UseBasicParsing).StatusCode -eq 200 } catch { $false } }
    "Agents" = { try { $r = Invoke-WebRequest -Uri "http://localhost:5001/api/v1/agents" -UseBasicParsing; $r.Content -match "agi_" } catch { $false } }
    "PostgreSQL" = { try { docker ps --filter "name=postgres" --format "{{.Status}}" | Select-String "healthy" } catch { $false } }
    "Redis" = { try { docker ps --filter "name=redis" --format "{{.Status}}" | Select-String "healthy" } catch { $false } }
    "Docker" = { try { docker ps | Out-Null; $true } catch { $false } }
}

Write-Host "`n--- 🔴 CRITICAL ---" -ForegroundColor Red
foreach ($check in $checks.Keys) {
    $result = & $checks[$check]
    if ($result) {
        Write-Host "$check : ✅" -ForegroundColor Green
    } else {
        Write-Host "$check : ❌" -ForegroundColor Red
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  📊 VERDICT" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$failed = ($checks.Values | ForEach-Object { & $_ } | Where-Object { $_ -eq $false }).Count
if ($failed -eq 0) {
    Write-Host "  🟢 GREEN — ALL PASSED!" -ForegroundColor Green
} else {
    Write-Host "  🔴 RED — $failed critical gates" -ForegroundColor Red
}
