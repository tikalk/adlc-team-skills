# product-analyze setup script (PowerShell)
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
$pdrCount = if (Test-Path $PdrDraftsDir) { (Get-ChildItem -Path $PdrDraftsDir -Filter 'PDR-*.md').Count } else { 0 }
# dual-read: compiled PRD at docs/adlc/product/PRD.md, legacy repo-root
# PRD.md fallback (either counts as present).
$prdExists = (Test-Path $PrdFile) -or (Test-Path (Join-Path $RepoRoot "PRD.md"))
if ($Json) {
  Write-Output (@{ REPO_ROOT=$RepoRoot; PDR_DRAFTS_DIR=$PdrDraftsDir; PRD_FILE=$PrdFile; pdr_count=$pdrCount; prd_exists=$prdExists } | ConvertTo-Json)
} else {
  Write-Output "[INFO] product-analyze setup"
  Write-Output "  PDRs: $pdrCount"
  Write-Output "  PRD exists: $prdExists"
}
