# Azure AI Search Infrastructure

This folder contains the infrastructure-as-code files for provisioning Azure AI Search.

## Prerequisites

- Azure CLI installed ([Download](https://aka.ms/installazurecliwindows))
- Azure subscription with permissions to create resources
- PowerShell 5.1 or higher

## Deployment

### Quick Start

Run the deployment script with default settings (creates free tier Azure AI Search):

```powershell
.\deploy-ai-search.ps1
```

### Custom Deployment

Specify custom parameters:

```powershell
.\deploy-ai-search.ps1 -ResourceGroupName "my-rg" -Location "westus2" -Sku "basic"
```

### Parameters

- **ResourceGroupName**: Name of the resource group (default: `rg-productsales-demo`)
- **Location**: Azure region (default: `eastus`)
- **SearchServiceName**: Custom name for the search service (default: auto-generated)
- **Sku**: Pricing tier - `free`, `basic`, or `standard` (default: `free`)

## What Gets Deployed

- **Azure AI Search Service** (Free tier)
  - 1 replica, 1 partition
  - Up to 10,000 documents
  - 50 MB storage
  - Semantic search enabled (free)
  - Public network access enabled

## After Deployment

The script will output configuration values for your `appsettings.json`:

```json
"AzureSearch": {
  "ServiceEndpoint": "https://[your-service-name].search.windows.net",
  "AdminKey": "[your-admin-key]",
  "IndexName": "product-sales-index"
}
```

**Important:** 
- Copy these values to your `appsettings.json`
- Keep the admin key secure
- Do NOT commit the admin key to source control

## Cleanup

To delete the deployed resources:

```powershell
az group delete --name rg-productsales-demo --yes --no-wait
```

## Free Tier Limitations

- 1 free search service per subscription
- 10,000 documents maximum
- 50 MB storage
- 3 indexes maximum
- No SLA
- Perfect for development and demos

## Troubleshooting

**Error: "Search service name already taken"**
- Search service names are globally unique
- Use a different name or let the script auto-generate one

**Error: "Free tier already exists"**
- You can only have 1 free tier search service per subscription
- Delete the existing one or use a different SKU

**Error: "Quota exceeded"**
- Check your subscription quotas
- Try a different region
