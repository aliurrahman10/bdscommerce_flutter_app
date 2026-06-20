param(
  [Parameter(Mandatory=$true)][string]$ProjectRoot,
  [Parameter(Mandatory=$false)][string]$DeviceId = ""
)
$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path $ProjectRoot).Path
Set-Location $ProjectRoot
Write-Host "===== PHASE 13C PRIVACY/LANGUAGE CHECK ====="
Write-Host "ProjectRoot: $ProjectRoot"
Write-Host "===== ENCODING AUDIT ====="
powershell -ExecutionPolicy Bypass -File ".\tool\phase13c_encoding_audit.ps1" -ProjectRoot $ProjectRoot
Write-Host "===== FLUTTER CLEAN ====="
flutter clean
Write-Host "===== FLUTTER PUB GET ====="
flutter pub get
Write-Host "===== FLUTTER ANALYZE ====="
flutter analyze
Write-Host "===== FLUTTER TEST ====="
flutter test
Write-Host "===== DEBUG APK BUILD ====="
flutter build apk --debug
if ($DeviceId -ne "") {
  Write-Host "===== FLUTTER RUN ON DEVICE $DeviceId ====="
  flutter run -d $DeviceId
}
