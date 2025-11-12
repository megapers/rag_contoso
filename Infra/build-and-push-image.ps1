#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Builds and pushes the RAG Contoso backend Docker image
.DESCRIPTION
    This script builds the .NET 8 backend Docker image and pushes it to GitHub Container Registry
.PARAMETER Tag
    Docker image tag (default: latest)
.PARAMETER GithubUsername
    GitHub username (default: megapers)
.PARAMETER GithubToken
    GitHub Personal Access Token with packages:write permission
.EXAMPLE
    .\build-and-push-image.ps1 -GithubToken "ghp_your_token_here"
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$Tag = "latest",
    
    [Parameter(Mandatory=$false)]
    [string]$GithubUsername = "megapers",
    
    [Parameter(Mandatory=$false)]
    [string]$GithubToken = ""
)

$ErrorActionPreference = "Stop"

Write-Host "`n╔════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  Build & Push Docker Image            ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════╝`n" -ForegroundColor Cyan

$imageName = "ghcr.io/$GithubUsername/rag_contoso:$Tag"

# Check if Docker is installed
Write-Host "🐳 Checking Docker..." -ForegroundColor Yellow
$dockerVersion = docker --version 2>$null
if (-not $dockerVersion) {
    Write-Host "❌ Docker is not installed!" -ForegroundColor Red
    Write-Host "   Install from: https://docs.docker.com/get-docker/`n" -ForegroundColor Yellow
    exit 1
}
Write-Host "✅ Docker: $dockerVersion`n" -ForegroundColor Green

# Check if Dockerfile exists
$dockerfilePath = "$PSScriptRoot\..\backEnd\ProductSales\Dockerfile"
if (-not (Test-Path $dockerfilePath)) {
    Write-Host "❌ Dockerfile not found at: $dockerfilePath" -ForegroundColor Red
    Write-Host "   Creating Dockerfile...`n" -ForegroundColor Yellow
    
    $dockerfileContent = @"
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app
EXPOSE 8080

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY ["ProductSales.csproj", "./"]
RUN dotnet restore "ProductSales.csproj"
COPY . .
RUN dotnet build "ProductSales.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "ProductSales.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "ProductSales.dll"]
"@
    
    Set-Content -Path $dockerfilePath -Value $dockerfileContent
    Write-Host "✅ Dockerfile created`n" -ForegroundColor Green
}

# Login to GitHub Container Registry
if (-not [string]::IsNullOrEmpty($GithubToken)) {
    Write-Host "🔐 Logging in to GitHub Container Registry..." -ForegroundColor Yellow
    echo $GithubToken | docker login ghcr.io -u $GithubUsername --password-stdin
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to login to GitHub Container Registry!" -ForegroundColor Red
        Write-Host "   Check your GitHub token has 'write:packages' permission`n" -ForegroundColor Yellow
        exit 1
    }
    Write-Host "✅ Logged in successfully`n" -ForegroundColor Green
} else {
    Write-Host "⚠️  No GitHub token provided - attempting to use cached credentials" -ForegroundColor Yellow
    Write-Host "   If build succeeds but push fails, provide -GithubToken parameter`n" -ForegroundColor Gray
}

# Build the Docker image
Write-Host "🔨 Building Docker image..." -ForegroundColor Cyan
Write-Host "   Image: $imageName" -ForegroundColor White
Write-Host "   Context: $PSScriptRoot\..\backEnd\ProductSales`n" -ForegroundColor Gray

cd "$PSScriptRoot\..\backEnd\ProductSales"

docker build -t $imageName -f Dockerfile .

if ($LASTEXITCODE -ne 0) {
    Write-Host "`n❌ Docker build failed!" -ForegroundColor Red
    exit 1
}

Write-Host "`n✅ Docker image built successfully!`n" -ForegroundColor Green

# Push the image
Write-Host "📤 Pushing image to GitHub Container Registry..." -ForegroundColor Cyan
Write-Host "   This may take a few minutes...`n" -ForegroundColor Gray

docker push $imageName

if ($LASTEXITCODE -ne 0) {
    Write-Host "`n❌ Docker push failed!" -ForegroundColor Red
    Write-Host "`n💡 To fix this:" -ForegroundColor Yellow
    Write-Host "1. Create a GitHub Personal Access Token:" -ForegroundColor White
    Write-Host "   - Go to: https://github.com/settings/tokens/new" -ForegroundColor Gray
    Write-Host "   - Select: write:packages, read:packages" -ForegroundColor Gray
    Write-Host "   - Generate token and copy it" -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. Run this script with the token:" -ForegroundColor White
    Write-Host "   .\build-and-push-image.ps1 -GithubToken `"ghp_your_token_here`"`n" -ForegroundColor Gray
    exit 1
}

Write-Host "`n✅ Image pushed successfully!`n" -ForegroundColor Green

# Make image public (requires gh CLI)
$ghCli = Get-Command gh -ErrorAction SilentlyContinue
if ($ghCli) {
    Write-Host "🔓 Making image public..." -ForegroundColor Yellow
    Write-Host "   Note: This requires GitHub CLI to be authenticated`n" -ForegroundColor Gray
    
    # This command might not work directly, user may need to do it manually in GitHub
    Write-Host "⚠️  To make the image public:" -ForegroundColor Yellow
    Write-Host "1. Go to: https://github.com/$GithubUsername?tab=packages" -ForegroundColor White
    Write-Host "2. Click on 'rag_contoso' package" -ForegroundColor White
    Write-Host "3. Go to 'Package settings'" -ForegroundColor White
    Write-Host "4. Scroll to 'Danger Zone' -> Change visibility -> Public`n" -ForegroundColor White
} else {
    Write-Host "💡 To make the image public:" -ForegroundColor Cyan
    Write-Host "1. Go to: https://github.com/$GithubUsername?tab=packages" -ForegroundColor White
    Write-Host "2. Click on 'rag_contoso' package" -ForegroundColor White
    Write-Host "3. Go to 'Package settings'" -ForegroundColor White
    Write-Host "4. Scroll to 'Danger Zone' -> Change visibility -> Public`n" -ForegroundColor White
}

Write-Host "╔════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║       Build Complete! ✅              ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════╝`n" -ForegroundColor Green

Write-Host "📊 Image Details:" -ForegroundColor Cyan
Write-Host "   Image: $imageName" -ForegroundColor White
Write-Host "   Size: " -NoNewline -ForegroundColor White
docker images $imageName --format "{{.Size}}"
Write-Host ""

Write-Host "🎯 Next Steps:" -ForegroundColor Cyan
Write-Host "1. Make the image public (see instructions above)" -ForegroundColor White
Write-Host "2. Deploy to Azure Container Apps:" -ForegroundColor White
Write-Host "   cd ..\Infra" -ForegroundColor Gray
Write-Host "   .\deploy-container-app.ps1 -PostgresAdminPassword `"Pass`" -LlmApiKey `"key`"`n" -ForegroundColor Gray

cd $PSScriptRoot
