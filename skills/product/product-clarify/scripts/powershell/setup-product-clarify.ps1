# product-clarify setup script (PowerShell)
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
#  canonical PDR memory root (legacy .adlc/memory stays read-compatible).
$PdrMemoryDir = Join-Path $RepoRoot "docs/adlc/memory/pdr"
$PrdFile = Join-Path $RepoRoot "docs/adlc/product/PRD.md"
New-Item -ItemType Directory -Force -Path $PdrDraftsDir | Out-Null
$pdrCount = if (Test-Path $PdrDraftsDir) { (Get-ChildItem -Path $PdrDraftsDir -Filter 'PDR-*.md').Count } else { 0 }
$acceptedCount = 0
if (Test-Path $PdrDraftsDir) {
  $PdrLibPs1 = Join-Path $PSScriptRoot "pdr-lib.ps1"
  if (-not (Test-Path $PdrLibPs1)) {
    Write-Error "pdr-lib.ps1 not loaded - it must sit next to setup-product-clarify.ps1; reinstall the product-clarify skill: adlc-cli skills add tikalk/adlc-team-skills --skill product-clarify"
    exit 1
  }
  . $PdrLibPs1
  if (Get-Command Count-PdrAccepted -ErrorAction SilentlyContinue) {
    $acceptedCount = Count-PdrAccepted -Dir $PdrDraftsDir
  } else {
    Get-ChildItem -Path $PdrDraftsDir -Filter 'PDR-*.md' | ForEach-Object {
      $content = Get-Content $_.FullName -Raw
      if ($content -match '\*\*Accepted\*\*') { $acceptedCount++ }
    }
  }
}
if ($Json) {
  Write-Output (@{ REPO_ROOT=$RepoRoot; PDR_DRAFTS_DIR=$PdrDraftsDir; PDR_MEMORY_DIR=$PdrMemoryDir; PRD_FILE=$PrdFile; pdr_count=$pdrCount; accepted_count=$acceptedCount } | ConvertTo-Json)
} else {
  Write-Output "[INFO] product-clarify setup"
  Write-Output "  PDRs found: $pdrCount"
  Write-Output "  Accepted: $acceptedCount"
}
