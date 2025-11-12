# Azure PostgreSQL Deployment Guide

## 🎯 Overview

This guide helps you deploy a **FREE** Azure PostgreSQL Flexible Server for the RAG Contoso demo application.

**Cost**: FREE (750 hours/month on B1ms tier = 24/7 availability)

## 🏗️ Architecture

```
Local Development (Docker):
┌─────────────────────────┐
│   SQL Server Container  │
│   localhost:1433        │
│   ContosoRetailDW       │
└─────────────────────────┘

Azure Production (Free):
┌─────────────────────────────────┐
│  Azure PostgreSQL Flexible      │
│  pg-rag-contoso-xxx.postgres... │
│  ContosoRetailDW                │
│  FREE: B1ms (1 vCore, 2 GiB)    │
└─────────────────────────────────┘
```

## 📋 Prerequisites

1. **Azure CLI** installed: `winget install Microsoft.AzureCLI`
2. **Azure Subscription** (free tier available)
3. **PowerShell 7+**: `winget install Microsoft.PowerShell`

## 🚀 Deployment Steps

### Step 1: Login to Azure

```powershell
az login
```

### Step 2: Deploy PostgreSQL Server

```powershell
cd Infra

.\deploy-postgresql.ps1 -AdminPassword "YourSecureP@ssw0rd123!"

# Or with custom resource group (must match AI Search deployment)
.\deploy-postgresql.ps1 `
    -ResourceGroupName "rg-productsales-demo" `
    -AdminPassword "YourSecureP@ssw0rd123!" `
    -Location "eastus"
```

**Expected output:**
```
✅ PostgreSQL Deployment Successful!

📊 Deployment Details:
Server FQDN:    pg-rag-contoso-xyz.postgres.database.azure.com
Server Name:    pg-rag-contoso-xyz
Database Name:  ContosoRetailDW

🔗 Connection String:
Server=pg-rag-contoso-xyz.postgres.database.azure.com;Database=ContosoRetailDW;...
```

### Step 3: Update Configuration

Add the connection string to your `appsettings.json`:

```json
{
  "UsePostgreSQL": true,
  "ConnectionStrings": {
    "PostgresConnection": "Server=YOUR_SERVER.postgres.database.azure.com;Database=ContosoRetailDW;User Id=pgadmin;Password=YOUR_PASSWORD;SSL Mode=Require;Trust Server Certificate=true;"
  }
}
```

### Step 4: Install PostgreSQL Provider

```powershell
cd backEnd/ProductSales
dotnet add package Npgsql.EntityFrameworkCore.PostgreSQL
```

### Step 5: Create and Run Migrations

```powershell
# Install EF Core tools if not already installed
dotnet tool install --global dotnet-ef

# Navigate to backend project
cd backEnd/ProductSales

# Create initial migration for PostgreSQL
dotnet ef migrations add InitialPostgres --context ContosoRetailPostgresContext

# Apply migration to Azure PostgreSQL
dotnet ef database update --context ContosoRetailPostgresContext
```

### Step 6: Migrate Data from SQL Server to PostgreSQL

#### Option A: Export/Import via CSV

```powershell
# Export from SQL Server (requires bcp utility)
bcp "SELECT * FROM ContosoRetailDW.dbo.FactSales" queryout "sales.csv" -S localhost,1433 -U sa -P 'Contraseña12345678' -c -t ","

# Import to PostgreSQL (requires psql)
psql -h YOUR_SERVER.postgres.database.azure.com -U pgadmin -d ContosoRetailDW -c "\COPY public.\"FactSales\" FROM 'sales.csv' WITH (FORMAT csv, DELIMITER ',');"
```

#### Option B: Use EF Core Data Seeding (Code-based)

Create a data migration service in your application to read from SQL Server and write to PostgreSQL.

#### Option C: Azure Data Factory (Enterprise)

For larger datasets, use Azure Data Factory with free tier (50 activities/month).

## 🔄 Dual Database Support

The application now supports both databases:

**Local Development (SQL Server):**
```json
{
  "UsePostgreSQL": false,
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost,1433;Database=ContosoRetailDW;..."
  }
}
```

**Azure Production (PostgreSQL):**
```json
{
  "UsePostgreSQL": true,
  "ConnectionStrings": {
    "PostgresConnection": "Server=YOUR_SERVER.postgres.database.azure.com;..."
  }
}
```

**Environment Variable Override:**
```powershell
$env:USE_POSTGRESQL = "true"
dotnet run
```

**Automatic in Production:**
The app automatically uses PostgreSQL when `Environment.IsProduction()` returns true.

## 🐳 Docker Deployment with PostgreSQL

Update your Container Apps environment variables:

```bash
az containerapp update \
  --name ca-rag-contoso \
  --resource-group rg-rag-contoso \
  --set-env-vars \
    "USE_POSTGRESQL=true" \
    "ConnectionStrings__PostgresConnection=Server=YOUR_SERVER.postgres.database.azure.com;Database=ContosoRetailDW;User Id=pgadmin;Password=YOUR_PASSWORD;SSL Mode=Require;Trust Server Certificate=true;"
```

## 📊 Monitoring & Management

### Check Server Status
```bash
az postgres flexible-server show \
  --resource-group rg-rag-contoso \
  --name pg-rag-contoso-xyz
```

### View Connection Logs
```bash
az postgres flexible-server logs download \
  --resource-group rg-rag-contoso \
  --name pg-rag-contoso-xyz
```

### Scale Up (if needed - costs apply)
```bash
az postgres flexible-server update \
  --resource-group rg-rag-contoso \
  --name pg-rag-contoso-xyz \
  --sku-name Standard_B2s
```

## 🔒 Security Best Practices

1. **Firewall Rules**: Restrict to specific IPs
   ```bash
   az postgres flexible-server firewall-rule create \
     --resource-group rg-rag-contoso \
     --name pg-rag-contoso-xyz \
     --rule-name AllowMyIP \
     --start-ip-address YOUR_IP \
     --end-ip-address YOUR_IP
   ```

2. **Use Azure Key Vault** for connection strings:
   ```bash
   az keyvault secret set \
     --vault-name kv-rag-contoso \
     --name PostgresConnectionString \
     --value "Server=..."
   ```

3. **Enable Azure AD Authentication** (recommended for production)

## 💰 Cost Management

**FREE Tier Limits:**
- ✅ 750 hours/month (enough for 24/7 demo)
- ✅ 32 GB storage
- ✅ 1 vCore, 2 GiB RAM

**Monitoring:**
```bash
az postgres flexible-server show \
  --resource-group rg-rag-contoso \
  --name pg-rag-contoso-xyz \
  --query "{Tier:sku.tier, Size:sku.name, Storage:storage.storageSizeGb}"
```

**Stop Server (when not in use):**
```bash
az postgres flexible-server stop \
  --resource-group rg-rag-contoso \
  --name pg-rag-contoso-xyz
```

## 🧪 Testing the Connection

```powershell
# Test with psql
psql -h YOUR_SERVER.postgres.database.azure.com -U pgadmin -d ContosoRetailDW

# Test with .NET
dotnet run
# Navigate to: http://localhost:5000/api/sales
```

## 📚 Additional Resources

- [Azure PostgreSQL Pricing](https://azure.microsoft.com/pricing/details/postgresql/)
- [PostgreSQL Flexible Server Documentation](https://learn.microsoft.com/azure/postgresql/flexible-server/)
- [Npgsql Entity Framework Core Provider](https://www.npgsql.org/efcore/)

## ❓ Troubleshooting

### Connection Timeout
- Check firewall rules: `az postgres flexible-server firewall-rule list`
- Verify SSL Mode is set to `Require`

### Authentication Failed
- Verify username format: `pgadmin` (not `pgadmin@servername`)
- Check password doesn't contain special shell characters

### Migration Errors
- Ensure PostgreSQL context is specified: `--context ContosoRetailPostgresContext`
- Check data type compatibility between SQL Server and PostgreSQL

## 🎉 Next Steps

After PostgreSQL is deployed:
1. ✅ Deploy backend to Azure Container Apps
2. ✅ Configure environment variables
3. ✅ Test API endpoints
4. ✅ Deploy frontend to Azure Static Web Apps
5. ✅ Update frontend API URL

---

**Need Help?** Check the main [DOCKER_DEPLOYMENT.md](./DOCKER_DEPLOYMENT.md) for Container Apps deployment steps.
