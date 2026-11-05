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

# ============================================================================
# Frontmatter + heading status parsers (vendored from product-clarify
# pdr-lib.ps1 per the scope rule: scripts stay skill-local, helpers are
# vendored, never sourced across skills; keep these copies in sync with
# product-clarify).
# ============================================================================
function Parse-FrontmatterField {
  param([string]$File, [string]$Field)
  if (-not (Test-Path $File)) { return "" }
  $lines = Get-Content $File
  $inFm = $false
  foreach ($line in $lines) {
    if ($line -match '^---\s*$') {
      if ($inFm) { break }
      $inFm = $true
      continue
    }
    if ($inFm -and ($line -match "^\s*$Field\s*:\s*(.*)$")) {
      $val = $Matches[1]
      $val = $val -replace '\s+#.*$', ''
      $val = $val -replace '^["'']|[''"]$', ''
      $val = $val -replace '^\[|\]$', ''
      return $val.Trim()
    }
  }
  return ""
}

function Parse-PdrHeadingField {
  param([string]$File, [string]$Field)
  if (-not (Test-Path $File)) { return "" }
  $lines = Get-Content $File
  $found = $false
  foreach ($line in $lines) {
    if (-not $found) {
      if ($line -match "^###+\s*$Field\s*$") { $found = $true; continue }
    } else {
      if ($line -match '^###+') { break }
      if ($line.Trim() -ne "") {
        $val = $line -replace '\*\*', ''
        return $val.Trim()
      }
    }
  }
  return ""
}

function Parse-PdrField {
  param([string]$File, [string]$Field)
  $fmField = $Field.ToLower()
  $val = Parse-FrontmatterField -File $File -Field $fmField
  if ($val) { return $val }
  $titleField = ($Field -split '-' | ForEach-Object { $_.Substring(0, 1).ToUpper() + $_.Substring(1).ToLower() }) -join '-'
  $val = Parse-PdrHeadingField -File $File -Field $titleField
  if ($val) { return $val }
  $val = Parse-PdrHeadingField -File $File -Field $Field
  return $val
}

$acceptedCount = 0
if (Test-Path $PdrDraftsDir) {
  # Accepted-PDR counter (uses the vendored frontmatter-primary +
  # heading-fallback status parser above: legacy H2 and current H3 shapes
  # count; frontmatter `status: accepted` counts; inline-bold and next-line
  # values count).
  Get-ChildItem -Path $PdrDraftsDir -Filter 'PDR-*.md' | ForEach-Object {
    $status = Parse-PdrField -File $_.FullName -Field "status"
    $status = ($status -replace '\*\*', '').ToLower().Trim()
    if ($status -eq "accepted" -or $status -eq "completed") { $acceptedCount++ }
  }
}

# Ledger slot allocation (vendored from product-clarify pdr-lib.ps1 per the
# scope rule: scripts stay skill-local, helpers are vendored, never sourced
# across skills). A record's number is the LEADING DIGITS of its filename
# stem; the maximum spans drafts AND published memory.
function Get-NextRecordNumber {
  param(
    [Parameter(Mandatory = $true)][string]$Prefix,
    [Parameter(Mandatory = $true)][string[]]$Dirs
  )
  $max = 0
  foreach ($dir in $Dirs) {
    if (-not (Test-Path -LiteralPath $dir)) { continue }
    foreach ($file in Get-ChildItem -LiteralPath $dir -Filter "$Prefix-*.md" -File -ErrorAction SilentlyContinue) {
      if ($file.BaseName -match ('^' + [regex]::Escape($Prefix) + '-(\d+)')) {
        $n = [int]$Matches[1]
        if ($n -gt $max) { $max = $n }
      }
    }
  }
  return ('{0:D3}' -f ($max + 1))
}

# The three document-internal PRD.md slots. Each scan is deliberately
# over-inclusive: an unused number is harmless, a reissued one collides.
function Get-NextPrdSection {
  param([string]$Path)
  $max = 0
  if (Test-Path -LiteralPath $Path) {
    foreach ($line in Get-Content -LiteralPath $Path) {
      if ($line -cmatch '^## (\d+)\. ') {
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
      if ($line -cmatch '^\|\s*(\d+)\s*\|') {
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
