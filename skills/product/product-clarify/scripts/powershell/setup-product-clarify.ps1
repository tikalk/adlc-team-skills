# product-clarify setup script (PowerShell)
param([switch]$Json)
$ErrorActionPreference = "Stop"


$RepoRoot = $(git rev-parse --show-toplevel 2>$null)
if (-not $RepoRoot) { $RepoRoot = (Get-Location).Path }
$ProjectRoot = $RepoRoot

# Resolve WORKSPACE_REPO_ROOT via shared team-paths (no per-project subfolders)
$_scriptDir = $PSScriptRoot
if (-not $_scriptDir) { $_scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$_teamPaths = $null
foreach ($_cand in @(
  (Join-Path $_scriptDir "../../../../team/team-paths.ps1"),
  (Join-Path $_scriptDir "../../../team/team-paths.ps1"),
  (Join-Path $_scriptDir "../../team/team-paths.ps1"),
  (Join-Path $_scriptDir "../team-paths.ps1"),
  (Join-Path $_scriptDir "team-paths.ps1")
)) {
  if (Test-Path $_cand) { $_teamPaths = $_cand; break }
}
if ($_teamPaths) {
  . $_teamPaths
  $_ws = Resolve-WorkspaceRepoRoot -ProjectRoot $ProjectRoot
  $WorkspaceRepoRoot = $_ws.WorkspaceRepoRoot
  $WorkspaceConfigured = $_ws.WorkspaceConfigured
} else {
  $WorkspaceRepoRoot = $ProjectRoot
  $WorkspaceConfigured = $false
}



$PdrDraftsDir = Join-Path $WorkspaceRepoRoot ".adlc/drafts/pdr"
$PdrMemoryDir = Join-Path $WorkspaceRepoRoot ".adlc/memory/pdr"
$PrdFile = Join-Path $WorkspaceRepoRoot "PRD.md"
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
  Write-Output (@{ REPO_ROOT=$RepoRoot; WORKSPACE_REPO_ROOT=$WorkspaceRepoRoot; PDR_DRAFTS_DIR=$PdrDraftsDir; PDR_MEMORY_DIR=$PdrMemoryDir; PRD_FILE=$PrdFile; pdr_count=$pdrCount; accepted_count=$acceptedCount } | ConvertTo-Json)
} else {
  Write-Output "[INFO] product-clarify setup"
  Write-Output "  PDRs found: $pdrCount"
  Write-Output "  Accepted: $acceptedCount"
}
