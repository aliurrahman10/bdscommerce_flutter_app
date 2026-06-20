param(
  [Parameter(Mandatory=$true)][string]$ProjectRoot,
  [string]$DeviceId = "",
  [switch]$BuildRelease
)
$ErrorActionPreference = "Stop"
Write-Host "===== PHASE 12H.4 STORE RENEWAL RED BANNER CHECK ====="
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
if ($BuildRelease) {
  Write-Host "===== RELEASE APK BUILD ====="
  flutter build apk --release
} else {
  Write-Host "===== DEBUG APK BUILD ====="
  flutter build apk --debug
}
if ($DeviceId -ne "") {
  Write-Host "===== FLUTTER RUN ON DEVICE $DeviceId ====="
  flutter run -d $DeviceId
}
