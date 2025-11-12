#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Import CSV file to Azure PostgreSQL using .NET
.EXAMPLE
    .\import-csv-to-postgres.ps1 -CsvFile "FactSales_20251111181227.csv"
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$CsvFile
)

$ErrorActionPreference = "Stop"

# Find the most recent CSV file if not specified
if (-not $CsvFile) {
    $csvFiles = Get-ChildItem "$PSScriptRoot\FactSales_*.csv" | Sort-Object LastWriteTime -Descending
    if ($csvFiles) {
        $CsvFile = $csvFiles[0].FullName
    } else {
        Write-Host "❌ No CSV files found!" -ForegroundColor Red
        exit 1
    }
} elseif (-not [System.IO.Path]::IsPathRooted($CsvFile)) {
    $CsvFile = Join-Path $PSScriptRoot $CsvFile
}

Write-Host "`n╔════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     Import CSV to Azure PostgreSQL    ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════╝`n" -ForegroundColor Cyan

Write-Host "📁 CSV File: $CsvFile" -ForegroundColor White
Write-Host "🗄️  Target: pg-contoso-6821.postgres.database.azure.com`n" -ForegroundColor White

if (-not (Test-Path $CsvFile)) {
    Write-Host "❌ File not found: $CsvFile" -ForegroundColor Red
    exit 1
}

$pgConnection = "Server=pg-contoso-6821.postgres.database.azure.com;Database=ContosoRetailDW;User Id=pgadmin;Password=2783Postgres;SSL Mode=Require;Trust Server Certificate=true;"

try {
    # Load Npgsql
    $npgsqlDll = Get-ChildItem -Path "$PSScriptRoot\..\backEnd\ProductSales\bin\Debug\net8.0" -Filter "Npgsql.dll" -Recurse | Select-Object -First 1
    Add-Type -Path $npgsqlDll.FullName
    
    Write-Host "📊 Reading CSV file..." -ForegroundColor Yellow
    
    # Read CSV
    $csv = Import-Csv $CsvFile
    $totalRecords = $csv.Count
    
    Write-Host "   Found $totalRecords records`n" -ForegroundColor Gray
    
    # Connect to PostgreSQL
    Write-Host "🔌 Connecting to Azure PostgreSQL..." -ForegroundColor Yellow
    $conn = New-Object Npgsql.NpgsqlConnection($pgConnection)
    $conn.Open()
    Write-Host "   ✅ Connected`n" -ForegroundColor Green
    
    # Prepare insert statement
    $insertSql = @"
INSERT INTO public."FactSales" (
    "DateKey", "ChannelKey", "StoreKey", "ProductKey", "PromotionKey", "CurrencyKey",
    "UnitCost", "UnitPrice", "SalesQuantity", "ReturnQuantity", "ReturnAmount",
    "DiscountQuantity", "DiscountAmount", "TotalCost", "SalesAmount",
    "ETLLoadID", "LoadDate", "UpdateDate"
) VALUES (
    @DateKey, @ChannelKey, @StoreKey, @ProductKey, @PromotionKey, @CurrencyKey,
    @UnitCost, @UnitPrice, @SalesQuantity, @ReturnQuantity, @ReturnAmount,
    @DiscountQuantity, @DiscountAmount, @TotalCost, @SalesAmount,
    @ETLLoadID, @LoadDate, @UpdateDate
)
"@
    
    Write-Host "📥 Importing data..." -ForegroundColor Yellow
    
    $imported = 0
    $batchSize = 100
    $transaction = $conn.BeginTransaction()
    
    try {
        foreach ($row in $csv) {
            $cmd = $conn.CreateCommand()
            $cmd.Transaction = $transaction
            $cmd.CommandText = $insertSql
            
            # Add parameters
            [void]$cmd.Parameters.AddWithValue("@DateKey", [DateTime]::Parse($row.DateKey))
            [void]$cmd.Parameters.AddWithValue("@ChannelKey", [int]$row.ChannelKey)
            [void]$cmd.Parameters.AddWithValue("@StoreKey", [int]$row.StoreKey)
            [void]$cmd.Parameters.AddWithValue("@ProductKey", [int]$row.ProductKey)
            [void]$cmd.Parameters.AddWithValue("@PromotionKey", [int]$row.PromotionKey)
            [void]$cmd.Parameters.AddWithValue("@CurrencyKey", [int]$row.CurrencyKey)
            [void]$cmd.Parameters.AddWithValue("@UnitCost", [decimal]$row.UnitCost)
            [void]$cmd.Parameters.AddWithValue("@UnitPrice", [decimal]$row.UnitPrice)
            [void]$cmd.Parameters.AddWithValue("@SalesQuantity", [int]$row.SalesQuantity)
            [void]$cmd.Parameters.AddWithValue("@ReturnQuantity", [int]$row.ReturnQuantity)
            
            if ([string]::IsNullOrEmpty($row.ReturnAmount)) {
                $param = New-Object Npgsql.NpgsqlParameter("@ReturnAmount", [System.Data.DbType]::Decimal)
                $param.Value = [DBNull]::Value
                [void]$cmd.Parameters.Add($param)
            } else {
                [void]$cmd.Parameters.AddWithValue("@ReturnAmount", [decimal]$row.ReturnAmount)
            }
            
            if ([string]::IsNullOrEmpty($row.DiscountQuantity)) {
                $param = New-Object Npgsql.NpgsqlParameter("@DiscountQuantity", [System.Data.DbType]::Int32)
                $param.Value = [DBNull]::Value
                [void]$cmd.Parameters.Add($param)
            } else {
                [void]$cmd.Parameters.AddWithValue("@DiscountQuantity", [int]$row.DiscountQuantity)
            }
            
            if ([string]::IsNullOrEmpty($row.DiscountAmount)) {
                $param = New-Object Npgsql.NpgsqlParameter("@DiscountAmount", [System.Data.DbType]::Decimal)
                $param.Value = [DBNull]::Value
                [void]$cmd.Parameters.Add($param)
            } else {
                [void]$cmd.Parameters.AddWithValue("@DiscountAmount", [decimal]$row.DiscountAmount)
            }
            
            [void]$cmd.Parameters.AddWithValue("@TotalCost", [decimal]$row.TotalCost)
            [void]$cmd.Parameters.AddWithValue("@SalesAmount", [decimal]$row.SalesAmount)
            
            if ([string]::IsNullOrEmpty($row.ETLLoadID)) {
                $param = New-Object Npgsql.NpgsqlParameter("@ETLLoadID", [System.Data.DbType]::Int32)
                $param.Value = [DBNull]::Value
                [void]$cmd.Parameters.Add($param)
            } else {
                [void]$cmd.Parameters.AddWithValue("@ETLLoadID", [int]$row.ETLLoadID)
            }
            
            if ([string]::IsNullOrEmpty($row.LoadDate)) {
                $param = New-Object Npgsql.NpgsqlParameter("@LoadDate", [System.Data.DbType]::DateTime)
                $param.Value = [DBNull]::Value
                [void]$cmd.Parameters.Add($param)
            } else {
                [void]$cmd.Parameters.AddWithValue("@LoadDate", [DateTime]::Parse($row.LoadDate))
            }
            
            if ([string]::IsNullOrEmpty($row.UpdateDate)) {
                $param = New-Object Npgsql.NpgsqlParameter("@UpdateDate", [System.Data.DbType]::DateTime)
                $param.Value = [DBNull]::Value
                [void]$cmd.Parameters.Add($param)
            } else {
                [void]$cmd.Parameters.AddWithValue("@UpdateDate", [DateTime]::Parse($row.UpdateDate))
            }
            
            [void]$cmd.ExecuteNonQuery()
            $imported++
            
            if ($imported % $batchSize -eq 0) {
                Write-Host "   Imported $imported / $totalRecords records..." -ForegroundColor Gray
            }
        }
        
        $transaction.Commit()
        Write-Host "   ✅ Transaction committed`n" -ForegroundColor Green
        
    } catch {
        $transaction.Rollback()
        throw
    }
    
    # Verify count
    Write-Host "📊 Verifying import..." -ForegroundColor Yellow
    $cmd = $conn.CreateCommand()
    $cmd.CommandText = 'SELECT COUNT(*) FROM public."FactSales"'
    $count = $cmd.ExecuteScalar()
    
    $conn.Close()
    
    Write-Host "   Records in PostgreSQL: $count" -ForegroundColor White
    Write-Host "   Records imported: $imported`n" -ForegroundColor White
    
    if ($count -eq $imported) {
        Write-Host "╔════════════════════════════════════════╗" -ForegroundColor Green
        Write-Host "║     Import Successful! ✅             ║" -ForegroundColor Green
        Write-Host "╚════════════════════════════════════════╝`n" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Count mismatch - please verify manually`n" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "❌ Import failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.Exception.StackTrace -ForegroundColor Gray
    exit 1
}
