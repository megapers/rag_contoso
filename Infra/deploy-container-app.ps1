#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Deploys the RAG Contoso backend to Azure Container Apps
.DESCRIPTION
    Deploys a .NET 8 Web API to Azure Container Apps with:
    - PostgreSQL connection
    - Azure AI Search integration
    - LLM API configuration (OpenAI, Azure OpenAI, etc.)
    - FREE tier: Scale-to-zero (0.25 vCPU, 0.5 GiB)
.PARAMETER ResourceGroupName
    Name of the Azure resource group (default: rg-productsales-demo)
.PARAMETER Location
    Azure region for deployment (default: eastus)
.PARAMETER PostgresServerName
    Name of the PostgreSQL server (default: pg-contoso-6821)
.PARAMETER PostgresAdminPassword
    PostgreSQL administrator password
.PARAMETER SearchServiceName
    Name of the Azure AI Search service
.PARAMETER SearchServiceKey
    Azure AI Search admin key
.PARAMETER LlmApiKey
    LLM API key (OpenAI, Perplexity, Azure OpenAI, etc.)
.PARAMETER ContainerImage
    Docker image to deploy (default: ghcr.io/megapers/rag_contoso:latest)
.EXAMPLE
    .\deploy-container-app.ps1 -PostgresAdminPassword "Pass123" -SearchServiceKey "key" -LlmApiKey "key"
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "rg-productsales-demo",
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "eastus",
    
    [Parameter(Mandatory=$false)]
    [string]$PostgresServerName = "pg-contoso-6821",
    
    [Parameter(Mandatory=$true)]
    [string]$PostgresAdminPassword,
    
    [Parameter(Mandatory=$false)]
    [string]$SearchServiceName = "",
    
    [Parameter(Mandatory=$false)]
    [string]$SearchServiceKey = "",
    
    [Parameter(Mandatory=$false)]
    [string]$LlmApiKey = "",
    
    [Parameter(Mandatory=$false)]
    [string]$ContainerImage = "mcr.microsoft.com/dotnet/samples:aspnetapp"
)

$ErrorActionPreference = "Stop"

Write-Host "`n╔════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  Deploy Backend to Container Apps     ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════╝`n" -ForegroundColor Cyan

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

# Check if resource group exists
Write-Host "📦 Checking resource group..." -ForegroundColor Yellow
$rg = az group show --name $ResourceGroupName 2>$null
if (-not $rg) {
    Write-Host "❌ Resource group '$ResourceGroupName' not found!" -ForegroundColor Red
    Write-Host "   Please run deploy-all.ps1 first to create infrastructure`n" -ForegroundColor Yellow
    exit 1
}
Write-Host "✅ Resource group exists`n" -ForegroundColor Green

# Get PostgreSQL server FQDN
Write-Host "🐘 Getting PostgreSQL server details..." -ForegroundColor Yellow
$pgServer = az postgres flexible-server show `
    --resource-group $ResourceGroupName `
    --name $PostgresServerName `
    --output json 2>$null | ConvertFrom-Json

if (-not $pgServer) {
    Write-Host "❌ PostgreSQL server '$PostgresServerName' not found!" -ForegroundColor Red
    Write-Host "   Available servers:" -ForegroundColor Yellow
    az postgres flexible-server list --resource-group $ResourceGroupName --output table
    exit 1
}

$postgresServerFqdn = $pgServer.fullyQualifiedDomainName
Write-Host "✅ PostgreSQL: $postgresServerFqdn`n" -ForegroundColor Green

# Get Azure AI Search endpoint if not provided
if ([string]::IsNullOrEmpty($SearchServiceName)) {
    Write-Host "🔍 Looking for Azure AI Search service..." -ForegroundColor Yellow
    $searchServices = az search service list `
        --resource-group $ResourceGroupName `
        --output json | ConvertFrom-Json
    
    if ($searchServices.Count -eq 0) {
        Write-Host "⚠️  No Azure AI Search service found. Deployment will continue without it." -ForegroundColor Yellow
        Write-Host "   You can add it later by updating the Container App environment variables.`n" -ForegroundColor Gray
        $searchServiceEndpoint = ""
    } else {
        $searchService = $searchServices[0]
        $SearchServiceName = $searchService.name
        $searchServiceEndpoint = "https://$($searchService.name).search.windows.net"
        Write-Host "✅ Found Azure AI Search: $SearchServiceName`n" -ForegroundColor Green
        
        # Get search service key if not provided
        if ([string]::IsNullOrEmpty($SearchServiceKey)) {
            Write-Host "🔑 Retrieving Azure AI Search admin key..." -ForegroundColor Yellow
            $keys = az search admin-key show `
                --resource-group $ResourceGroupName `
                --service-name $SearchServiceName `
                --output json | ConvertFrom-Json
            $SearchServiceKey = $keys.primaryKey
            Write-Host "✅ Key retrieved`n" -ForegroundColor Green
        }
    }
} else {
    $searchServiceEndpoint = "https://$SearchServiceName.search.windows.net"
}

# Prompt for LLM API key if not provided
if ([string]::IsNullOrEmpty($LlmApiKey)) {
    Write-Host "⚠️  LLM API key not provided." -ForegroundColor Yellow
    Write-Host "   The app will work but RAG/LLM features will be limited.`n" -ForegroundColor Gray
    $LlmApiKey = "not-configured"
}

# Build parameters
$parameters = @{
    postgresServerFqdn = $postgresServerFqdn
    postgresAdminPassword = $PostgresAdminPassword
    searchServiceEndpoint = $searchServiceEndpoint
    searchServiceKey = $SearchServiceKey
    llmApiKey = $LlmApiKey
    containerImage = $ContainerImage
}

Write-Host "📋 Deployment Configuration:" -ForegroundColor Cyan
Write-Host "   Resource Group: $ResourceGroupName" -ForegroundColor White
Write-Host "   Location: $Location" -ForegroundColor White
Write-Host "   Container Image: $ContainerImage" -ForegroundColor White
Write-Host "   PostgreSQL: $postgresServerFqdn" -ForegroundColor White
Write-Host "   AI Search: $(if($searchServiceEndpoint){"$searchServiceEndpoint"}else{"Not configured"})" -ForegroundColor White
Write-Host "   LLM API: $(if($LlmApiKey -ne "not-configured"){"✅ Configured"}else{"⚠️  Not configured"})" -ForegroundColor White
Write-Host ""

# Deploy Container App
Write-Host "🚀 Deploying Container App..." -ForegroundColor Cyan
Write-Host "   This may take 3-5 minutes...`n" -ForegroundColor Gray

$deploymentName = "container-app-deployment-$(Get-Date -Format 'yyyyMMddHHmmss')"

$parameterJson = $parameters | ConvertTo-Json -Compress

$deployment = az deployment group create `
    --resource-group $ResourceGroupName `
    --template-file "$PSScriptRoot\container-app.bicep" `
    --parameters location="$Location" `
    --parameters postgresServerFqdn="$postgresServerFqdn" `
    --parameters postgresAdminPassword="$PostgresAdminPassword" `
    --parameters searchServiceEndpoint="$searchServiceEndpoint" `
    --parameters searchServiceKey="$SearchServiceKey" `
    --parameters llmApiKey="$LlmApiKey" `
    --parameters containerImage="$ContainerImage" `
    --name $deploymentName `
    --output json 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Host "`n❌ Deployment failed!" -ForegroundColor Red
    Write-Host $deployment -ForegroundColor Red
    exit 1
}

$deploymentResult = $deployment | ConvertFrom-Json

Write-Host "`n✅ Container App Deployment Successful!`n" -ForegroundColor Green

# Extract outputs
$outputs = $deploymentResult.properties.outputs
$containerAppUrl = $outputs.containerAppUrl.value
$containerAppFqdn = $outputs.containerAppFqdn.value
$containerAppName = $outputs.containerAppName.value

Write-Host "╔════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║       Deployment Complete! 🎉         ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════╝`n" -ForegroundColor Green

Write-Host "📊 Deployment Details:" -ForegroundColor Cyan
Write-Host "==========================================`n" -ForegroundColor Cyan
Write-Host "Container App Name:  $containerAppName" -ForegroundColor White
Write-Host "Container App FQDN:  $containerAppFqdn" -ForegroundColor White
Write-Host "Container App URL:   $containerAppUrl" -ForegroundColor White
Write-Host ""

Write-Host "🔗 API Endpoints:" -ForegroundColor Yellow
Write-Host "   Swagger UI:  $containerAppUrl/swagger" -ForegroundColor Gray
Write-Host "   Sales API:   $containerAppUrl/api/sales" -ForegroundColor Gray
Write-Host "   RAG API:     $containerAppUrl/api/rag/query" -ForegroundColor Gray
Write-Host "   ETL API:     $containerAppUrl/api/etl/run" -ForegroundColor Gray
Write-Host ""

Write-Host "📝 Test the deployment:" -ForegroundColor Cyan
Write-Host "   curl $containerAppUrl/api/sales" -ForegroundColor Gray
Write-Host ""

Write-Host "🎯 Next Steps:" -ForegroundColor Cyan
Write-Host "1. Test the API endpoints to verify deployment" -ForegroundColor White
Write-Host "2. Run ETL to index data: POST $containerAppUrl/api/etl/run" -ForegroundColor White
Write-Host "3. Deploy frontend to Azure Static Web Apps" -ForegroundColor White
Write-Host "4. Update frontend API URL to: $containerAppUrl" -ForegroundColor White
Write-Host ""

Write-Host "📊 Monitor your app:" -ForegroundColor Cyan
Write-Host "   az containerapp logs show --name $containerAppName --resource-group $ResourceGroupName --follow" -ForegroundColor Gray
Write-Host ""

Write-Host "✅ Backend deployment complete!`n" -ForegroundColor Green
