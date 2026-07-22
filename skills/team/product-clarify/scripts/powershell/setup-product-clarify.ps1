# product-clarify setup script (PowerShell)
param([switch]$Json)
$ErrorActionPreference = "Stop"
$RepoRoot = $(git rev-parse --show-toplevel 2>$null); if (-not $RepoRoot) { $RepoRoot = Get-Location }
$PdrDraftsDir = Join-Path $RepoRoot ".adlc/drafts/pdr"
$PdrMemoryDir = Join-Path $RepoRoot ".adlc/memory/pdr"
$PrdFile = Join-Path $RepoRoot "PRD.md"
New-Item -ItemType Directory -Force -Path $PdrDraftsDir | Out-Null
$pdrCount = if (Test-Path $PdrDraftsDir) { (Get-ChildItem -Path $PdrDraftsDir -Filter 'PDR-*.md').Count } else { 0 }
$acceptedCount = 0
if (Test-Path $PdrDraftsDir) {
  Get-ChildItem -Path $PdrDraftsDir -Filter 'PDR-*.md' | ForEach-Object {
    $content = Get-Content $_.FullName -Raw
    if ($content -match '\*\*Accepted\*\*') { $acceptedCount++ }
  }
}
if ($Json) {
  Write-Output (@{ REPO_ROOT=$RepoRoot; PDR_DRAFTS_DIR=$PdrDraftsDir; PDR_MEMORY_DIR=$PdrMemoryDir; PRD_FILE=$PrdFile; pdr_count=$pdrCount; accepted_count=$acceptedCount } | ConvertTo-Json)
} else {
  Write-Output "[INFO] product-clarify setup"
  Write-Output "  PDRs found: $pdrCount"
  Write-Output "  Accepted: $acceptedCount"
}
