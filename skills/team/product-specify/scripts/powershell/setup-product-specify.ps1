# product-specify setup script (PowerShell)
param([switch]$Json)
$ErrorActionPreference = "Stop"
$RepoRoot = $(git rev-parse --show-toplevel 2>$null); if (-not $RepoRoot) { $RepoRoot = Get-Location }
$PdrDraftsDir = Join-Path $RepoRoot ".adlc/drafts/pdr"
$PrdFile = Join-Path $RepoRoot "PRD.md"
New-Item -ItemType Directory -Force -Path $PdrDraftsDir | Out-Null

$max = 0
if (Test-Path $PdrDraftsDir) {
  Get-ChildItem -Path $PdrDraftsDir -Filter 'PDR-*.md' | ForEach-Object {
    $num = $_.Name -replace 'PDR-','' -replace '\.md',''
    if ($num -match '^\d+$') { $n = [int]$num; if ($n -gt $max) { $max = $n } }
  }
}
$nextPdr = '{0:D3}' -f ($max + 1)
$pdrCount = if (Test-Path $PdrDraftsDir) { (Get-ChildItem -Path $PdrDraftsDir -Filter 'PDR-*.md').Count } else { 0 }

if ($Json) {
  Write-Output (@{ REPO_ROOT=$RepoRoot; PDR_DRAFTS_DIR=$PdrDraftsDir; PRD_FILE=$PrdFile; next_pdr=$nextPdr; pdr_count=$pdrCount } | ConvertTo-Json)
} else {
  Write-Output "[INFO] product-specify setup"
  Write-Output "  REPO_ROOT: $RepoRoot"
  Write-Output "  Next PDR: PDR-$nextPdr"
  Write-Output "  Existing PDRs: $pdrCount"
}
