param(
  [Parameter(Mandatory=$true)][string]$ProjectRoot,
  [string]$DeviceId = '',
  [switch]$BuildRelease
)
$ErrorActionPreference = 'Stop'
Set-Location $ProjectRoot
Write-Host '===== PHASE 12H.2 FLUTTER HOTFIX RELEASE CHECK ====='
Write-Host "ProjectRoot: $ProjectRoot"
Write-Host '===== FLUTTER CLEAN ====='
flutter clean
Write-Host '===== FLUTTER PUB GET ====='
flutter pub get
Write-Host '===== FLUTTER ANALYZE ====='
flutter analyze
Write-Host '===== FLUTTER TEST ====='
flutter test
if ($BuildRelease) {
  Write-Host '===== RELEASE APK BUILD ====='
  flutter build apk --release
} else {
  Write-Host '===== DEBUG APK BUILD ====='
  flutter build apk --debug
  if ($DeviceId -ne '') {
    Write-Host "===== FLUTTER RUN ON DEVICE $DeviceId ====="
    flutter run -d $DeviceId
  }
}
