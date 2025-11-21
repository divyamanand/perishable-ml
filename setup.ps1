# Hospital Inventory RL - Automated Setup Script for Windows PowerShell
# Run this script to set up and test your Docker environment

Write-Host "`n" -NoNewline
Write-Host "╔═══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                                                               ║" -ForegroundColor Cyan
Write-Host "║          Hospital Inventory RL - Docker Setup                 ║" -ForegroundColor Cyan
Write-Host "║                                                               ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host "`n"

# Check if Docker is running
Write-Host "🔍 Checking Docker installation..." -ForegroundColor Yellow
try {
    $dockerVersion = docker --version
    Write-Host "✅ Docker is installed: $dockerVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Docker is not installed or not running!" -ForegroundColor Red
    Write-Host "   Please install Docker Desktop from: https://www.docker.com/products/docker-desktop" -ForegroundColor Yellow
    exit 1
}

Write-Host "`n"

# Step 1: Build Docker Image
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "STEP 1: Building Docker Image" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "`n"

Write-Host "📦 Building custom-rl-env image..." -ForegroundColor Yellow
docker build -t custom-rl-env .

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Docker image built successfully!" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to build Docker image!" -ForegroundColor Red
    exit 1
}

Write-Host "`n"

# Step 2: Quick Training Test
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "STEP 2: Testing Training (Quick Run)" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "`n"

Write-Host "🎓 Running quick training test (1000 timesteps)..." -ForegroundColor Yellow
Write-Host "   This will verify your environment is working correctly." -ForegroundColor Gray
Write-Host "`n"

docker run --rm `
  -e TIMESTEPS=1000 `
  -v ${PWD}/models:/app/models `
  custom-rl-env python train/train.py

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n✅ Training test completed successfully!" -ForegroundColor Green
} else {
    Write-Host "`n❌ Training test failed!" -ForegroundColor Red
    exit 1
}

Write-Host "`n"

# Step 3: Full Training (Optional)
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "STEP 3: Full Training (Optional)" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "`n"

$response = Read-Host "Do you want to run full training now (20,000 timesteps)? This will take a few minutes. (y/N)"

if ($response -eq 'y' -or $response -eq 'Y') {
    Write-Host "`n🎓 Running full training..." -ForegroundColor Yellow
    docker run --rm -v ${PWD}/models:/app/models custom-rl-env
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n✅ Full training completed!" -ForegroundColor Green
    } else {
        Write-Host "`n❌ Full training failed!" -ForegroundColor Red
    }
} else {
    Write-Host "⏭️  Skipping full training. You can run it later with:" -ForegroundColor Yellow
    Write-Host "   docker run --rm -v `${PWD}/models:/app/models custom-rl-env" -ForegroundColor Gray
}

Write-Host "`n"

# Step 4: Check for Model
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "STEP 4: Verifying Model" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "`n"

if (Test-Path "models/dqn_inventory.zip") {
    Write-Host "✅ Model found: models/dqn_inventory.zip" -ForegroundColor Green
    $modelSize = (Get-Item "models/dqn_inventory.zip").Length / 1MB
    Write-Host "   Size: $([math]::Round($modelSize, 2)) MB" -ForegroundColor Gray
} else {
    Write-Host "⚠️  No model found. Please train a model first." -ForegroundColor Yellow
}

Write-Host "`n"

# Step 5: Summary and Next Steps
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "🎉 Setup Complete!" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "`n"

Write-Host "📚 What's Available:" -ForegroundColor Green
Write-Host "   • Docker image: custom-rl-env" -ForegroundColor White
Write-Host "   • Training script: train/train.py" -ForegroundColor White
Write-Host "   • Inference script: inference/predict.py" -ForegroundColor White
Write-Host "   • API server: inference/api.py" -ForegroundColor White
Write-Host "`n"

Write-Host "🚀 Next Steps:" -ForegroundColor Green
Write-Host "`n"

Write-Host "   1️⃣  Run Full Training:" -ForegroundColor Yellow
Write-Host "      docker run --rm -v `${PWD}/models:/app/models custom-rl-env" -ForegroundColor White
Write-Host "`n"

Write-Host "   2️⃣  Run Inference:" -ForegroundColor Yellow
Write-Host "      docker run --rm -v `${PWD}/models:/app/models custom-rl-env python inference/predict.py" -ForegroundColor White
Write-Host "`n"

Write-Host "   3️⃣  Start API Server:" -ForegroundColor Yellow
Write-Host "      docker run -p 8000:8000 -v `${PWD}/models:/app/models custom-rl-env uvicorn inference.api:app --host 0.0.0.0 --port 8000" -ForegroundColor White
Write-Host "`n"

Write-Host "   4️⃣  Start Full Stack (with TensorBoard):" -ForegroundColor Yellow
Write-Host "      docker-compose up -d" -ForegroundColor White
Write-Host "`n"

Write-Host "📖 Documentation:" -ForegroundColor Green
Write-Host "   • Quick Start:        QUICK_START.md" -ForegroundColor White
Write-Host "   • Full Guide:         README.md" -ForegroundColor White
Write-Host "   • Commands:           POWERSHELL_COMMANDS.md" -ForegroundColor White
Write-Host "   • Setup Summary:      SETUP_COMPLETE.md" -ForegroundColor White
Write-Host "`n"

Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "`n"

# Optional: Start API if model exists
if (Test-Path "models/dqn_inventory.zip") {
    $startApi = Read-Host "Would you like to start the API server now? (y/N)"
    
    if ($startApi -eq 'y' -or $startApi -eq 'Y') {
        Write-Host "`n🚀 Starting API server on http://localhost:8000..." -ForegroundColor Yellow
        Write-Host "   Press Ctrl+C to stop the server" -ForegroundColor Gray
        Write-Host "   API Docs: http://localhost:8000/docs" -ForegroundColor Gray
        Write-Host "`n"
        
        docker run -p 8000:8000 -v ${PWD}/models:/app/models custom-rl-env uvicorn inference.api:app --host 0.0.0.0 --port 8000
    }
}

Write-Host "✨ Setup script completed successfully!" -ForegroundColor Green
Write-Host "`n"
