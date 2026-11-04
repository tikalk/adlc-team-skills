# product-specify setup script (PowerShell)
param([switch]$Json)
$ErrorActionPreference = "Stop"

# Layout roots (.adlc/ machine pipeline; docs/adlc/ human-facing deliverables)
$ADLC_DIR = if ($env:ADLC_DIR) { $env:ADLC_DIR } else { ".adlc" }
$DOCS_ADLC_DIR = if ($env:DOCS_ADLC_DIR) { $env:DOCS_ADLC_DIR } else { "docs/adlc" }
$DOCS_ADLC_MEMORY = if ($env:DOCS_ADLC_MEMORY) { $env:DOCS_ADLC_MEMORY } else { "docs/adlc/memory" }
$DOCS_ADLC_PRODUCT = if ($env:DOCS_ADLC_PRODUCT) { $env:DOCS_ADLC_PRODUCT } else { "docs/adlc/product" }
$DOCS_ADLC_ARCHITECT = if ($env:DOCS_ADLC_ARCHITECT) { $env:DOCS_ADLC_ARCHITECT } else { "docs/adlc/architect" }
$ADLC_DRAFTS = if ($env:ADLC_DRAFTS) { $env:ADLC_DRAFTS } else { ".adlc/drafts" }
$RepoRoot = $(git rev-parse --show-toplevel 2>$null); if (-not $RepoRoot) { $RepoRoot = Get-Location }
$PdrDraftsDir = Join-Path $RepoRoot ".adlc/drafts/pdr"
$PrdFile = Join-Path $RepoRoot "docs/adlc/product/PRD.md"
New-Item -ItemType Directory -Force -Path $PdrDraftsDir | Out-Null

# Ledger slot allocation (vendored from product-clarify pdr-lib.ps1):
# leading digits of the filename stem, max across drafts AND published memory.
function Get-NextRecordNumber {
  param(
    [Parameter(Mandatory = $true)][string]$Prefix,
    [Parameter(Mandatory = $true)][string[]]$Dirs
  )
  $max = 0
  foreach ($dir in $Dirs) {
    if (-not (Test-Path $dir)) { continue }
    Get-ChildItem -Path $dir -Filter "$Prefix-*.md" | ForEach-Object {
      if ($_.BaseName -match ('^' + [regex]::Escape($Prefix) + '-(\d+)')) {
        $n = [int]$Matches[1]
        if ($n -gt $max) { $max = $n }
      }
    }
  }
  '{0:D3}' -f ($max + 1)
}

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
