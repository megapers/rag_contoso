#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Deploys Azure PostgreSQL Flexible Server for RAG Contoso Demo
.DESCRIPTION
    This script provisions a FREE tier PostgreSQL Flexible Server on Azure
    - FREE tier: Standard_B1ms (1 vCore, 2 GiB RAM)
    - 32 GB storage
    - 750 hours/month FREE (24/7 for demo)
.PARAMETER ResourceGroupName
    Name of the Azure resource group (default: rg-productsales-demo)
.PARAMETER Location
    Azure region for deployment (default: eastus)
.PARAMETER AdminPassword
    PostgreSQL administrator password (must be secure)
.EXAMPLE
    .\deploy-postgresql.ps1 -AdminPassword "YourSecureP@ssw0rd123!"
.EXAMPLE
    .\deploy-postgresql.ps1 -ResourceGroupName "rg-productsales-demo" -AdminPassword "YourSecureP@ssw0rd123!"
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "rg-productsales-demo",
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "eastus",
    
    [Parameter(Mandatory=$true)]
    [string]$AdminPassword
)

$ErrorActionPreference = "Stop"

Write-Host "`n🚀 Starting Azure PostgreSQL Deployment" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Check if logged in to Azure
Write-Host "🔐 Checking Azure login..." -ForegroundColor Yellow
$account = az account show 2>$null | ConvertFrom-Json
if (-not $account) {
    Write-Host "❌ Not logged in to Azure. Running 'az login'..." -ForegroundColor Red
    az login
    $account = az account show | ConvertFrom-Json
}
Write-Host "✅ Logged in as: $($account.user.name)" -ForegroundColor Green
Write-Host "📋 Subscription: $($account.name)`n" -ForegroundColor Green

# Check if resource group exists, create if not
Write-Host "📦 Checking resource group..." -ForegroundColor Yellow
$rg = az group show --name $ResourceGroupName 2>$null
if (-not $rg) {
    Write-Host "Creating resource group: $ResourceGroupName in $Location" -ForegroundColor Yellow
    az group create `
        --name $ResourceGroupName `
        --location $Location `
        --tags "Environment=Demo" "Project=RAG-Contoso" "CostCenter=Free-Tier"
    Write-Host "✅ Resource group created`n" -ForegroundColor Green
} else {
    Write-Host "✅ Resource group exists`n" -ForegroundColor Green
}

# Deploy PostgreSQL using Bicep
Write-Host "🐘 Deploying PostgreSQL Flexible Server (FREE tier)..." -ForegroundColor Cyan
Write-Host "   - SKU: Standard_B1ms (1 vCore, 2 GiB RAM)" -ForegroundColor Gray
Write-Host "   - Storage: 32 GB" -ForegroundColor Gray
Write-Host "   - Cost: FREE (750 hours/month)" -ForegroundColor Gray
Write-Host "" -ForegroundColor Gray

$deploymentName = "postgresql-deployment-$(Get-Date -Format 'yyyyMMddHHmmss')"

$deployment = az deployment group create `
    --resource-group $ResourceGroupName `
    --template-file "./postgresql.bicep" `
    --parameters administratorLoginPassword="$AdminPassword" location="$Location" `
    --name $deploymentName `
    --output json | ConvertFrom-Json

if ($LASTEXITCODE -ne 0) {
    Write-Host "`n❌ Deployment failed!" -ForegroundColor Red
    exit 1
}

Write-Host "`n✅ PostgreSQL Deployment Successful!`n" -ForegroundColor Green

# Extract outputs
$outputs = $deployment.properties.outputs
$serverFqdn = $outputs.serverFqdn.value
$serverName = $outputs.serverName.value
$databaseName = $outputs.databaseName.value
$connectionString = $outputs.connectionStringTemplate.value

Write-Host "📊 Deployment Details:" -ForegroundColor Cyan
Write-Host "==========================================`n" -ForegroundColor Cyan
Write-Host "Server FQDN:    $serverFqdn" -ForegroundColor White
Write-Host "Server Name:    $serverName" -ForegroundColor White
Write-Host "Database Name:  $databaseName" -ForegroundColor White
Write-Host ""

Write-Host "🔗 Connection String:" -ForegroundColor Yellow
Write-Host $connectionString.Replace("<password>", "***HIDDEN***") -ForegroundColor Gray
Write-Host ""

Write-Host "⚠️  Important: Update your appsettings.json with:" -ForegroundColor Magenta
Write-Host '  "ConnectionStrings": {' -ForegroundColor Gray
Write-Host '    "PostgresConnection": "' -NoNewline -ForegroundColor Gray
Write-Host $connectionString.Replace("<password>", $AdminPassword) -NoNewline -ForegroundColor Yellow
Write-Host '"' -ForegroundColor Gray
Write-Host '  }' -ForegroundColor Gray
Write-Host ""

Write-Host "🎯 Next Steps:" -ForegroundColor Cyan
Write-Host "1. Update appsettings.json with the PostgreSQL connection string" -ForegroundColor White
Write-Host "2. Set environment variable: USE_POSTGRESQL=true" -ForegroundColor White
Write-Host "3. Run migrations: dotnet ef database update --context ContosoRetailPostgresContext" -ForegroundColor White
Write-Host "4. Import data from SQL Server to PostgreSQL" -ForegroundColor White
Write-Host ""

Write-Host "✅ Deployment Complete!`n" -ForegroundColor Green
