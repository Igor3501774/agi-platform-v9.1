# ----------------------------------------
# Memory Save
# ----------------------------------------

$totalTests++

$memoryMarker = "AGI_SMOKE_$([Guid]::NewGuid().ToString('N'))"
$memoryTestText = "Smoke test record $memoryMarker"

try {
    $saveBodyMap = @{
        agent_id = "agi_1"
        text = $memoryTestText
        metadata = @{
            test = "smoke"
        }
    }

    $saveBody = $saveBodyMap | ConvertTo-Json -Depth 5

    $saveResult = Invoke-RestMethod `
        -Uri "$BaseUrl/api/v1/memory/save" `
        -Method Post `
        -Headers $headers `
        -Body $saveBody `
        -ContentType "application/json" `
        -TimeoutSec $ApiTimeoutSec `
        -ErrorAction Stop

    if ($saveResult.status -ne "success") {
        throw "Неожиданный ответ save: $($saveResult | ConvertTo-Json -Compress)"
    }

    $memorySaveOk = $true
    Add-Pass "Memory Save"
} catch {
    Add-Fail "Memory Save: $($_.Exception.Message)"

    $errorBody = Get-HttpErrorBody $_
    if ($errorBody) {
        Write-Host "     Ответ API: $errorBody" -ForegroundColor Yellow
    }
}
