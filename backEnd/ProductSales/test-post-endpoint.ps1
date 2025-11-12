#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Tests the new POST endpoint for Sales
.DESCRIPTION
    Creates a test sale record and verifies it was created successfully
#>

Write-Host "`n🧪 Testing POST /api/sales Endpoint" -ForegroundColor Cyan
Write-Host "===================================`n" -ForegroundColor Cyan

$apiUrl = "http://localhost:5000"

# Test data
$testSale = @{
    dateKey = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
    channelKey = 1
    storeKey = 306
    productKey = 2515
    promotionKey = 1
    currencyKey = 1
    unitCost = 8.99
    unitPrice = 14.99
    salesQuantity = 3
    returnQuantity = 0
    returnAmount = 0
    discountQuantity = 0
    discountAmount = 0
    totalCost = 26.97
    salesAmount = 44.97
}

Write-Host "📋 Test Sale Data:" -ForegroundColor Yellow
$testSale | ConvertTo-Json | Write-Host -ForegroundColor Gray
Write-Host ""

Write-Host "🚀 Sending POST request..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod `
        -Uri "$apiUrl/api/sales" `
        -Method POST `
        -Body ($testSale | ConvertTo-Json) `
        -ContentType "application/json" `
        -ErrorAction Stop
    
    Write-Host "✅ Sale created successfully!`n" -ForegroundColor Green
    Write-Host "📊 Response:" -ForegroundColor Cyan
    $response | ConvertTo-Json | Write-Host -ForegroundColor Gray
    Write-Host ""
    
    $salesKey = $response.salesKey
    Write-Host "🔑 Sales Key: $salesKey" -ForegroundColor Green
    
    # Verify by retrieving the created sale
    Write-Host "`n📥 Verifying: GET /api/sales/$salesKey" -ForegroundColor Yellow
    $verifyResponse = Invoke-RestMethod `
        -Uri "$apiUrl/api/sales/$salesKey" `
        -Method GET `
        -ErrorAction Stop
    
    Write-Host "✅ Sale retrieved successfully!" -ForegroundColor Green
    Write-Host "   Amount: $($verifyResponse.salesAmount)" -ForegroundColor White
    Write-Host "   Quantity: $($verifyResponse.salesQuantity)" -ForegroundColor White
    Write-Host "   Date: $($verifyResponse.dateKey)`n" -ForegroundColor White
    
    Write-Host "🎉 All tests passed!`n" -ForegroundColor Green
    
} catch {
    Write-Host "❌ Test failed!" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "`n⚠️  Make sure the API is running: dotnet run`n" -ForegroundColor Yellow
    exit 1
}
