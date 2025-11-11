# 🐳 Docker Deployment Guide - GitHub Container Registry

## Overview

This guide walks you through deploying the RAG Sales Analytics backend to Azure Container Apps using **GitHub Container Registry (GHCR)** - completely free and integrated with your repository.

## Why GitHub Container Registry?

- ✅ **100% Free** - Unlimited public images, generous private image storage
- ✅ **Integrated** - Images live alongside your code at `github.com/megapers/rag_contoso`
- ✅ **Automated** - GitHub Actions builds and pushes on every commit to `main`
- ✅ **Secure** - Use GitHub tokens instead of separate credentials
- ✅ **Private by default** - Images can match your repo's visibility

## Prerequisites

- ✅ Docker Desktop installed and running
- ✅ GitHub account with repository access
- ✅ Azure account (free tier works - Container Apps has free allocation)
- ✅ Azure CLI installed

## Step 1: Build Docker Image

```powershell
# Navigate to backend directory
cd backEnd\ProductSales

# Build the Docker image
docker build -t rag-contoso-backend:latest .

# Verify the image was created
docker images | Select-String "rag-contoso-backend"
```

## Step 2: Test Locally (Optional but Recommended)

```powershell
# Run the container locally
docker run -d -p 8080:8080 `
  --name rag-backend-test `
  -e ConnectionStrings__DefaultConnection="YourConnectionString" `
  -e AzureSearch__ServiceEndpoint="https://your-service.search.windows.net" `
  -e AzureSearch__AdminKey="YourKey" `
  -e LlmApi__BaseUrl="https://api.deepseek.com" `
  -e LlmApi__ApiKey="YourKey" `
  -e LlmApi__Model="deepseek-chat" `
  rag-contoso-backend:latest

# Test the API
curl http://localhost:8080/swagger

# Stop and remove test container
docker stop rag-backend-test
docker rm rag-backend-test
```

## Step 2: Test Locally (Optional but Recommended)

```powershell
# Run the container locally
docker run -d -p 8080:8080 `
  --name rag-backend-test `
  -e ConnectionStrings__DefaultConnection="YourConnectionString" `
  -e AzureSearch__ServiceEndpoint="https://your-service.search.windows.net" `
  -e AzureSearch__AdminKey="YourKey" `
  -e LlmApi__BaseUrl="https://api.deepseek.com" `
  -e LlmApi__ApiKey="YourKey" `
  -e LlmApi__Model="deepseek-chat" `
  rag-contoso-backend:latest

# Test the API
curl http://localhost:8080/swagger

# Stop and remove test container
docker stop rag-backend-test
docker rm rag-backend-test
```

## Step 3: Push to GitHub Container Registry

### 3.1 Create GitHub Personal Access Token (One-time setup)

1. Go to: https://github.com/settings/tokens/new
2. Fill in:
   - **Note**: "GHCR Push Token"
   - **Expiration**: 90 days or No expiration
   - **Scopes**: Check `write:packages`, `read:packages`, `delete:packages`
3. Click **Generate token**
4. **Copy the token** (starts with `ghp_...`)

### 3.2 Login to GitHub Container Registry

```powershell
# Set your GitHub username and token
$GITHUB_USER = "megapers"
$GITHUB_TOKEN = "your_token_here"

# Login to GHCR
echo $GITHUB_TOKEN | docker login ghcr.io -u $GITHUB_USER --password-stdin

# Expected output: Login Succeeded
```

### 3.3 Tag the Image

```powershell
# Tag for GHCR
docker tag rag-contoso-backend:latest ghcr.io/megapers/rag_contoso:latest

# Also tag with a version
docker tag rag-contoso-backend:latest ghcr.io/megapers/rag_contoso:v1.0

# Verify tags
docker images | Select-String "ghcr.io/megapers"
```

### 3.4 Push to GitHub Container Registry

```powershell
# Push latest tag
docker push ghcr.io/megapers/rag_contoso:latest

# Push version tag
docker push ghcr.io/megapers/rag_contoso:v1.0
```

**View your package**: https://github.com/megapers/rag_contoso/pkgs/container/rag_contoso

### 3.5 Make Package Public (Optional)

By default, the package inherits your repo's visibility. To make it public:

1. Go to: https://github.com/megapers/rag_contoso/pkgs/container/rag_contoso/settings
2. Scroll to **Danger Zone**
3. Click **Change visibility** → **Public**

**Note:** Public packages can be pulled without authentication.

## Step 4: Deploy to Azure Container Apps

### 4.1 Login to Azure

```bash
# Login to Azure
az login

# Set your subscription (if you have multiple)
az account set --subscription "Your Subscription Name"

# Create resource group
az group create --name rg-rag-contoso --location eastus
```

### 4.2 Create Container Apps Environment

```bash
# Create Container Apps environment (free tier)
az containerapp env create \
  --name cae-rag-contoso \
  --resource-group rg-rag-contoso \
  --location eastus
```

### 4.3 Create Container App from GitHub Container Registry

```bash
# Create container app with public GHCR image
az containerapp create \
  --name ca-rag-backend \
  --resource-group rg-rag-contoso \
  --environment cae-rag-contoso \
  --image ghcr.io/megapers/rag_contoso:latest \
  --target-port 8080 \
  --ingress external \
  --min-replicas 0 \
  --max-replicas 1 \
  --cpu 0.5 \
  --memory 1.0Gi \
  --env-vars \
    "ASPNETCORE_ENVIRONMENT=Production"
```

**Note:** If your package is private, you'll need to add registry credentials:

```bash
# For private images, create a secret with your GitHub token
az containerapp registry set \
  --name ca-rag-backend \
  --resource-group rg-rag-contoso \
  --server ghcr.io \
  --username megapers \
  --password "your_github_token"
```

### 4.4 Add Secrets as Environment Variables

```bash
# Add secrets (use Azure Key Vault references in production)
az containerapp update \
  --name ca-rag-backend \
  --resource-group rg-rag-contoso \
  --set-env-vars \
    "ConnectionStrings__DefaultConnection=secretref:sql-connection" \
    "AzureSearch__ServiceEndpoint=https://your-service.search.windows.net" \
    "AzureSearch__AdminKey=secretref:search-key" \
    "AzureSearch__IndexName=product-sales-index" \
    "LlmApi__BaseUrl=https://api.deepseek.com" \
    "LlmApi__ApiKey=secretref:llm-key" \
    "LlmApi__Model=deepseek-chat"

# Set secrets
az containerapp secret set \
  --name ca-rag-backend \
  --resource-group rg-rag-contoso \
  --secrets \
    sql-connection="Server=..." \
    search-key="YourKey" \
    llm-key="YourKey"
```

### 4.5 Get the Application URL

```bash
# Get the URL
az containerapp show \
  --name ca-rag-backend \
  --resource-group rg-rag-contoso \
  --query properties.configuration.ingress.fqdn \
  --output tsv
```

Expected output: `ca-rag-backend.nicegrass-12345.eastus.azurecontainerapps.io`

## Step 5: Update Frontend Configuration

Update your frontend `.env` file:

```env
REACT_APP_API_URL=https://ca-rag-backend.nicegrass-12345.eastus.azurecontainerapps.io
```

Then deploy frontend to Azure Static Web Apps (see frontend deployment guide).

## Step 6: Enable CORS for Production

Update `Program.cs` to allow your frontend domain:

```csharp
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowReactApp",
        policy =>
        {
            policy.WithOrigins(
                "http://localhost:3000",  // Development
                "https://your-frontend.azurestaticapps.net"  // Production
            )
            .AllowAnyHeader()
            .AllowAnyMethod()
            .AllowCredentials();
        });
});
```

Rebuild and push the updated image:

```powershell
docker build -t ghcr.io/megapers/rag_contoso:v1.1 ./backEnd/ProductSales
docker push ghcr.io/megapers/rag_contoso:v1.1

# Update container app
az containerapp update \
  --name ca-rag-backend \
  --resource-group rg-rag-contoso \
  --image ghcr.io/megapers/rag_contoso:v1.1
```

## GitHub Actions Automation (Recommended!)

We've included a GitHub Actions workflow that **automatically builds and pushes** the Docker image whenever you push to `main`.

**Workflow file**: `.github/workflows/docker-build.yml`

### How it works:

1. You push code changes to `main` branch
2. GitHub Actions automatically:
   - Builds the Docker image
   - Tags it with `latest`, branch name, and commit SHA
   - Pushes to `ghcr.io/megapers/rag_contoso`
3. You update Azure Container Apps to use the new image

### Manual trigger:

You can also trigger the workflow manually:
1. Go to: https://github.com/megapers/rag_contoso/actions
2. Select **"Build and Push Docker Image"**
3. Click **"Run workflow"** → **"Run workflow"**

### View build status:

Check the Actions tab: https://github.com/megapers/rag_contoso/actions

**No need to run `docker build` locally anymore!** Just `git push` and the image is built in the cloud.

## Monitoring and Logs

### View Logs

```bash
# Stream logs
az containerapp logs show \
  --name ca-rag-backend \
  --resource-group rg-rag-contoso \
  --follow

# View recent logs
az containerapp logs show \
  --name ca-rag-backend \
  --resource-group rg-rag-contoso \
  --tail 100
```

### Check Container Status

```bash
# Get container app details
az containerapp show \
  --name ca-rag-backend \
  --resource-group rg-rag-contoso
```

## Cost Considerations

### Free Tier Limits (No Credit Card Needed)

Azure Container Apps Free Tier:
- ✅ **180,000 vCPU-seconds per month** (free)
- ✅ **360,000 GiB-seconds per month** (free)
- ⚠️ Beyond free tier: ~$0.000012 per vCPU-second

Our configuration (0.5 vCPU, 1GB memory, scale to 0):
- **Running 1 hour/day**: ~54,000 vCPU-seconds/month ✅ FREE
- **Running 24/7**: ~1,296,000 vCPU-seconds/month ❌ Exceeds free tier

**Recommendation for Demo:**
- Set `--min-replicas 0` to scale to zero when not in use (FREE)
- First request takes 5-10 seconds to cold start
- Perfect for demos and testing

GitHub Container Registry Free Tier:
- ✅ **Unlimited public repositories**
- ✅ **500MB free for private images**
- ✅ **Integrated with GitHub** - no separate account needed
- ✅ **Unlimited bandwidth** for public images

## Troubleshooting

### Container Won't Start

Check logs:
```bash
az containerapp logs show --name ca-rag-backend --resource-group rg-rag-contoso --tail 50
```

Common issues:
- Missing environment variables
- Incorrect connection strings
- Port configuration mismatch

### CORS Errors

Ensure:
1. Frontend domain is added to CORS policy
2. Container app ingress is set to `external`
3. HTTPS is used in production

### Database Connection Issues

If using Azure SQL:
- Add Container App IP range to SQL firewall
- Or use "Allow Azure services" option
- Verify connection string format

## Updating the Application

### Option 1: Manual Build (Quick fix)

```powershell
# 1. Make code changes
# 2. Build new image
docker build -t ghcr.io/megapers/rag_contoso:v1.2 ./backEnd/ProductSales

# 3. Push to GHCR
docker push ghcr.io/megapers/rag_contoso:v1.2

# 4. Update Container App
az containerapp update \
  --name ca-rag-backend \
  --resource-group rg-rag-contoso \
  --image ghcr.io/megapers/rag_contoso:v1.2
```

### Option 2: Automated via GitHub Actions (Recommended)

```powershell
# 1. Make code changes
# 2. Commit and push to main
git add .
git commit -m "feat: Your changes"
git push origin main

# 3. GitHub Actions builds and pushes automatically
# 4. Update Container App with new image
az containerapp update \
  --name ca-rag-backend \
  --resource-group rg-rag-contoso \
  --image ghcr.io/megapers/rag_contoso:main-$(git rev-parse --short HEAD)
```

## Cleanup

```bash
# Delete container app
az containerapp delete --name ca-rag-backend --resource-group rg-rag-contoso --yes

# Delete entire resource group (removes everything)
az group delete --name rg-rag-contoso --yes --no-wait
```

## Security Best Practices

1. ✅ **Use Azure Key Vault** for production secrets
2. ✅ **Enable Managed Identity** for Azure service connections
3. ✅ **Keep packages private** unless needed (GHCR supports private images on free tier)
4. ✅ **Enable diagnostic logs** and monitoring
5. ✅ **Set resource limits** to prevent unexpected costs
6. ✅ **Use HTTPS only** - disable HTTP ingress
7. ✅ **Regular updates** - GitHub Actions can rebuild images with security patches
8. ✅ **Use GitHub Dependabot** for automatic dependency updates

## Additional Resources

- **GitHub Container Registry Docs**: https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry
- **GitHub Actions Docs**: https://docs.github.com/en/actions
- **Azure Container Apps Docs**: https://learn.microsoft.com/en-us/azure/container-apps/
- **Your package on GitHub**: https://github.com/megapers/rag_contoso/pkgs/container/rag_contoso
- **Your Actions workflows**: https://github.com/megapers/rag_contoso/actions

---

**You're now ready to deploy! 🚀**
