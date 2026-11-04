# product-roadmap setup script (PowerShell)
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
#  canonical memory root is docs/adlc/memory; legacy .adlc/memory
# stays read-compatible — memory counts sum both roots (dual-read R8).
$PdrMemoryDir = Join-Path $RepoRoot "docs/adlc/memory/pdr"
$LegacyPdrMemoryDir = Join-Path $RepoRoot ".adlc/memory/pdr"
$PrdFile = Join-Path $RepoRoot "docs/adlc/product/PRD.md"
New-Item -ItemType Directory -Force -Path $PdrDraftsDir | Out-Null
$draftCount = if (Test-Path $PdrDraftsDir) { (Get-ChildItem -Path $PdrDraftsDir -Filter 'PDR-*.md').Count } else { 0 }
$memCount = ( @(Get-ChildItem -Path $PdrMemoryDir -Filter 'PDR-*.md' -ErrorAction SilentlyContinue).Count + @(Get-ChildItem -Path $LegacyPdrMemoryDir -Filter 'PDR-*.md' -ErrorAction SilentlyContinue).Count )
if ($Json) {
  Write-Output (@{ REPO_ROOT=$RepoRoot; PDR_DRAFTS_DIR=$PdrDraftsDir; PDR_MEMORY_DIR=$PdrMemoryDir; PRD_FILE=$PrdFile; draft_count=$draftCount; memory_count=$memCount } | ConvertTo-Json)
} else {
  Write-Output "[INFO] product-roadmap setup"
  Write-Output "  Draft PDRs: $draftCount"
  Write-Output "  Memory PDRs: $memCount"
}
