# product-roadmap setup script (PowerShell)
param([switch]$Json)
$ErrorActionPreference = "Stop"

function Resolve-SddDocsLocation {
  param([string]$ProjectRoot)
  $loc = $env:SDD_DOCS_LOCATION
  if ($loc) { return $loc }
  $initOpts = Join-Path $ProjectRoot ".adlc" "init-options.json"
  if (Test-Path $initOpts) {
    try {
      $config = Get-Content $initOpts -Raw | ConvertFrom-Json
      if ($config.sdd_docs_location) { return $config.sdd_docs_location }
    } catch {}
  }
  return ""
}

function Get-SddProjectSubfolderName {
  param([string]$ProjectRoot)
  $commonDir = git -C $ProjectRoot rev-parse --git-common-dir 2>$null
  if ($commonDir) {
    $parent = Split-Path $commonDir -Parent
    $normalized = (Resolve-Path $parent -ErrorAction SilentlyContinue).Path
    if ($normalized) { return Split-Path $normalized -Leaf }
  }
  return Split-Path $ProjectRoot -Leaf
}

$RepoRoot = $(git rev-parse --show-toplevel 2>$null)
if (-not $RepoRoot) { $RepoRoot = (Get-Location).Path }
$ProjectRoot = $RepoRoot

$SddDocsLocation = Resolve-SddDocsLocation -ProjectRoot $ProjectRoot
if ($SddDocsLocation) {
  if ($SddDocsLocation.StartsWith("~")) {
    $SddDocsLocation = Join-Path $env:HOME $SddDocsLocation.Substring(1).TrimStart("/", "\")
  }
  $SddRoot = Join-Path $SddDocsLocation.TrimEnd("/", "\") (Get-SddProjectSubfolderName -ProjectRoot $ProjectRoot)
} else {
  $SddRoot = $ProjectRoot
}

$PdrDraftsDir = Join-Path $SddRoot ".adlc/drafts/pdr"
$PdrMemoryDir = Join-Path $SddRoot ".adlc/memory/pdr"
$PrdFile = Join-Path $SddRoot "PRD.md"
New-Item -ItemType Directory -Force -Path $PdrDraftsDir | Out-Null
$draftCount = if (Test-Path $PdrDraftsDir) { (Get-ChildItem -Path $PdrDraftsDir -Filter 'PDR-*.md').Count } else { 0 }
$memCount = if (Test-Path $PdrMemoryDir) { (Get-ChildItem -Path $PdrMemoryDir -Filter 'PDR-*.md').Count } else { 0 }
if ($Json) {
  Write-Output (@{ REPO_ROOT=$RepoRoot; SDD_DOCS_LOCATION=$SddDocsLocation; SDD_ROOT=$SddRoot; PDR_DRAFTS_DIR=$PdrDraftsDir; PDR_MEMORY_DIR=$PdrMemoryDir; PRD_FILE=$PrdFile; draft_count=$draftCount; memory_count=$memCount } | ConvertTo-Json)
} else {
  Write-Output "[INFO] product-roadmap setup"
  Write-Output "  Draft PDRs: $draftCount"
  Write-Output "  Memory PDRs: $memCount"
}
