# Azure Container Apps Deployment Guide

## 🎯 Overview

This guide walks you through deploying the RAG Contoso backend API to Azure Container Apps.

**Architecture:**
```
┌─────────────────────────────────────────┐
│   Azure Container Apps (FREE TIER)      │
│   - .NET 8 Web API                      │
│   - Scale-to-zero (0.25 vCPU, 0.5 GiB)│
│   - HTTPS ingress                       │
│   └─> Connects to PostgreSQL           │
│   └─> Connects to AI Search            │
│   └─> Uses LLM API                     │
└─────────────────────────────────────────┘
```

## 📋 Prerequisites

1. **Azure Subscription** with Container Apps enabled
2. **Docker Image** published to GitHub Container Registry (ghcr.io)
3. **PostgreSQL** deployed to Azure (from previous steps)
4. **Azure AI Search** deployed (optional but recommended)
5. **LLM API Key** (optional, for RAG features - supports OpenAI, Azure OpenAI, Perplexity, etc.)

## 🚀 Quick Start

### Option 1: Deploy Everything at Once

```powershell
cd Infra

.\deploy-all.ps1 `
    -PostgresAdminPassword "YourSecurePassword123!" `
    -LlmApiKey "your-llm-api-key"
```

This deploys:
- ✅ Azure AI Search (FREE tier)
- ✅ PostgreSQL (FREE tier)
- ✅ Container App (consumption-based pricing)

### Option 2: Deploy Only Container App

If you already have PostgreSQL and AI Search deployed:

```powershell
cd Infra

.\deploy-container-app.ps1 `
    -PostgresAdminPassword "YourSecurePassword123!" `
    -LlmApiKey "your-llm-api-key"
```

### Option 3: Skip Container App for Now

```powershell
.\deploy-all.ps1 `
    -PostgresAdminPassword "YourSecurePassword123!" `
    -SkipContainerApp
```

## 📦 Docker Image Requirements

### Using Pre-built Image (Recommended)

The deployment uses: `ghcr.io/megapers/rag_contoso:latest`

This image is publicly available and contains:
- .NET 8 Runtime
- Compiled backend API
- All dependencies

### Building Your Own Image

If you want to build and push your own image:

```powershell
# Login to GitHub Container Registry
echo $env:GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# Build the image
cd backEnd/ProductSales
docker build -t ghcr.io/YOUR_USERNAME/rag_contoso:latest .

# Push to registry
docker push ghcr.io/YOUR_USERNAME/rag_contoso:latest

# Deploy with custom image
.\deploy-container-app.ps1 `
    -ContainerImage "ghcr.io/YOUR_USERNAME/rag_contoso:latest" `
    -PostgresAdminPassword "Pass123" `
    -LlmApiKey "your-api-key"
```

## 🔧 Configuration

### Environment Variables

The Container App is configured with:

| Variable | Value | Description |
|----------|-------|-------------|
| `ASPNETCORE_ENVIRONMENT` | `Production` | ASP.NET Core environment |
| `ASPNETCORE_URLS` | `http://+:8080` | Listen on port 8080 |
| `USE_POSTGRESQL` | `true` | Use PostgreSQL instead of SQL Server |
| `ConnectionStrings__PostgresConnection` | `Server=...` | PostgreSQL connection string |
| `AzureAISearch__Endpoint` | `https://...` | Azure AI Search endpoint |
| `AzureAISearch__ApiKey` | `***` | AI Search admin key (secret) |
| `AzureAISearch__IndexName` | `contoso-sales-index` | Search index name |
| `LlmApi__ApiKey` | `***` | LLM API key (secret) - supports OpenAI, Azure OpenAI, etc. |

### Scaling Configuration

Default scaling rules:
- **Min replicas:** 0 (scale-to-zero for FREE tier)
- **Max replicas:** 1 (sufficient for demos)
- **Scaling trigger:** HTTP requests (10 concurrent requests per instance)

To increase for production:

```bash
az containerapp update \
  --name <container-app-name> \
  --resource-group rg-productsales-demo \
  --min-replicas 1 \
  --max-replicas 5
```

### Resource Allocation

Default resources per replica (optimized for FREE tier):
- **CPU:** 0.25 cores
- **Memory:** 0.5 GiB

To increase for production, edit `container-app.bicep`:
```bicep
param cpuCores string = '0.5'
param memorySize string = '1.0Gi'
```

## 🧪 Testing the Deployment

### 1. Verify Container App is Running

```bash
az containerapp show \
  --name <container-app-name> \
  --resource-group rg-productsales-demo \
  --query "{Status:properties.provisioningState, FQDN:properties.configuration.ingress.fqdn}"
```

### 2. Test API Endpoints

Get the Container App URL from deployment output, then:

```powershell
# Test health/sales endpoint
curl https://<your-app>.azurecontainerapps.io/api/sales

# Test Swagger UI
Start-Process https://<your-app>.azurecontainerapps.io/swagger
```

### 3. Run ETL to Index Data

```powershell
Invoke-RestMethod `
    -Uri "https://<your-app>.azurecontainerapps.io/api/etl/run" `
    -Method POST `
    -ContentType "application/json"
```

### 4. Test RAG Query

```powershell
$query = @{
    question = "What were the top selling products in 2009?"
} | ConvertTo-Json

Invoke-RestMethod `
    -Uri "https://<your-app>.azurecontainerapps.io/api/rag/query" `
    -Method POST `
    -Body $query `
    -ContentType "application/json"
```

## 📊 Monitoring & Logs

### View Live Logs

```bash
az containerapp logs show \
  --name <container-app-name> \
  --resource-group rg-productsales-demo \
  --follow
```

### View Log Analytics

```bash
# Get Log Analytics workspace ID
az containerapp env show \
  --name <environment-name> \
  --resource-group rg-productsales-demo \
  --query "properties.appLogsConfiguration.logAnalyticsConfiguration.customerId"

# Query logs in Azure Portal
# Navigate to: Log Analytics Workspace > Logs
# Query: ContainerAppConsoleLogs_CL | where TimeGenerated > ago(1h)
```

### View Metrics in Portal

1. Go to Azure Portal
2. Navigate to your Container App
3. Click "Metrics" in the left menu
4. Available metrics:
   - Requests
   - CPU Usage
   - Memory Usage
   - Replica Count

## 🔒 Security

### Secrets Management

Secrets are stored securely in Container App:
- `postgres-password`
- `search-key`
- `llm-api-key`

To update secrets:

```bash
az containerapp secret set \
  --name <container-app-name> \
  --resource-group rg-productsales-demo \
  --secrets "postgres-password=NewPassword123"

# Restart to apply changes
az containerapp revision restart \
  --name <container-app-name> \
  --resource-group rg-productsales-demo \
  --revision <latest-revision-name>
```

### Firewall Rules

Ensure PostgreSQL firewall allows Container App:

```bash
# Container Apps use dynamic IPs, so allow Azure services
az postgres flexible-server firewall-rule create \
  --resource-group rg-productsales-demo \
  --name pg-contoso-6821 \
  --rule-name AllowAzureServices \
  --start-ip-address 0.0.0.0 \
  --end-ip-address 0.0.0.0
```

## 🔄 Updating the Deployment

### Update Container Image

```bash
az containerapp update \
  --name <container-app-name> \
  --resource-group rg-productsales-demo \
  --image ghcr.io/megapers/rag_contoso:v2.0
```

### Update Environment Variables

```bash
az containerapp update \
  --name <container-app-name> \
  --resource-group rg-productsales-demo \
  --set-env-vars "NEW_VAR=value"
```

### Redeploy Using Bicep

```powershell
.\deploy-container-app.ps1 `
    -PostgresAdminPassword "Pass123" `
    -ContainerImage "ghcr.io/megapers/rag_contoso:latest"
```

## 💰 Cost Optimization

### FREE Tier Configuration

The deployment is configured for **FREE tier usage**:
- **vCPU:** 0.25 cores (within free grant)
- **Memory:** 0.5 GiB (within free grant)
- **Min replicas:** 0 (scale-to-zero when idle)
- **Max replicas:** 1

**Monthly FREE Grant:**
- ✅ 180,000 vCPU-seconds (~50 hours of 0.25 vCPU)
- ✅ 360,000 GiB-seconds (~200 hours of 0.5 GiB)
- ✅ First 2 million requests

**Cost: $0/month** for light demo usage! 🎉

### Understanding Scale-to-Zero

With `minReplicas: 0`, your app will:
- ✅ Scale down to 0 when idle (no traffic)
- ✅ **Cost $0 when not in use**
- ⚠️ First request after idle: ~10-30 seconds (cold start)
- ✅ Subsequent requests: fast response

**Perfect for demos and development!**

### Staying Within FREE Tier

To maximize free usage:

1. **Use scale-to-zero** (already configured)
2. **Monitor usage:**
   ```bash
   az monitor metrics list \
     --resource <container-app-id> \
     --metric "Requests" \
     --start-time $(date -u -d '30 days ago' +%Y-%m-%dT%H:%M:%SZ)
   ```
3. **Stop when not needed:**
   ```bash
   az containerapp revision deactivate \
     --name <container-app-name> \
     --resource-group rg-productsales-demo \
     --revision <revision-name>
   ```

### Cost Comparison

| Configuration | Monthly Cost | Use Case |
|--------------|--------------|----------|
| **FREE (0.25 vCPU, scale-to-zero)** | **$0** | ✅ Demo, development |
| Small (0.5 vCPU, 1 replica) | ~$30-40 | Light production |
| Medium (1.0 vCPU, 2 replicas) | ~$120-160 | Production |

### FREE Tier Considerations

Combined FREE tier usage:
- ✅ PostgreSQL: 750 hours/month (FREE)
- ✅ AI Search: 50 MB storage (FREE)
- ✅ Container Apps: 180K vCPU-seconds + 2M requests (FREE)
- **Total: $0/month for demo usage! 🎉**

## 🐛 Troubleshooting

### Container App Not Starting

Check logs:
```bash
az containerapp logs show \
  --name <container-app-name> \
  --resource-group rg-productsales-demo \
  --tail 50
```

Common issues:
- ❌ Invalid connection string → Check PostgreSQL password
- ❌ Cannot pull image → Verify image exists and is public
- ❌ Port mismatch → Ensure app listens on port 8080

### Cannot Connect to PostgreSQL

```bash
# Verify firewall rules
az postgres flexible-server firewall-rule list \
  --resource-group rg-productsales-demo \
  --name pg-contoso-6821

# Add Azure services rule if missing
az postgres flexible-server firewall-rule create \
  --resource-group rg-productsales-demo \
  --name pg-contoso-6821 \
  --rule-name AllowAzureServices \
  --start-ip-address 0.0.0.0 \
  --end-ip-address 0.0.0.0
```

### API Returns 404

Check ingress configuration:
```bash
az containerapp show \
  --name <container-app-name> \
  --resource-group rg-productsales-demo \
  --query "properties.configuration.ingress"
```

Ensure:
- `external: true`
- `targetPort: 8080`
- `allowInsecure: false` (HTTPS only)

## 🎯 Next Steps

After successful deployment:

1. ✅ **Test all API endpoints** to verify functionality
2. ✅ **Run ETL** to index data in Azure AI Search
3. ✅ **Deploy frontend** to Azure Static Web Apps
4. ✅ **Update frontend** to use Container App URL
5. ✅ **Set up monitoring** alerts for errors/high CPU
6. ✅ **Configure CI/CD** for automated deployments

## 📚 Additional Resources

- [Azure Container Apps Documentation](https://learn.microsoft.com/azure/container-apps/)
- [Container Apps Pricing](https://azure.microsoft.com/pricing/details/container-apps/)
- [Bicep Documentation](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
- [GitHub Container Registry](https://docs.github.com/packages/working-with-a-github-packages-registry/working-with-the-container-registry)

---

**Need help?** Check the [main README](../README.md) or the [PostgreSQL deployment guide](./POSTGRESQL_DEPLOYMENT.md).
