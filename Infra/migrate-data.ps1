# Data Migration Helper Script
# Exports data from SQL Server to PostgreSQL

param(
    [Parameter(Mandatory=$false)]
    [string]$SqlServerConnectionString = "Server=localhost,1433;Database=ContosoRetailDW;User Id=sa;Password=Contraseña12345678;TrustServerCertificate=True;",
    
    [Parameter(Mandatory=$true)]
    [string]$PostgresConnectionString
)

Write-Host "`n📊 RAG Contoso - Data Migration Utility" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Check if SqlClient is available
try {
    Add-Type -AssemblyName "System.Data.SqlClient"
    Write-Host "✅ SQL Server Client loaded" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to load SQL Server Client. Install: dotnet add package System.Data.SqlClient" -ForegroundColor Red
    exit 1
}

Write-Host "`n📤 Step 1: Exporting data from SQL Server..." -ForegroundColor Yellow

# Export using bcp (if available)
$bcpAvailable = Get-Command bcp -ErrorAction SilentlyContinue

if ($bcpAvailable) {
    Write-Host "   Using BCP utility for export..." -ForegroundColor Gray
    
    $exportFile = "FactSales_Export_$(Get-Date -Format 'yyyyMMddHHmmss').csv"
    
    bcp "SELECT * FROM ContosoRetailDW.dbo.FactSales" queryout $exportFile -S "localhost,1433" -U "sa" -P "Contraseña12345678" -c -t ","
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Data exported to: $exportFile" -ForegroundColor Green
        Write-Host "   File size: $((Get-Item $exportFile).Length / 1MB) MB`n" -ForegroundColor Gray
    } else {
        Write-Host "❌ BCP export failed" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "⚠️  BCP utility not found. Manual export required." -ForegroundColor Yellow
    Write-Host "   Install: https://docs.microsoft.com/en-us/sql/tools/bcp-utility`n" -ForegroundColor Gray
}

Write-Host "📥 Step 2: Import to PostgreSQL" -ForegroundColor Yellow
Write-Host "   Use one of these methods:`n" -ForegroundColor Gray

Write-Host "   Option A - psql command line:" -ForegroundColor Cyan
Write-Host "   psql `"$PostgresConnectionString`" -c `"\COPY public.\`"FactSales\`" FROM '$exportFile' WITH (FORMAT csv, DELIMITER ',', HEADER);`"`n" -ForegroundColor Gray

Write-Host "   Option B - pgAdmin:" -ForegroundColor Cyan
Write-Host "   1. Open pgAdmin and connect to your Azure PostgreSQL server" -ForegroundColor Gray
Write-Host "   2. Right-click on 'FactSales' table -> Import/Export Data" -ForegroundColor Gray
Write-Host "   3. Select the CSV file: $exportFile" -ForegroundColor Gray
Write-Host "   4. Configure columns and import`n" -ForegroundColor Gray

Write-Host "   Option C - Azure Data Studio:" -ForegroundColor Cyan
Write-Host "   1. Install 'PostgreSQL' extension" -ForegroundColor Gray
Write-Host "   2. Connect to Azure PostgreSQL" -ForegroundColor Gray
Write-Host "   3. Use 'Import Wizard' on FactSales table`n" -ForegroundColor Gray

Write-Host "   Option D - Code-based migration:" -ForegroundColor Cyan
Write-Host "   Run the API endpoint: POST /api/admin/migrate-data`n" -ForegroundColor Gray

Write-Host "✅ Export complete! Follow the import instructions above.`n" -ForegroundColor Green
