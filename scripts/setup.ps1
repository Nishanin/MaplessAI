# MapLess AI Local Environment Setup Script
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  MapLess AI -- Project Setup" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# 1. Backend Setup
Write-Host "`n[1/2] Installing Backend Dependencies..." -ForegroundColor Yellow
Push-Location "$PSScriptRoot\..\backend"
npm install
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: npm install failed in backend/" -ForegroundColor Red
    Pop-Location
    exit 1
}
Pop-Location

# 2. Mobile Setup
Write-Host "`n[2/2] Fetching Flutter Dependencies in apps/mobile..." -ForegroundColor Yellow
Push-Location "$PSScriptRoot\..\apps\mobile"
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "Error: flutter pub get failed in apps/mobile/" -ForegroundColor Red
    Pop-Location
    exit 1
}
Pop-Location

Write-Host "`n[OK] MapLess AI environment successfully initialized!" -ForegroundColor Green
Write-Host "  To run backend: cd backend && npm start"
Write-Host "  To run mobile:  cd apps/mobile && flutter run"
