# Complete Azure Deployment Guide - FREE Tier

## 🎯 Overview

Deploy the complete RAG Contoso application to Azure using **100% FREE** services for demo purposes.

## 💰 Cost Breakdown (FREE)

| Service | SKU | Monthly Cost | Usage Limits |
|---------|-----|--------------|--------------|
| PostgreSQL Flexible Server | Standard_B1ms | **$0** | 750 hours/month (31.25 days) |
| Container Apps | Consumption | **$0** | 180,000 vCPU-sec + 360,000 GiB-sec |
| Static Web Apps | Free | **$0** | 100 GB bandwidth/month |
| Azure AI Search | Free | **$0** | 50 MB storage, 10K docs |
| **TOTAL** | | **$0/month** ✅ | Perfect for demos! |

## 📋 Prerequisites

```powershell
# Install Azure CLI
winget install Microsoft.AzureCLI

# Install .NET SDK 8.0
winget install Microsoft.DotNet.SDK.8

# Install Node.js (for frontend)
winget install OpenJS.NodeJS

# Login to Azure
az login
```

## 🚀 Deployment Steps

### Phase 1: Deploy PostgreSQL Database (FREE)

```powershell
cd Infra

# Deploy PostgreSQL (FREE tier)
.\deploy-postgresql.ps1 `
    -AdminPassword "YourSecureP@ssw0rd123!"

# Or deploy all infrastructure at once (RECOMMENDED)
.\deploy-all.ps1 `
    -PostgresAdminPassword "YourSecureP@ssw0rd123!"
```

**Output:**
```
✅ PostgreSQL Deployment Successful!
Server FQDN: pg-rag-contoso-xyz.postgres.database.azure.com
Database: ContosoRetailDW
```

**Save the connection string** - you'll need it later!

---

### Phase 2: Migrate Data to PostgreSQL

```powershell
# Create PostgreSQL tables using EF Core migrations
dotnet ef migrations add InitialPostgres --context ContosoRetailPostgresContext
dotnet ef database update --context ContosoRetailPostgresContext

# Export data from local SQL Server
.\migrate-data.ps1 -PostgresConnectionString "Server=pg-rag-contoso-xyz.postgres.database.azure.com;Database=ContosoRetailDW;User Id=pgadmin;Password=YourSecureP@ssw0rd123!;SSL Mode=Require;Trust Server Certificate=true;"
```

**Manual Import Options:**
- **psql**: Use command line to import CSV
- **pgAdmin**: GUI tool for importing data
- **Azure Data Studio**: With PostgreSQL extension

---

### Phase 3: Deploy Backend to Container Apps

#### 3.1: Create Container Apps Environment

```bash
# Create Container Apps environment (FREE)
az containerapp env create \
  --name cae-rag-contoso \
  --resource-group rg-rag-contoso \
  --location eastus \
  --enable-workload-profiles false
```

#### 3.2: Deploy from GitHub Container Registry

```bash
# Create Container App with PostgreSQL configuration
az containerapp create \
  --name ca-rag-contoso \
  --resource-group rg-rag-contoso \
  --environment cae-rag-contoso \
  --image ghcr.io/megapers/rag_contoso:latest \
  --target-port 8080 \
  --ingress external \
  --min-replicas 0 \
  --max-replicas 1 \
  --cpu 0.25 \
  --memory 0.5Gi \
  --env-vars \
    "USE_POSTGRESQL=true" \
    "ConnectionStrings__PostgresConnection=Server=pg-rag-contoso-xyz.postgres.database.azure.com;Database=ContosoRetailDW;User Id=pgadmin;Password=YourSecureP@ssw0rd123!;SSL Mode=Require;Trust Server Certificate=true;" \
    "AzureSearch__ServiceEndpoint=https://YOUR_SEARCH.search.windows.net" \
    "AzureSearch__AdminKey=YOUR_SEARCH_KEY" \
    "AzureSearch__IndexName=product-sales-index" \
    "LlmApi__BaseUrl=https://api.deepseek.com" \
    "LlmApi__ApiKey=YOUR_LLM_API_KEY" \
    "LlmApi__Model=deepseek-chat"
```

#### 3.3: Get Backend URL

```bash
az containerapp show \
  --name ca-rag-contoso \
  --resource-group rg-rag-contoso \
  --query "properties.configuration.ingress.fqdn" \
  --output tsv
```

**Example Output:**
```
ca-rag-contoso.nicewater-12345678.eastus.azurecontainerapps.io
```

**Test the API:**
```bash
curl https://ca-rag-contoso.nicewater-12345678.eastus.azurecontainerapps.io/api/sales
```

---

### Phase 4: Deploy Frontend to Static Web Apps (FREE)

#### 4.1: Update Frontend Configuration

Update `frontEnd/.env.production`:
```env
REACT_APP_API_URL=https://ca-rag-contoso.nicewater-12345678.eastus.azurecontainerapps.io
```

#### 4.2: Build Frontend

```powershell
cd frontEnd
npm install
npm run build
```

#### 4.3: Deploy to Static Web Apps

```bash
# Create Static Web App (FREE tier)
az staticwebapp create \
  --name swa-rag-contoso \
  --resource-group rg-rag-contoso \
  --location eastus2 \
  --sku Free

# Get deployment token
$token = az staticwebapp secrets list \
  --name swa-rag-contoso \
  --resource-group rg-rag-contoso \
  --query "properties.apiKey" \
  --output tsv

# Deploy using SWA CLI
npm install -g @azure/static-web-apps-cli
swa deploy ./build --deployment-token $token
```

#### 4.4: Configure CORS in Backend

Update Container App environment variables to allow frontend origin:

```bash
az containerapp update \
  --name ca-rag-contoso \
  --resource-group rg-rag-contoso \
  --set-env-vars \
    "AllowedOrigins=https://swa-rag-contoso.eastus2.azurestaticapps.net"
```

Update `Program.cs` CORS configuration:
```csharp
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowReactApp", policy =>
    {
        var allowedOrigins = builder.Configuration
            .GetValue<string>("AllowedOrigins")
            ?.Split(',') ?? Array.Empty<string>();
        
        policy.WithOrigins(allowedOrigins)
              .AllowAnyHeader()
              .AllowAnyMethod()
              .AllowCredentials();
    });
});
```

---

### Phase 5: Azure AI Search (FREE Tier)

```bash
# Create Azure AI Search (FREE tier)
az search service create \
  --name search-rag-contoso \
  --resource-group rg-rag-contoso \
  --location eastus \
  --sku free

# Get admin key
az search admin-key show \
  --service-name search-rag-contoso \
  --resource-group rg-rag-contoso
```

Update Container App with Search credentials:
```bash
az containerapp update \
  --name ca-rag-contoso \
  --resource-group rg-rag-contoso \
  --set-env-vars \
    "AzureSearch__ServiceEndpoint=https://search-rag-contoso.search.windows.net" \
    "AzureSearch__AdminKey=YOUR_ADMIN_KEY" \
    "AzureSearch__IndexName=product-sales-index"
```

---

## 🔄 Continuous Deployment

### Backend Auto-Deploy (Already Configured)

Your GitHub Actions workflow automatically builds and pushes to GHCR on every commit to `main`.

Update Container App to pull latest image:
```bash
az containerapp update \
  --name ca-rag-contoso \
  --resource-group rg-rag-contoso \
  --image ghcr.io/megapers/rag_contoso:latest
```

### Frontend Auto-Deploy

Configure GitHub Actions for Static Web Apps:

```yaml
# .github/workflows/frontend-deploy.yml
name: Deploy Frontend
on:
  push:
    branches: [main]
    paths:
      - 'frontEnd/**'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Build and Deploy
        uses: Azure/static-web-apps-deploy@v1
        with:
          azure_static_web_apps_api_token: ${{ secrets.AZURE_STATIC_WEB_APPS_API_TOKEN }}
          repo_token: ${{ secrets.GITHUB_TOKEN }}
          action: "upload"
          app_location: "/frontEnd"
          output_location: "build"
```

---

## 🧪 Testing the Deployment

### 1. Test PostgreSQL Connection
```bash
psql "Server=pg-rag-contoso-xyz.postgres.database.azure.com;Database=ContosoRetailDW;User Id=pgadmin;Password=YourSecureP@ssw0rd123!;SSL Mode=Require;"
```

### 2. Test Backend API
```bash
# GET all sales
curl https://ca-rag-contoso.nicewater-12345678.eastus.azurecontainerapps.io/api/sales

# POST new sale
curl -X POST https://ca-rag-contoso.nicewater-12345678.eastus.azurecontainerapps.io/api/sales \
  -H "Content-Type: application/json" \
  -d '{"dateKey":"2025-11-11","channelKey":1,"storeKey":100,"productKey":200,"promotionKey":1,"currencyKey":1,"unitCost":10.50,"unitPrice":19.99,"salesQuantity":5,"returnQuantity":0,"totalCost":52.50,"salesAmount":99.95}'

# RAG Query
curl https://ca-rag-contoso.nicewater-12345678.eastus.azurecontainerapps.io/api/rag/query \
  -H "Content-Type: application/json" \
  -d '{"query":"What were the top selling products in 2007?"}'
```

### 3. Test Frontend
Navigate to: `https://swa-rag-contoso.eastus2.azurestaticapps.net`

---

## 📊 Monitoring & Logs

### Container Apps Logs
```bash
# View live logs
az containerapp logs show \
  --name ca-rag-contoso \
  --resource-group rg-rag-contoso \
  --follow

# View system logs
az monitor log-analytics query \
  --workspace YOUR_WORKSPACE_ID \
  --analytics-query "ContainerAppConsoleLogs_CL | where ContainerAppName_s == 'ca-rag-contoso' | order by TimeGenerated desc | take 100"
```

### PostgreSQL Metrics
```bash
az postgres flexible-server show \
  --resource-group rg-rag-contoso \
  --name pg-rag-contoso-xyz \
  --query "{Status:state, CPU:sku.tier, Storage:storage.storageSizeGb}"
```

---

## 🔒 Security Checklist

- ✅ Use Azure Key Vault for secrets (optional but recommended)
- ✅ Configure firewall rules for PostgreSQL (restrict to Container Apps IP)
- ✅ Enable HTTPS only for Container Apps
- ✅ Use Managed Identity for service-to-service auth
- ✅ Regularly rotate API keys and passwords
- ✅ Enable Azure Monitor alerts for anomalies

---

## 🗑️ Cleanup (Delete All Resources)

```bash
# Delete entire resource group (all services)
az group delete --name rg-rag-contoso --yes --no-wait
```

**This will delete:**
- PostgreSQL server
- Container Apps environment
- Static Web App
- Azure AI Search
- All associated resources

---

## 📚 Useful Commands

### Update Container App Environment Variables
```bash
az containerapp update \
  --name ca-rag-contoso \
  --resource-group rg-rag-contoso \
  --set-env-vars "KEY=VALUE"
```

### Scale Container App
```bash
az containerapp update \
  --name ca-rag-contoso \
  --resource-group rg-rag-contoso \
  --min-replicas 1 \
  --max-replicas 3
```

### View All Resources
```bash
az resource list \
  --resource-group rg-rag-contoso \
  --output table
```

---

## 🎉 Success!

Your complete RAG Contoso application is now running on Azure with:
- ✅ FREE PostgreSQL database
- ✅ FREE Container Apps backend
- ✅ FREE Static Web Apps frontend
- ✅ FREE Azure AI Search
- ✅ **Total Cost: $0/month**

**Access your app:**
- Frontend: `https://swa-rag-contoso.eastus2.azurestaticapps.net`
- Backend API: `https://ca-rag-contoso.nicewater-12345678.eastus.azurecontainerapps.io`

---

**Questions?** Refer to:
- [POSTGRESQL_DEPLOYMENT.md](./POSTGRESQL_DEPLOYMENT.md)
- [DOCKER_DEPLOYMENT.md](./DOCKER_DEPLOYMENT.md)
- [SECURITY.md](./SECURITY.md)
