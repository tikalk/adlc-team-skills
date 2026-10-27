# product-specify setup script (PowerShell)
param([switch]$Json)
$ErrorActionPreference = "Stop"

# shared layout constants (single definition in paths.ps1).
$AdlcPathsPs1 = "$PSScriptRoot/../../../../team/workspace/scripts/powershell/paths.ps1"
if (-not (Test-Path $AdlcPathsPs1)) {
    $AdlcPathsPs1 = "$PSScriptRoot/../../../workspace/scripts/powershell/paths.ps1"
}
if (Test-Path $AdlcPathsPs1) { . $AdlcPathsPs1 }
$RepoRoot = $(git rev-parse --show-toplevel 2>$null); if (-not $RepoRoot) { $RepoRoot = Get-Location }
$PdrDraftsDir = Join-Path $RepoRoot ".adlc/drafts/pdr"
$PrdFile = Join-Path $RepoRoot "docs/adlc/product/PRD.md"
New-Item -ItemType Directory -Force -Path $PdrDraftsDir | Out-Null

# Ledger slot allocation lives in pdr-lib.ps1 (Get-NextRecordNumber): leading
# digits of the filename stem, max across drafts AND published memory. This
# script previously carried its own copy, which silently skipped stemmed
# records (PDR-002-amendment-2.md) and scanned drafts alone.
$PdrLibPs1 = "$PSScriptRoot/../../../product-clarify/scripts/powershell/pdr-lib.ps1"
if (-not (Test-Path $PdrLibPs1)) {
    $PdrLibPs1 = "$PSScriptRoot/../product-clarify/pdr-lib.ps1"
}
if (-not (Test-Path $PdrLibPs1)) {
    Write-Error "pdr-lib.ps1 not loaded - install the product-clarify skill: adlc-cli skills add tikalk/adlc-team-skills --skill product-clarify"
    exit 1
}
. $PdrLibPs1

$nextPdr = Get-NextRecordNumber -Prefix 'PDR' -Dirs @(
  $PdrDraftsDir,
  (Join-Path $RepoRoot "docs/adlc/memory/pdr")
)
$pdrCount = if (Test-Path $PdrDraftsDir) { (Get-ChildItem -Path $PdrDraftsDir -Filter 'PDR-*.md').Count } else { 0 }

if ($Json) {
  Write-Output (@{ REPO_ROOT=$RepoRoot; PDR_DRAFTS_DIR=$PdrDraftsDir; PRD_FILE=$PrdFile; next_pdr=$nextPdr; pdr_count=$pdrCount } | ConvertTo-Json)
} else {
  Write-Output "[INFO] product-specify setup"
  Write-Output "  REPO_ROOT: $RepoRoot"
  Write-Output "  Next PDR: PDR-$nextPdr"
  Write-Output "  Existing PDRs: $pdrCount"
}
