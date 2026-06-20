param(
  [string]$ProjectRoot = (Get-Location).Path,
  [string]$ZipPath = ""
)

$ErrorActionPreference = "Stop"

$SensitiveNamePatterns = @(".env", ".env.*", "*.sql", "*.sql.gz", "*.dump", "*.dump.gz", "*.log", "*backup*", "*backups*")
$SecretMarkers = @("APP_KEY=", "DB_PASSWORD=", "MAIL_PASSWORD=", "AWS_SECRET_ACCESS_KEY=", "STRIPE_SECRET=", "PAYPAL_SECRET=", "JWT_SECRET=", "SAAS_SYNC_SECRET=")

function Normalize-Rel([string]$p) { return ($p -replace "\\", "/").TrimStart("/", ".") }
function Allowed([string]$rel) {
  $name = Split-Path $rel -Leaf
  return $name -eq ".env.example"
}
function MatchesAny([string]$rel, [string[]]$patterns) {
  $name = Split-Path $rel -Leaf
  foreach ($pat in $patterns) {
    if ($rel -like $pat -or $name -like $pat) { return $true }
  }
  return $false
}

$issues = New-Object System.Collections.Generic.List[string]

if ($ZipPath -ne "") {
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $zip = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
  try {
    foreach ($entry in $zip.Entries) {
      if ($entry.FullName.EndsWith("/")) { continue }
      $rel = Normalize-Rel $entry.FullName
      if (Allowed $rel) { continue }
      if (MatchesAny $rel $SensitiveNamePatterns) { $issues.Add("sensitive_path: $rel") }
    }
  } finally {
    $zip.Dispose()
  }
  if ($issues.Count -eq 0) { Write-Host "PHASE13D_ZIP_AUDIT=OK"; exit 0 }
  $issues | Select-Object -First 100 | ForEach-Object { Write-Host $_ }
  Write-Host "PHASE13D_ZIP_AUDIT=CHECK_REQUIRED"
  exit 2
}

$root = (Resolve-Path $ProjectRoot).Path
Get-ChildItem -Path $root -Recurse -File -Force | ForEach-Object {
  $rel = Normalize-Rel ($_.FullName.Substring($root.Length))
  if (Allowed $rel) { return }
  if (MatchesAny $rel $SensitiveNamePatterns) { $issues.Add("sensitive_path: $rel") }
}

if ($issues.Count -eq 0) { Write-Host "PHASE13D_TREE_AUDIT=OK"; exit 0 }
$issues | Select-Object -First 100 | ForEach-Object { Write-Host $_ }
Write-Host "PHASE13D_TREE_AUDIT=CHECK_REQUIRED"
exit 2
