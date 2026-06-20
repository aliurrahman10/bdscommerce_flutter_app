param(
  [Parameter(Mandatory=$true)][string]$ProjectRoot
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = (Resolve-Path $ProjectRoot).Path
$utf8Strict = New-Object System.Text.UTF8Encoding($false, $true)

function Read-Utf8Safe([string]$Path) {
  $bytes = [System.IO.File]::ReadAllBytes($Path)
  try { return $utf8Strict.GetString($bytes) } catch { return [System.Text.Encoding]::UTF8.GetString($bytes) }
}

function Suspicious-Score([string]$Text) {
  if ($null -eq $Text) { return 0 }
  $score = 0
  foreach ($ch in $Text.ToCharArray()) {
    $c = [int][char]$ch
    if ($c -eq 0x00C2 -or $c -eq 0x00C3 -or $c -eq 0x00C0 -or $c -eq 0x00E0 -or $c -eq 0x00A6 -or $c -eq 0x00A7 -or $c -eq 0x00EF -or $c -eq 0x00BF -or $c -eq 0x00BD -or $c -eq 0xFFFD -or $c -eq 0x20AC -or $c -eq 0x2122) {
      $score++
    }
  }
  return $score
}

function Bangla-Score([string]$Text) {
  if ($null -eq $Text) { return 0 }
  $score = 0
  foreach ($ch in $Text.ToCharArray()) {
    $c = [int][char]$ch
    if ($c -ge 0x0980 -and $c -le 0x09FF) { $score++ }
  }
  return $score
}

Write-Host '===== PHASE 12H.12A ENCODING AUDIT ====='
$bad = 0
$bnFiles = 0
$roots = @('lib','test')
foreach ($root in $roots) {
  $fullRoot = Join-Path $ProjectRoot $root
  if (Test-Path $fullRoot) {
    Get-ChildItem -Path $fullRoot -Recurse -Filter '*.dart' | ForEach-Object {
      $text = Read-Utf8Safe $_.FullName
      $score = Suspicious-Score $text
      $bn = Bangla-Score $text
      if ($bn -gt 0) { $bnFiles++ }
      if ($score -gt 0) {
        $bad++
        $rel = $_.FullName.Substring($ProjectRoot.Length).TrimStart('\','/')
        Write-Host "POSSIBLE_MOJIBAKE score=$score file=$rel" -ForegroundColor Yellow
      }
    }
  }
}
Write-Host "Bangla source files: $bnFiles"
Write-Host "Possible mojibake files: $bad"
if ($bad -eq 0) { Write-Host 'PHASE12H12A_ENCODING_AUDIT=OK' } else { Write-Host 'PHASE12H12A_ENCODING_AUDIT=CHECK_REQUIRED' }
