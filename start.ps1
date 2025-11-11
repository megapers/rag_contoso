# RAG Application Startup Script
# This script starts both the backend and frontend applications

Write-Host "🚀 Starting RAG Application..." -ForegroundColor Cyan
Write-Host ""

# Check if .NET is installed
Write-Host "Checking .NET installation..." -ForegroundColor Yellow
try {
    $dotnetVersion = dotnet --version
    Write-Host "✅ .NET SDK $dotnetVersion found" -ForegroundColor Green
} catch {
    Write-Host "❌ .NET SDK not found. Please install .NET 8 SDK" -ForegroundColor Red
    exit 1
}

# Check if Node.js is installed
Write-Host "Checking Node.js installation..." -ForegroundColor Yellow
try {
    $nodeVersion = node --version
    Write-Host "✅ Node.js $nodeVersion found" -ForegroundColor Green
} catch {
    Write-Host "❌ Node.js not found. Please install Node.js" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

# Start Backend
Write-Host "🔧 Starting Backend API..." -ForegroundColor Yellow
Write-Host "Location: backEnd/ProductSales" -ForegroundColor Gray
Write-Host ""

$backendPath = Join-Path $PSScriptRoot "backEnd\ProductSales"
$backendJob = Start-Job -ScriptBlock {
    param($path)
    Set-Location $path
    dotnet run
} -ArgumentList $backendPath

Write-Host "✅ Backend starting in background (http://localhost:5003)" -ForegroundColor Green
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

# Wait a moment for backend to initialize
Write-Host "⏳ Waiting for backend to initialize..." -ForegroundColor Yellow
Start-Sleep -Seconds 8

# Start Frontend
Write-Host "🎨 Starting Frontend..." -ForegroundColor Yellow
Write-Host "Location: frontEnd" -ForegroundColor Gray
Write-Host ""

$frontendPath = Join-Path $PSScriptRoot "frontEnd"

# Check if node_modules exists
if (-not (Test-Path "$frontendPath\node_modules")) {
    Write-Host "📦 Installing frontend dependencies..." -ForegroundColor Yellow
    Push-Location $frontendPath
    npm install
    Pop-Location
    Write-Host "✅ Dependencies installed" -ForegroundColor Green
    Write-Host ""
}

Push-Location $frontendPath
$frontendJob = Start-Job -ScriptBlock {
    param($path)
    Set-Location $path
    npm start
} -ArgumentList $frontendPath

Write-Host "✅ Frontend starting (http://localhost:3000)" -ForegroundColor Green
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""
Write-Host "🎉 Both applications are starting!" -ForegroundColor Green
Write-Host ""
Write-Host "📌 Backend:  http://localhost:5003" -ForegroundColor Cyan
Write-Host "📌 Frontend: http://localhost:3000" -ForegroundColor Cyan
Write-Host "📌 Swagger:  http://localhost:5003/swagger" -ForegroundColor Cyan
Write-Host ""
Write-Host "💡 Tip: For HTTPS, run 'dotnet run --launch-profile https' instead" -ForegroundColor Gray
Write-Host ""
Write-Host "Press Ctrl+C to stop both applications" -ForegroundColor Yellow
Write-Host ""

# Wait for user to stop
try {
    Wait-Job -Job $backendJob, $frontendJob
} finally {
    Write-Host ""
    Write-Host "🛑 Stopping applications..." -ForegroundColor Yellow
    Stop-Job -Job $backendJob, $frontendJob
    Remove-Job -Job $backendJob, $frontendJob
    Pop-Location
    Write-Host "✅ Applications stopped" -ForegroundColor Green
}
