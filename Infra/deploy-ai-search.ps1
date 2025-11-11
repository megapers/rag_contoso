# Azure AI Search Deployment Script
# This script deploys Azure AI Search service using Bicep

param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "rg-productsales-demo",
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "eastus",
    
    [Parameter(Mandatory=$false)]
    [string]$SearchServiceName = "",
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("free", "basic", "standard")]
    [string]$Sku = "free"
)

# Set error action preference
$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Azure AI Search Deployment" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if Azure CLI is installed
try {
    $azVersion = az version --output json | ConvertFrom-Json
    Write-Host "✓ Azure CLI version: $($azVersion.'azure-cli')" -ForegroundColor Green
} catch {
    Write-Host "✗ Azure CLI is not installed. Please install it from: https://aka.ms/installazurecliwindows" -ForegroundColor Red
    exit 1
}

# Check if logged in to Azure
Write-Host "Checking Azure login status..." -ForegroundColor Yellow
$account = az account show 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Not logged in to Azure. Initiating login..." -ForegroundColor Yellow
    az login
    if ($LASTEXITCODE -ne 0) {
        Write-Host "✗ Azure login failed" -ForegroundColor Red
        exit 1
    }
}

$accountInfo = az account show | ConvertFrom-Json
Write-Host "✓ Logged in as: $($accountInfo.user.name)" -ForegroundColor Green
Write-Host "✓ Subscription: $($accountInfo.name) ($($accountInfo.id))" -ForegroundColor Green
Write-Host ""

# Create resource group if it doesn't exist
Write-Host "Checking resource group '$ResourceGroupName'..." -ForegroundColor Yellow
$rgExists = az group exists --name $ResourceGroupName
if ($rgExists -eq "false") {
    Write-Host "Creating resource group '$ResourceGroupName' in '$Location'..." -ForegroundColor Yellow
    az group create --name $ResourceGroupName --location $Location --output none
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Resource group created successfully" -ForegroundColor Green
    } else {
        Write-Host "✗ Failed to create resource group" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "✓ Resource group already exists" -ForegroundColor Green
}
Write-Host ""

# Deploy Bicep template
Write-Host "Deploying Azure AI Search service..." -ForegroundColor Yellow
Write-Host "  SKU: $Sku" -ForegroundColor Gray
Write-Host "  Location: $Location" -ForegroundColor Gray

$bicepFile = Join-Path $PSScriptRoot "ai-search.bicep"
$deploymentName = "aisearch-deployment-$(Get-Date -Format 'yyyyMMddHHmmss')"

$deploymentParams = @(
    "--resource-group", $ResourceGroupName,
    "--name", $deploymentName,
    "--template-file", $bicepFile,
    "--parameters", "sku=$Sku", "location=$Location"
)

if ($SearchServiceName) {
    $deploymentParams += "--parameters"
    $deploymentParams += "searchServiceName=$SearchServiceName"
}

$deployment = az deployment group create @deploymentParams --output json | ConvertFrom-Json

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Deployment completed successfully" -ForegroundColor Green
    Write-Host ""
    
    # Get outputs
    $searchServiceName = $deployment.properties.outputs.searchServiceName.value
    $searchServiceEndpoint = $deployment.properties.outputs.searchServiceEndpoint.value
    
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Deployment Details" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Search Service Name: $searchServiceName" -ForegroundColor White
    Write-Host "Search Service Endpoint: $searchServiceEndpoint" -ForegroundColor White
    Write-Host ""
    
    # Get admin key
    Write-Host "Retrieving admin key..." -ForegroundColor Yellow
    $keys = az search admin-key show --resource-group $ResourceGroupName --service-name $searchServiceName | ConvertFrom-Json
    $adminKey = $keys.primaryKey
    
    Write-Host "✓ Admin key retrieved" -ForegroundColor Green
    Write-Host ""
    
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Configuration for appsettings.json" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host '"AzureSearch": {' -ForegroundColor White
    Write-Host '  "ServiceEndpoint": "' -NoNewline -ForegroundColor White
    Write-Host $searchServiceEndpoint -NoNewline -ForegroundColor Yellow
    Write-Host '",' -ForegroundColor White
    Write-Host '  "AdminKey": "' -NoNewline -ForegroundColor White
    Write-Host $adminKey -NoNewline -ForegroundColor Yellow
    Write-Host '",' -ForegroundColor White
    Write-Host '  "IndexName": "product-sales-index"' -ForegroundColor White
    Write-Host '}' -ForegroundColor White
    Write-Host ""
    
    Write-Host "⚠ Important: Copy the above configuration to your appsettings.json file" -ForegroundColor Yellow
    Write-Host "⚠ Keep the admin key secure and do not commit it to source control" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "✓ Deployment completed successfully!" -ForegroundColor Green
    
} else {
    Write-Host "✗ Deployment failed" -ForegroundColor Red
    exit 1
}
