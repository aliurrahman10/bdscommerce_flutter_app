param(
  [Parameter(Mandatory=$true)][string]$ProjectRoot,
  [string]$DeviceId = ''
)

$ErrorActionPreference = 'Continue'
Write-Host '===== PHASE 12H.12A SAFE LANGUAGE ENCODING/FONT REPAIR CHECK ====='
Write-Host "ProjectRoot: $ProjectRoot"

powershell -ExecutionPolicy Bypass -File (Join-Path $ProjectRoot 'tool\phase12h_12a_encoding_audit.ps1') -ProjectRoot $ProjectRoot

Set-Location $ProjectRoot
Write-Host '===== FLUTTER CLEAN ====='
flutter clean
Write-Host '===== FLUTTER PUB GET ====='
flutter pub get
Write-Host '===== FLUTTER ANALYZE ====='
flutter analyze
Write-Host '===== FLUTTER TEST ====='
flutter test
Write-Host '===== DEBUG APK BUILD ====='
flutter build apk --debug
if ($DeviceId -and $DeviceId.Trim().Length -gt 0) {
  Write-Host "===== FLUTTER RUN ON DEVICE $DeviceId ====="
  flutter run -d $DeviceId
}
