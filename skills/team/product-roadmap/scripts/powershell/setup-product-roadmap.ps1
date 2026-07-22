# product-roadmap setup script (PowerShell)
param([switch]$Json)
$ErrorActionPreference = "Stop"
$RepoRoot = $(git rev-parse --show-toplevel 2>$null); if (-not $RepoRoot) { $RepoRoot = Get-Location }
$PdrDraftsDir = Join-Path $RepoRoot ".adlc/drafts/pdr"
$PdrMemoryDir = Join-Path $RepoRoot ".adlc/memory/pdr"
$PrdFile = Join-Path $RepoRoot "PRD.md"
New-Item -ItemType Directory -Force -Path $PdrDraftsDir | Out-Null
$draftCount = if (Test-Path $PdrDraftsDir) { (Get-ChildItem -Path $PdrDraftsDir -Filter 'PDR-*.md').Count } else { 0 }
$memCount = if (Test-Path $PdrMemoryDir) { (Get-ChildItem -Path $PdrMemoryDir -Filter 'PDR-*.md').Count } else { 0 }
if ($Json) {
  Write-Output (@{ REPO_ROOT=$RepoRoot; PDR_DRAFTS_DIR=$PdrDraftsDir; PDR_MEMORY_DIR=$PdrMemoryDir; PRD_FILE=$PrdFile; draft_count=$draftCount; memory_count=$memCount } | ConvertTo-Json)
} else {
  Write-Output "[INFO] product-roadmap setup"
  Write-Output "  Draft PDRs: $draftCount"
  Write-Output "  Memory PDRs: $memCount"
}
