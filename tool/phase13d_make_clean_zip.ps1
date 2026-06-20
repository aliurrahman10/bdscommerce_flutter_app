param(
  [string]$ProjectRoot,
  [string]$OutputPath,
  [switch]$IncludeUploads
)

$ErrorActionPreference = "Stop"
if (-not $ProjectRoot) { throw "ProjectRoot is required" }
if (-not $OutputPath) { throw "OutputPath is required" }

$ProjectRoot = (Resolve-Path $ProjectRoot).Path
$outDir = Split-Path $OutputPath -Parent
if ($outDir -and -not (Test-Path $outDir)) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }
if (Test-Path $OutputPath) { Remove-Item -Force $OutputPath }

$prefix = Split-Path $ProjectRoot -Leaf
$tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("phase13d_clean_zip_" + [Guid]::NewGuid().ToString("N"))
$stageRoot = Join-Path $tmpRoot $prefix
New-Item -ItemType Directory -Force -Path $stageRoot | Out-Null

$ExcludePatterns = @(
  ".git/*", ".github/*", ".idea/*", ".vscode/*",
  ".env", ".env.*", "*.log", "*.sql", "*.sql.gz", "*.dump", "*.dump.gz", "*.bak", "*.backup",
  "*.zip", "*.tar", "*.tar.gz", "*.tgz", "*.7z", "*.rar",
  "backups/*", "*/backups/*",
  "storage/logs/*", "storage/debugbar/*", "storage/app/*backup*/*", "storage/app/*backups*/*", "storage/app/public/*",
  "storage/framework/cache/data/*", "storage/framework/sessions/*", "storage/framework/testing/*",
  "bootstrap/cache/*.php",
  "vendor/*", "node_modules/*", "build/*", ".dart_tool/*", ".gradle/*", "android/.gradle/*", "ios/Pods/*", "ios/.symlinks/*", "coverage/*",
  ".flutter-plugins", ".flutter-plugins-dependencies"
)
if (-not $IncludeUploads) { $ExcludePatterns += @("public/uploads/*", "public/storage/*", "storage/app/public/*") }

function Normalize-Rel([string]$p) {
  $n = $p -replace "\\", "/"
  while ($n.StartsWith("/")) { $n = $n.Substring(1) }
  return $n
}
function Allowed([string]$rel) {
  $leaf = Split-Path $rel -Leaf
  return ($leaf -eq ".env.example" -or $leaf -eq ".env.production.example" -or $leaf -eq ".env.staging.example")
}
function ShouldExclude([string]$rel) {
  $r = Normalize-Rel $rel
  if (Allowed $r) { return $false }
  foreach ($pat in $ExcludePatterns) {
    if ($r -like $pat) { return $true }
  }
  return $false
}

$count = 0
try {
  Get-ChildItem -Path $ProjectRoot -Recurse -File -Force | ForEach-Object {
    $rel = Normalize-Rel ($_.FullName.Substring($ProjectRoot.Length))
    if (ShouldExclude $rel) { return }
    $dst = Join-Path $stageRoot ($rel -replace "/", [System.IO.Path]::DirectorySeparatorChar)
    $dstDir = Split-Path $dst -Parent
    if (-not (Test-Path $dstDir)) { New-Item -ItemType Directory -Force -Path $dstDir | Out-Null }
    Copy-Item -LiteralPath $_.FullName -Destination $dst -Force
    $script:count++
  }
  $manifest = @{
    phase = "13D.1"
    created_at = (Get-Date -Format o)
    files = $count
    policy = "env/log/sql/backups/runtime/build/vendor excluded"
  } | ConvertTo-Json -Depth 3
  Set-Content -LiteralPath (Join-Path $stageRoot "PHASE13D_RELEASE_MANIFEST.json") -Value $manifest -Encoding UTF8

  if (Get-Command Compress-Archive -ErrorAction SilentlyContinue) {
    Compress-Archive -Path (Join-Path $tmpRoot "*") -DestinationPath $OutputPath -Force
  } else {
    throw "Compress-Archive cmdlet is not available on this PowerShell installation."
  }
} finally {
  if (Test-Path $tmpRoot) { Remove-Item -Recurse -Force $tmpRoot -ErrorAction SilentlyContinue }
}

Write-Host "PHASE13D_CLEAN_PACKAGE=OK"
Write-Host "Output: $OutputPath"
Write-Host "Files: $count"
