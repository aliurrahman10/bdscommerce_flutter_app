param(
  [Parameter(Mandatory=$true)][string]$ProjectRoot,
  [Parameter(Mandatory=$false)][string]$DeviceId = ''
)

$ErrorActionPreference = 'Continue'
Set-Location $ProjectRoot

Write-Host '===== PHASE 12H.11B FLUTTER CONSTRUCTOR SAFE HOTFIX CHECK ====='
Write-Host "ProjectRoot: $ProjectRoot"
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
if ($DeviceId -ne '') {
  Write-Host "===== FLUTTER RUN ON DEVICE $DeviceId ====="
  flutter run -d $DeviceId
}
