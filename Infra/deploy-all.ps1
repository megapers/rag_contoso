#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Deploys all Azure infrastructure for RAG Contoso Demo
.DESCRIPTION
    This script deploys all required Azure resources:
    - Azure AI Search (FREE tier)
    - PostgreSQL Flexible Server (FREE tier)
    All resources are created in the same resource group: rg-productsales-demo
.PARAMETER ResourceGroupName
    Name of the Azure resource group (default: rg-productsales-demo)
.PARAMETER Location
    Azure region for deployment (default: eastus)
.PARAMETER PostgresAdminPassword
    PostgreSQL administrator password (must be secure)
.PARAMETER SkipAISearch
    Skip Azure AI Search deployment
.PARAMETER SkipPostgreSQL
    Skip PostgreSQL deployment
.EXAMPLE
    .\deploy-all.ps1 -PostgresAdminPassword "YourSecureP@ssw0rd123!"
.EXAMPLE
    .\deploy-all.ps1 -ResourceGroupName "rg-productsales-demo" -PostgresAdminPassword "YourSecureP@ssw0rd123!" -Location "eastus"
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "rg-productsales-demo",
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "eastus",
    
    [Parameter(Mandatory=$true)]
    [string]$PostgresAdminPassword,
    
    [Parameter(Mandatory=$false)]
    [string]$LlmApiKey = "",
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipAISearch,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipPostgreSQL,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipContainerApp
)

$ErrorActionPreference = "Stop"

Write-Host "`n╔════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  RAG Contoso - Infrastructure Deploy  ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════╝`n" -ForegroundColor Cyan

Write-Host "📋 Deployment Configuration:" -ForegroundColor Yellow
Write-Host "   Resource Group: $ResourceGroupName" -ForegroundColor White
Write-Host "   Location: $Location" -ForegroundColor White
Write-Host "   AI Search: $(if($SkipAISearch){'❌ Skipped'}else{'✅ Will Deploy'})" -ForegroundColor White
Write-Host "   PostgreSQL: $(if($SkipPostgreSQL){'❌ Skipped'}else{'✅ Will Deploy'})" -ForegroundColor White
Write-Host "   Container App: $(if($SkipContainerApp){'❌ Skipped'}else{'✅ Will Deploy'})" -ForegroundColor White
Write-Host ""

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
        --tags "Environment=Demo" "Project=RAG-Contoso" "CostCenter=Free-Tier" `
        --output none
    Write-Host "✅ Resource group created`n" -ForegroundColor Green
} else {
    Write-Host "✅ Resource group exists`n" -ForegroundColor Green
}

$deploymentResults = @{
    AISearch = $null
    PostgreSQL = $null
    ContainerApp = $null
}

# Deploy Azure AI Search
if (-not $SkipAISearch) {
    Write-Host "`n╔════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║     Deploying Azure AI Search         ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════╝`n" -ForegroundColor Cyan
    
    try {
        & "$PSScriptRoot\deploy-ai-search.ps1" `
            -ResourceGroupName $ResourceGroupName `
            -Location $Location `
            -Sku "free"
        
        $deploymentResults.AISearch = "✅ Success"
        Write-Host "`n✅ Azure AI Search deployed successfully!`n" -ForegroundColor Green
    } catch {
        $deploymentResults.AISearch = "❌ Failed: $($_.Exception.Message)"
        Write-Host "`n❌ Azure AI Search deployment failed: $($_.Exception.Message)`n" -ForegroundColor Red
    }
} else {
    $deploymentResults.AISearch = "⏭️  Skipped"
}

# Deploy PostgreSQL
if (-not $SkipPostgreSQL) {
    Write-Host "`n╔════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║     Deploying PostgreSQL Server       ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════╝`n" -ForegroundColor Cyan
    
    try {
        & "$PSScriptRoot\deploy-postgresql.ps1" `
            -ResourceGroupName $ResourceGroupName `
            -Location $Location `
            -AdminPassword $PostgresAdminPassword
        
        $deploymentResults.PostgreSQL = "✅ Success"
        Write-Host "`n✅ PostgreSQL deployed successfully!`n" -ForegroundColor Green
    } catch {
        $deploymentResults.PostgreSQL = "❌ Failed: $($_.Exception.Message)"
        Write-Host "`n❌ PostgreSQL deployment failed: $($_.Exception.Message)`n" -ForegroundColor Red
    }
} else {
    $deploymentResults.PostgreSQL = "⏭️  Skipped"
}

# Deploy Container App
if (-not $SkipContainerApp) {
    Write-Host "`n╔════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║     Deploying Container App           ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════╝`n" -ForegroundColor Cyan
    
    try {
        & "$PSScriptRoot\deploy-container-app.ps1" `
            -ResourceGroupName $ResourceGroupName `
            -Location $Location `
            -PostgresAdminPassword $PostgresAdminPassword `
            -LlmApiKey $LlmApiKey
        
        $deploymentResults.ContainerApp = "✅ Success"
        Write-Host "`n✅ Container App deployed successfully!`n" -ForegroundColor Green
    } catch {
        $deploymentResults.ContainerApp = "❌ Failed: $($_.Exception.Message)"
        Write-Host "`n❌ Container App deployment failed: $($_.Exception.Message)`n" -ForegroundColor Red
    }
} else {
    $deploymentResults.ContainerApp = "⏭️  Skipped"
}

# Summary
Write-Host "`n╔════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║       Deployment Summary              ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════╝`n" -ForegroundColor Green

Write-Host "📊 Results:" -ForegroundColor Cyan
Write-Host "   Azure AI Search:  $($deploymentResults.AISearch)" -ForegroundColor White
Write-Host "   PostgreSQL:       $($deploymentResults.PostgreSQL)" -ForegroundColor White
Write-Host "   Container App:    $($deploymentResults.ContainerApp)" -ForegroundColor White
Write-Host ""

Write-Host "🔗 Resource Group:" -ForegroundColor Cyan
Write-Host "   Name: $ResourceGroupName" -ForegroundColor White
Write-Host "   Portal: https://portal.azure.com/#resource/subscriptions/$($account.id)/resourceGroups/$ResourceGroupName" -ForegroundColor Yellow
Write-Host ""

Write-Host "🎯 Next Steps:" -ForegroundColor Cyan
Write-Host "1. Verify Container App is running: az containerapp show -n <app-name> -g $ResourceGroupName" -ForegroundColor White
Write-Host "2. Test API endpoints at the Container App URL" -ForegroundColor White
Write-Host "3. Run ETL to index data in Azure AI Search" -ForegroundColor White
Write-Host "4. Deploy frontend to Azure Static Web Apps" -ForegroundColor White
Write-Host ""

$hasFailures = $deploymentResults.Values | Where-Object { $_ -like "❌*" }
if ($hasFailures) {
    Write-Host "⚠️  Some deployments failed. Check the logs above for details.`n" -ForegroundColor Yellow
    exit 1
} else {
    Write-Host "✅ All deployments completed successfully!`n" -ForegroundColor Green
    exit 0
}
