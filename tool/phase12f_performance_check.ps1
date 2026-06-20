param(
  [string]$ProjectRoot = "D:\BDS-Mobile\bds_commerce_flutter_starter",
  [string]$DeviceId = "",
  [switch]$BuildRelease
)

$ErrorActionPreference = "Stop"
Write-Host "===== PHASE 12F FLUTTER PERFORMANCE CHECK ====="
Write-Host "ProjectRoot: $ProjectRoot"
Set-Location $ProjectRoot

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

if ($BuildRelease) {
  Write-Host "===== RELEASE APK BUILD ====="
  flutter build apk --release
}

if ($DeviceId -ne "") {
  Write-Host "===== FLUTTER RUN ON DEVICE $DeviceId ====="
  Write-Host "Watch log for skipped frame count before/after Phase 12F. First debug install may still be slower than release."
  flutter run -d $DeviceId
}
