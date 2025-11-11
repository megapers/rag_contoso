# Quick Start - Frontend Only
# Use this if backend is already running

Write-Host "🎨 Starting Frontend Application..." -ForegroundColor Cyan
Write-Host ""

# Check if Node.js is installed
try {
    $nodeVersion = node --version
    Write-Host "✅ Node.js $nodeVersion found" -ForegroundColor Green
} catch {
    Write-Host "❌ Node.js not found. Please install Node.js" -ForegroundColor Red
    exit 1
}

$frontendPath = Join-Path $PSScriptRoot "frontEnd"

# Check if node_modules exists
if (-not (Test-Path "$frontendPath\node_modules")) {
    Write-Host "📦 Installing dependencies..." -ForegroundColor Yellow
    Push-Location $frontendPath
    npm install
    Pop-Location
    Write-Host "✅ Dependencies installed" -ForegroundColor Green
    Write-Host ""
}

Write-Host "🚀 Starting development server..." -ForegroundColor Yellow
Write-Host ""

Push-Location $frontendPath
npm start
Pop-Location
