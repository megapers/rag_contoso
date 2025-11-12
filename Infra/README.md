# Azure Infrastructure Deployment

This directory contains all infrastructure-as-code (IaC) files for deploying the RAG Contoso application to Azure.

## 📁 Files

### Bicep Templates
- **`ai-search.bicep`** - Azure AI Search service deployment
- **`postgresql.bicep`** - PostgreSQL Flexible Server deployment (FREE tier)

### PowerShell Scripts
- **`deploy-all.ps1`** - Deploys all infrastructure in one command ⭐ **RECOMMENDED**
- **`deploy-ai-search.ps1`** - Deploys Azure AI Search only
- **`deploy-postgresql.ps1`** - Deploys PostgreSQL server only
- **`migrate-data.ps1`** - Helper script to migrate data from SQL Server to PostgreSQL

### Documentation
- **`POSTGRESQL_DEPLOYMENT.md`** - Detailed PostgreSQL deployment guide
- **`README.md`** - This file

## 🚀 Quick Start

### Deploy All Infrastructure (Recommended)

```powershell
# Deploy everything to the default resource group (rg-productsales-demo)
.\deploy-all.ps1 -PostgresAdminPassword "YourSecureP@ssw0rd123!"
```

### Deploy Individual Components

```powershell
# Deploy only Azure AI Search
.\deploy-ai-search.ps1

# Deploy only PostgreSQL
.\deploy-postgresql.ps1 -AdminPassword "YourSecureP@ssw0rd123!"

# Deploy with custom resource group
.\deploy-all.ps1 `
    -ResourceGroupName "my-custom-rg" `
    -Location "westus2" `
    -PostgresAdminPassword "YourSecureP@ssw0rd123!"
```

## 💰 Cost (FREE Tier)

All deployments use FREE tier resources:

| Service | SKU | Monthly Cost |
|---------|-----|--------------|
| Azure AI Search | Free | **$0** |
| PostgreSQL Flexible Server | Standard_B1ms | **$0** (750 hours/month) |
| **TOTAL** | | **$0/month** ✅ |

## 🎯 Default Configuration

- **Resource Group**: `rg-productsales-demo`
- **Location**: `eastus`
- **PostgreSQL**: 
  - Version: 16
  - Tier: Burstable (Standard_B1ms)
  - Storage: 32 GB
  - Database: ContosoRetailDW
- **Azure AI Search**:
  - SKU: Free
  - Replica Count: 1
  - Partition Count: 1

## 📋 Prerequisites

```powershell
# Install Azure CLI
winget install Microsoft.AzureCLI

# Login to Azure
az login

# Verify subscription
az account show
```

## 🔧 Parameters

### deploy-all.ps1

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| ResourceGroupName | No | rg-productsales-demo | Azure resource group name |
| Location | No | eastus | Azure region |
| PostgresAdminPassword | Yes | - | PostgreSQL admin password |
| SkipAISearch | No | false | Skip AI Search deployment |
| SkipPostgreSQL | No | false | Skip PostgreSQL deployment |

### deploy-ai-search.ps1

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| ResourceGroupName | No | rg-productsales-demo | Azure resource group name |
| Location | No | eastus | Azure region |
| SearchServiceName | No | Auto-generated | Custom search service name |
| Sku | No | free | Pricing tier (free/basic/standard) |

### deploy-postgresql.ps1

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| ResourceGroupName | No | rg-productsales-demo | Azure resource group name |
| Location | No | eastus | Azure region |
| AdminPassword | Yes | - | PostgreSQL admin password |

## 📚 Next Steps After Deployment

1. **Update Configuration**
   ```json
   // appsettings.json
   {
     "UsePostgreSQL": true,
     "ConnectionStrings": {
       "PostgresConnection": "Server=YOUR_SERVER.postgres.database.azure.com;..."
     },
     "AzureSearch": {
       "ServiceEndpoint": "https://YOUR_SEARCH.search.windows.net",
       "AdminKey": "YOUR_KEY"
     }
   }
   ```

2. **Create PostgreSQL Tables**
   ```powershell
   cd ../backEnd/ProductSales
   dotnet ef migrations add InitialPostgres --context ContosoRetailPostgresContext
   dotnet ef database update --context ContosoRetailPostgresContext
   ```

3. **Migrate Data**
   ```powershell
   cd ../Infra
   .\migrate-data.ps1 -PostgresConnectionString "Server=..."
   ```

4. **Deploy Backend**
   - See main deployment documentation for Container Apps setup

## 🗑️ Cleanup

Delete all resources:
```powershell
az group delete --name rg-productsales-demo --yes --no-wait
```

## 📖 Additional Documentation

- [POSTGRESQL_DEPLOYMENT.md](./POSTGRESQL_DEPLOYMENT.md) - Detailed PostgreSQL guide
- [../AZURE_DEPLOYMENT_COMPLETE.md](../AZURE_DEPLOYMENT_COMPLETE.md) - Complete Azure deployment guide
- [../IMPLEMENTATION_SUMMARY.md](../IMPLEMENTATION_SUMMARY.md) - Recent changes summary

## 🆘 Troubleshooting

### Resource Group Already Exists
The scripts will use the existing resource group if it already exists.

### PostgreSQL Server Name Conflict
The Bicep template generates a unique name using `uniqueString(resourceGroup().id)`.

### Azure CLI Not Found
```powershell
winget install Microsoft.AzureCLI
# Restart PowerShell after installation
```

### Not Logged In
```powershell
az login
az account set --subscription "YOUR_SUBSCRIPTION_NAME"
```

### Password Requirements
PostgreSQL password must:
- Be at least 8 characters
- Contain uppercase and lowercase letters
- Contain numbers
- Contain special characters

## 🎯 Example Deployment Flow

```powershell
# 1. Navigate to infrastructure directory
cd C:\Users\megap\Desktop\Study\Microsoft-RAG\ETL\Infra

# 2. Deploy all infrastructure
.\deploy-all.ps1 -PostgresAdminPassword "MySecure@Pass123"

# 3. The script will:
#    - Login to Azure (if needed)
#    - Create resource group: rg-productsales-demo
#    - Deploy Azure AI Search (FREE)
#    - Deploy PostgreSQL (FREE)
#    - Output connection strings

# 4. Update your appsettings.json with the output values

# 5. Run migrations
cd ../backEnd/ProductSales
dotnet ef database update --context ContosoRetailPostgresContext

# 6. Done! Ready to deploy backend to Azure Container Apps
```
