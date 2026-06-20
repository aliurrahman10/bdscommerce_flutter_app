param(
  [Parameter(Mandatory=$false)][string]$ProjectRoot = (Get-Location).Path
)
$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path $ProjectRoot).Path
$files = @(
  "lib\features\store\store_dashboard_page.dart"
)
$badChars = @([char]0x00E0, [char]0x00C2, [char]0x00C3, [char]0xFFFD)
$bad = @()
foreach ($rel in $files) {
  $path = Join-Path $ProjectRoot $rel
  if (!(Test-Path $path)) { $bad += "MISSING $rel"; continue }
  $text = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
  foreach ($ch in $badChars) {
    if ($text.IndexOf($ch) -ge 0) { $bad += "POSSIBLE_MOJIBAKE $rel char=0x{0:X4}" -f ([int][char]$ch); break }
  }
}
if ($bad.Count -gt 0) {
  $bad | ForEach-Object { Write-Host $_ }
  Write-Host "PHASE13C_ENCODING_AUDIT=CHECK_REQUIRED"
  exit 1
}
Write-Host "PHASE13C_ENCODING_AUDIT=OK"
