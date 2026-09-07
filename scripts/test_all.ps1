# MapLess AI Full Test Suite Runner
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  MapLess AI — Running All Tests" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# 1. Backend Tests
Write-Host "`n[1/2] Running Backend Tests (Jest)..." -ForegroundColor Yellow
Push-Location "$PSScriptRoot\..\backend"
npm test
$backendStatus = $LASTEXITCODE
Pop-Location

# 2. Flutter Mobile Tests
Write-Host "`n[2/2] Running Mobile Tests (Flutter Test)..." -ForegroundColor Yellow
Push-Location "$PSScriptRoot\..\apps\mobile"
flutter analyze
$analyzeStatus = $LASTEXITCODE
flutter test
$flutterStatus = $LASTEXITCODE
Pop-Location

Write-Host "`n=========================================" -ForegroundColor Cyan
if ($backendStatus -eq 0 -and $analyzeStatus -eq 0 -and $flutterStatus -eq 0) {
    Write-Host "✔ ALL TESTS & ANALYZERS PASSED" -ForegroundColor Green
    exit 0
} else {
    Write-Host "❌ SOME CHECKS FAILED:" -ForegroundColor Red
    if ($backendStatus -ne 0) { Write-Host "  - Backend tests failed" -ForegroundColor Red }
    if ($analyzeStatus -ne 0) { Write-Host "  - Flutter analyze failed" -ForegroundColor Red }
    if ($flutterStatus -ne 0) { Write-Host "  - Flutter tests failed" -ForegroundColor Red }
    exit 1
}
