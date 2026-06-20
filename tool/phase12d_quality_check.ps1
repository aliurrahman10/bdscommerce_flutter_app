param(
    [string]$ProjectRoot = (Get-Location).Path,
    [string]$DeviceId = ""
)

$ErrorActionPreference = "Stop"

Write-Host "===== PHASE 12D FLUTTER QUALITY CHECK ====="
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

if ($DeviceId -ne "") {
    Write-Host "===== FLUTTER RUN ON DEVICE $DeviceId ====="
    flutter run -d $DeviceId
} else {
    Write-Host "===== FLUTTER BUILD DEBUG APK ====="
    flutter build apk --debug
}

Write-Host "PHASE 12D FLUTTER QUALITY CHECK DONE"
