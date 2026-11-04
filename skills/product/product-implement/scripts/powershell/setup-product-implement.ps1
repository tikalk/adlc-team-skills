# product-implement setup script (PowerShell)
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
#  canonical PDR memory root (legacy .adlc/memory stays read-compatible).
$PdrMemoryDir = Join-Path $RepoRoot "docs/adlc/memory/pdr"
$PrdFile = Join-Path $RepoRoot "docs/adlc/product/PRD.md"
$SectionsDir = Join-Path $RepoRoot ".adlc/product/sections"
$StateFile = Join-Path $RepoRoot ".adlc/product/state.json"
New-Item -ItemType Directory -Force -Path $PdrDraftsDir | Out-Null
New-Item -ItemType Directory -Force -Path $PdrMemoryDir | Out-Null
New-Item -ItemType Directory -Force -Path $SectionsDir | Out-Null
#  compiled PRD lives under docs/adlc/product/ — ensure the parent exists.
New-Item -ItemType Directory -Force -Path (Join-Path $RepoRoot "docs/adlc/product") | Out-Null

$acceptedCount = 0
if (Test-Path $PdrDraftsDir) {
  Get-ChildItem -Path $PdrDraftsDir -Filter 'PDR-*.md' | ForEach-Object {
    $content = Get-Content $_.FullName -Raw
    if ($content -match '\*\*Accepted\*\*') { $acceptedCount++ }
  }
}

# Ledger slot allocation (vendored from product-clarify pdr-lib.ps1 per the
# scope rule: scripts stay skill-local, helpers are vendored, never sourced
# across skills). A record's number is the LEADING DIGITS of its filename
# stem; the maximum spans drafts AND published memory.
function Get-NextRecordNumber {
  param([string]$Prefix, [string[]]$Dirs)
  $max = 0
  foreach ($dir in $Dirs) {
    if (-not (Test-Path -LiteralPath $dir)) { continue }
    foreach ($file in Get-ChildItem -LiteralPath $dir -Filter "$Prefix-*.md" -File -ErrorAction SilentlyContinue) {
      if ($file.BaseName -match "^$Prefix-(\d+)") {
        $n = [int]$Matches[1]
        if ($n -gt $max) { $max = $n }
      }
    }
  }
  return ('{0:d3}' -f ($max + 1))
}

# The three document-internal PRD.md slots. Each scan is deliberately
# over-inclusive: an unused number is harmless, a reissued one collides.
function Get-NextPrdSection {
  param([string]$Path)
  $max = 0
  if (Test-Path -LiteralPath $Path) {
    foreach ($line in Get-Content -LiteralPath $Path) {
      if ($line -match '^## (\d+)\. ') {
        $n = [int]$Matches[1]
        if ($n -gt $max) { $max = $n }
      }
    }
  }
  return ($max + 1)
}

function Get-NextReqId {
  param([string]$Path)
  $max = 0
  if (Test-Path -LiteralPath $Path) {
    foreach ($m in [regex]::Matches((Get-Content -LiteralPath $Path -Raw), 'REQ-(\d+)')) {
      $n = [int]$m.Groups[1].Value
      if ($n -gt $max) { $max = $n }
    }
  }
  return ($max + 1)
}

function Get-NextFeatureNumber {
  param([string]$Path)
  $max = 0
  if (Test-Path -LiteralPath $Path) {
    foreach ($line in Get-Content -LiteralPath $Path) {
      if ($line -match '^\| (\d+) \|') {
        $n = [int]$Matches[1]
        if ($n -gt $max) { $max = $n }
      }
    }
  }
  return ($max + 1)
}

$nextPdr = Get-NextRecordNumber -Prefix 'PDR' -Dirs @($PdrDraftsDir, $PdrMemoryDir)
$nextPrdSection = Get-NextPrdSection -Path $PrdFile
$nextReqId = Get-NextReqId -Path $PrdFile
$nextFeatureNumber = Get-NextFeatureNumber -Path $PrdFile

if ($Json) {
  Write-Output (@{ REPO_ROOT=$RepoRoot; PDR_DRAFTS_DIR=$PdrDraftsDir; PDR_MEMORY_DIR=$PdrMemoryDir; PRD_FILE=$PrdFile; SECTIONS_DIR=$SectionsDir; STATE_FILE=$StateFile; accepted_count=$acceptedCount; next_pdr=$nextPdr; next_prd_section=$nextPrdSection; next_req_id=$nextReqId; next_feature_number=$nextFeatureNumber } | ConvertTo-Json)
} else {
  Write-Output "[INFO] product-implement setup"
  Write-Output "  Accepted PDRs: $acceptedCount"
  Write-Output "  PRD_FILE: $PrdFile"
  Write-Output "  SECTIONS_DIR: $SectionsDir"
  Write-Output "  Next PDR slot: PDR-$nextPdr"
  Write-Output "  Next PRD section: $nextPrdSection"
  Write-Output "  Next REQ id: REQ-$nextReqId"
  Write-Output "  Next feature row: $nextFeatureNumber"
}
