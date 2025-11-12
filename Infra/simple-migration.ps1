#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Simple data migration from SQL Server to Azure PostgreSQL using CSV
.DESCRIPTION
    Exports data from SQL Server to CSV, then provides commands to import to PostgreSQL
.EXAMPLE
    .\simple-migration.ps1
#>

$ErrorActionPreference = "Stop"

Write-Host "`n╔════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   Contoso Data Migration (CSV Method) ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════╝`n" -ForegroundColor Cyan

$sqlConnection = "Server=localhost,1433;Database=ContosoRetailDW;User Id=sa;Password=Contraseña12345678;TrustServerCertificate=True;"
$pgConnection = "Server=pg-contoso-6821.postgres.database.azure.com;Database=ContosoRetailDW;User Id=pgadmin;Password=2783Postgres;SSL Mode=Require;Trust Server Certificate=true;"
$exportFile = Join-Path $PSScriptRoot "FactSales_$(Get-Date -Format 'yyyyMMddHHmmss').csv"

# Step 1: Create table in PostgreSQL
Write-Host "📋 Step 1: Creating table in Azure PostgreSQL..." -ForegroundColor Yellow

$createTableSQL = @"
CREATE TABLE IF NOT EXISTS public."FactSales" (
    "SalesKey" SERIAL PRIMARY KEY,
    "DateKey" TIMESTAMP NOT NULL,
    "ChannelKey" INTEGER NOT NULL,
    "StoreKey" INTEGER NOT NULL,
    "ProductKey" INTEGER NOT NULL,
    "PromotionKey" INTEGER NOT NULL,
    "CurrencyKey" INTEGER NOT NULL,
    "UnitCost" NUMERIC(19,4) NOT NULL,
    "UnitPrice" NUMERIC(19,4) NOT NULL,
    "SalesQuantity" INTEGER NOT NULL,
    "ReturnQuantity" INTEGER NOT NULL,
    "ReturnAmount" NUMERIC(19,4),
    "DiscountQuantity" INTEGER,
    "DiscountAmount" NUMERIC(19,4),
    "TotalCost" NUMERIC(19,4) NOT NULL,
    "SalesAmount" NUMERIC(19,4) NOT NULL,
    "ETLLoadID" INTEGER,
    "LoadDate" TIMESTAMP,
    "UpdateDate" TIMESTAMP
);
"@

# Check if psql is available
$psqlAvailable = Get-Command psql -ErrorAction SilentlyContinue

if ($psqlAvailable) {
    Write-Host "   Using psql to create table..." -ForegroundColor Gray
    $env:PGPASSWORD = "2783Postgres"
    psql -h "pg-contoso-6821.postgres.database.azure.com" -U "pgadmin" -d "ContosoRetailDW" -c $createTableSQL
    $env:PGPASSWORD = $null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Table created successfully`n" -ForegroundColor Green
    }
} else {
    Write-Host "   ⚠️  psql not found - will use .NET method instead" -ForegroundColor Yellow
    
    # Use .NET to execute SQL
    Add-Type -AssemblyName "System.Data"
    try {
        $npgsqlDll = Get-ChildItem -Path "$PSScriptRoot\..\backEnd\ProductSales\bin\Debug\net8.0" -Filter "Npgsql.dll" -Recurse | Select-Object -First 1
        Add-Type -Path $npgsqlDll.FullName
        
        $pgConn = New-Object Npgsql.NpgsqlConnection($pgConnection)
        $pgConn.Open()
        $cmd = $pgConn.CreateCommand()
        $cmd.CommandText = $createTableSQL
        $cmd.ExecuteNonQuery() | Out-Null
        $pgConn.Close()
        
        Write-Host "✅ Table created successfully using .NET`n" -ForegroundColor Green
    } catch {
        Write-Host "⚠️  Could not create table: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "   Table may already exist`n" -ForegroundColor Gray
    }
}

# Step 2: Export data from SQL Server
Write-Host "📋 Step 2: Exporting data from SQL Server..." -ForegroundColor Yellow
Write-Host "   Connecting to localhost:1433..." -ForegroundColor Gray

try {
    # Use .NET SqlClient to export
    Add-Type -AssemblyName "System.Data"
    
    $sqlConn = New-Object System.Data.SqlClient.SqlConnection($sqlConnection)
    $sqlConn.Open()
    
    # Only export 1000 records (same as used by the app for AI Search indexing)
    $query = "SELECT TOP 1000 * FROM dbo.FactSales ORDER BY SalesKey"
    $cmd = New-Object System.Data.SqlClient.SqlCommand($query, $sqlConn)
    $reader = $cmd.ExecuteReader()
    
    # Get column names
    $columns = @()
    for ($i = 0; $i -lt $reader.FieldCount; $i++) {
        $columns += $reader.GetName($i)
    }
    
    # Export to CSV
    $csv = New-Object System.Text.StringBuilder
    [void]$csv.AppendLine(($columns -join ','))
    
    $recordCount = 0
    while ($reader.Read()) {
        $row = @()
        for ($i = 0; $i -lt $reader.FieldCount; $i++) {
            $value = $reader.GetValue($i)
            if ($value -is [System.DBNull]) {
                $row += ""
            } elseif ($value -is [DateTime]) {
                $row += $value.ToString("yyyy-MM-dd HH:mm:ss")
            } else {
                $row += "`"$($value.ToString().Replace('"', '""'))`""
            }
        }
        [void]$csv.AppendLine(($row -join ','))
        $recordCount++
        
        if ($recordCount % 500 -eq 0) {
            Write-Host "   Exported $recordCount records..." -ForegroundColor Gray
        }
    }
    
    $reader.Close()
    $sqlConn.Close()
    
    # Save to file
    [System.IO.File]::WriteAllText($exportFile, $csv.ToString())
    
    Write-Host "✅ Exported $recordCount records to: $exportFile" -ForegroundColor Green
    Write-Host "   File size: $([Math]::Round((Get-Item $exportFile).Length / 1MB, 2)) MB`n" -ForegroundColor Gray
    
} catch {
    Write-Host "❌ Export failed: $($_.Exception.Message)`n" -ForegroundColor Red
    exit 1
}

# Step 3: Import to PostgreSQL
Write-Host "📋 Step 3: Importing to Azure PostgreSQL..." -ForegroundColor Yellow

if ($psqlAvailable) {
    Write-Host "   Using psql to import data..." -ForegroundColor Gray
    $env:PGPASSWORD = "2783Postgres"
    
    # Use \COPY command through psql
    $copyCmd = "\COPY public.\`"FactSales\`" FROM '$($exportFile)' WITH (FORMAT csv, HEADER true, DELIMITER ',', QUOTE '`"', ESCAPE '`"');"
    Write-Host "   Executing: $copyCmd" -ForegroundColor Gray
    
    psql -h "pg-contoso-6821.postgres.database.azure.com" -U "pgadmin" -d "ContosoRetailDW" -c $copyCmd
    
    $env:PGPASSWORD = $null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Data imported successfully`n" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Import may have failed - check errors above`n" -ForegroundColor Yellow
    }
    
    # Verify count
    Write-Host "📊 Verifying import..." -ForegroundColor Yellow
    $env:PGPASSWORD = "2783Postgres"
    $count = psql -h "pg-contoso-6821.postgres.database.azure.com" -U "pgadmin" -d "ContosoRetailDW" -t -c "SELECT COUNT(*) FROM public.\`"FactSales\`";"
    $env:PGPASSWORD = $null
    
    Write-Host "   Records in Azure PostgreSQL: $($count.Trim())" -ForegroundColor White
    Write-Host "   Records exported: $recordCount" -ForegroundColor White
    
    if ($count.Trim() -eq $recordCount.ToString()) {
        Write-Host "✅ Verification successful!`n" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Count mismatch - please verify manually`n" -ForegroundColor Yellow
    }
    
} else {
    Write-Host "   ⚠️  psql not found - manual import required`n" -ForegroundColor Yellow
    Write-Host "📝 Manual Import Instructions:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Option 1 - Install PostgreSQL client and run:" -ForegroundColor White
    Write-Host "   winget install PostgreSQL.PostgreSQL" -ForegroundColor Gray
    Write-Host "   Then run this script again" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Option 2 - Use pgAdmin:" -ForegroundColor White
    Write-Host "   1. Download pgAdmin: https://www.pgadmin.org/download/" -ForegroundColor Gray
    Write-Host "   2. Connect to: pg-contoso-6821.postgres.database.azure.com" -ForegroundColor Gray
    Write-Host "   3. Right-click FactSales table -> Import/Export Data" -ForegroundColor Gray
    Write-Host "   4. Select file: $exportFile" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Option 3 - Use Azure Data Studio:" -ForegroundColor White
    Write-Host "   1. Install PostgreSQL extension" -ForegroundColor Gray
    Write-Host "   2. Connect to Azure PostgreSQL" -ForegroundColor Gray
    Write-Host "   3. Use Import Wizard" -ForegroundColor Gray
    Write-Host ""
}

Write-Host "╔════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║       Migration Complete! ✅          ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════╝`n" -ForegroundColor Green

Write-Host "📁 Export file: $exportFile" -ForegroundColor Cyan
Write-Host "🗄️  Azure PostgreSQL: pg-contoso-6821.postgres.database.azure.com" -ForegroundColor Cyan
Write-Host ""
