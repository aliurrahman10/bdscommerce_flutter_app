param([string]$ProjectRoot = (Get-Location).Path)
$ErrorActionPreference = "Stop"
$root = (Resolve-Path $ProjectRoot).Path
$required = @(
  "tool\phase13d_source_audit.ps1",
  "tool\phase13d_make_clean_zip.ps1",
  ".gitignore",
  "PHASE13D_SOURCE_HYGIENE.md"
)
foreach ($rel in $required) {
  if (-not (Test-Path (Join-Path $root $rel))) { Write-Host "FAIL: missing $rel"; exit 1 }
}
$gitignore = Get-Content -Raw -Path (Join-Path $root ".gitignore")
if ($gitignore -notmatch "Phase 13D source/package hygiene") { Write-Host "FAIL: .gitignore Phase 13D block missing"; exit 1 }
Write-Host "PHASE13D_FLUTTER_VERIFY=OK"
Write-Host "Source hygiene tooling installed. Use tool\phase13d_make_clean_zip.ps1 for shareable packages."
