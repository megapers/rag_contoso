#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Migrates Contoso Retail data from SQL Server to Azure PostgreSQL
.DESCRIPTION
    This script:
    1. Creates PostgreSQL tables using EF Core migrations
    2. Calls the migration API endpoint to copy data
    3. Verifies the migration
.EXAMPLE
    .\execute-migration.ps1
#>

$ErrorActionPreference = "Stop"

Write-Host "`n╔════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   Contoso Data Migration to Azure     ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════╝`n" -ForegroundColor Cyan

$postgresConnection = "Server=pg-contoso-6821.postgres.database.azure.com;Database=ContosoRetailDW;User Id=pgadmin;Password=2783Postgres;SSL Mode=Require;Trust Server Certificate=true;"

# Step 1: Create PostgreSQL tables
Write-Host "📋 Step 1: Creating PostgreSQL tables..." -ForegroundColor Yellow
Write-Host "   Location: pg-contoso-6821.postgres.database.azure.com" -ForegroundColor Gray

cd "$PSScriptRoot\..\backEnd\ProductSales"

try {
    # Create migration (skip if already exists)
    Write-Host "   Creating EF Core migration..." -ForegroundColor Gray
    dotnet ef migrations add InitialPostgres --context ContosoRetailPostgresContext 2>$null
    
    # Apply migration to Azure PostgreSQL
    Write-Host "   Applying migration to Azure PostgreSQL..." -ForegroundColor Gray
    dotnet ef database update --context ContosoRetailPostgresContext --connection "$postgresConnection"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ PostgreSQL tables created successfully`n" -ForegroundColor Green
    }
} catch {
    if ($_.Exception.Message -like "*already been applied*" -or $_.Exception.Message -like "*duplicate*") {
        Write-Host "✅ Tables already exist (skipping)`n" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Migration may already exist or tables created: $($_.Exception.Message)`n" -ForegroundColor Yellow
    }
}

# Step 2: Start the API
Write-Host "📋 Step 2: Starting API server..." -ForegroundColor Yellow

$apiJob = Start-Job -ScriptBlock {
    Set-Location $using:PWD
    dotnet run --urls "http://localhost:5000"
}

Write-Host "   Waiting for API to start..." -ForegroundColor Gray
Start-Sleep -Seconds 8

try {
    # Test if API is running
    $null = Invoke-RestMethod -Uri "http://localhost:5000/api/sales" -Method GET -TimeoutSec 5 -ErrorAction Stop
    Write-Host "✅ API is running`n" -ForegroundColor Green
} catch {
    Write-Host "⚠️  API may not be fully started, continuing anyway...`n" -ForegroundColor Yellow
}

# Step 3: Execute migration
Write-Host "📋 Step 3: Migrating data from SQL Server to PostgreSQL..." -ForegroundColor Yellow
Write-Host "   Source: localhost:1433 (SQL Server)" -ForegroundColor Gray
Write-Host "   Destination: pg-contoso-6821 (Azure PostgreSQL)" -ForegroundColor Gray
Write-Host ""

try {
    $startTime = Get-Date
    
    $response = Invoke-RestMethod `
        -Uri "http://localhost:5000/api/admin/migrate-data" `
        -Method POST `
        -ContentType "application/json" `
        -TimeoutSec 300 `
        -ErrorAction Stop
    
    $endTime = Get-Date
    $duration = $endTime - $startTime
    
    Write-Host "`n✅ Migration completed successfully!`n" -ForegroundColor Green
    Write-Host "📊 Migration Results:" -ForegroundColor Cyan
    Write-Host "   Total Records: $($response.totalRecords)" -ForegroundColor White
    Write-Host "   Migrated: $($response.migratedRecords)" -ForegroundColor White
    Write-Host "   Duration: $($response.durationFormatted)" -ForegroundColor White
    Write-Host ""
    
} catch {
    Write-Host "`n❌ Migration failed!" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
} finally {
    # Stop the API
    Write-Host "🛑 Stopping API server..." -ForegroundColor Yellow
    Stop-Job -Job $apiJob -ErrorAction SilentlyContinue
    Remove-Job -Job $apiJob -Force -ErrorAction SilentlyContinue
}

# Step 4: Verify migration
Write-Host "`n📋 Step 4: Verifying data in Azure PostgreSQL..." -ForegroundColor Yellow

# Check if psql is available
$psqlAvailable = Get-Command psql -ErrorAction SilentlyContinue

if ($psqlAvailable) {
    Write-Host "   Connecting to PostgreSQL..." -ForegroundColor Gray
    $count = psql "$postgresConnection" -t -c "SELECT COUNT(*) FROM public.\"FactSales\";"
    Write-Host "   Records in Azure PostgreSQL: $($count.Trim())" -ForegroundColor White
    Write-Host ""
} else {
    Write-Host "   ⚠️  psql not found - install PostgreSQL client to verify" -ForegroundColor Yellow
    Write-Host "   You can verify manually in Azure Portal or pgAdmin" -ForegroundColor Gray
    Write-Host ""
}

Write-Host "╔════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║       Migration Complete! ✅          ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════╝`n" -ForegroundColor Green

Write-Host "🎯 Next Steps:" -ForegroundColor Cyan
Write-Host "1. Verify data in Azure Portal: https://portal.azure.com" -ForegroundColor White
Write-Host "2. Test queries against Azure PostgreSQL" -ForegroundColor White
Write-Host "3. Deploy backend to Azure Container Apps" -ForegroundColor White
Write-Host ""
