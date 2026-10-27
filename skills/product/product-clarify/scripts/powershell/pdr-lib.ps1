# pdr-lib.ps1 — Shared PDR lifecycle library for adlc-skills product-* skills (PowerShell twin of pdr-lib.sh)
#
# Mirrors the bash pdr-lib.sh so that the PDR side has the same structural
# robustness on Windows as on Unix: script-driven index generation, atomic move
# promotion, and a frontmatter-primary + heading-fallback parser that handles
# both legacy H2 (## Status) and current H3 (### Status) metadata.
#
# Usage:
#   . .\pdr-lib.ps1                        # load functions
# note: memory-scope readers dual-read the legacy .adlc/memory root
# (back-compat); Generate-PdrIndex memory additionally indexes
# docs/adlc/memory/pdr/ (the canonical promotion target) and writes the index
# there whenever that root holds records; Move-Pdr promotes INTO
# docs/adlc/memory/pdr/ (R8: writers write the new path only).
#
#   Generate-PdrIndex memory              # regenerate the memory pdr.md (docs root preferred)
#   Generate-PdrIndex drafts               # regenerate .adlc/drafts/pdr/pdr.md
#   Move-Pdr 020 drafts memory             # atomically move the planning-mode decision drafts→memory
#   Migrate-PdrToFrontmatter .adlc\memory\pdr\PDR-001.md   # one-time legacy migration
$ErrorActionPreference = "Stop"

# shared layout constants (single definition in paths.ps1).
$PdrLibPathsPs1 = "$PSScriptRoot/../../../../team/workspace/scripts/powershell/paths.ps1"
if (-not (Test-Path $PdrLibPathsPs1)) {
    $PdrLibPathsPs1 = "$PSScriptRoot/../../../workspace/scripts/powershell/paths.ps1"
}
if (Test-Path $PdrLibPathsPs1) { . $PdrLibPathsPs1 }

# ============================================================================
# Project root resolution
# ============================================================================
function Get-ProjectRoot {
    $dir = (Get-Location).Path
    while ($dir -ne [System.IO.Path]::GetPathRoot($dir)) {
        if ((Test-Path (Join-Path $dir ".adlc")) -or (Test-Path (Join-Path $dir ".git"))) {
            return $dir
        }
        $dir = Split-Path $dir -Parent
    }
    return (Get-Location).Path
}

if (-not $REPO_ROOT) { $REPO_ROOT = Get-ProjectRoot }

# ============================================================================
# YAML frontmatter parser
# ============================================================================
function Parse-FrontmatterField {
    param([string]$File, [string]$Field)
    if (-not (Test-Path $File)) { return "" }
    $lines = Get-Content $File
    $inFm = $false
    $fmEnd = $false
    foreach ($line in $lines) {
        if ($line -match '^---\s*$') {
            if ($inFm) { $script:fmEnd = $true; break }
            $inFm = $true; continue
        }
        if ($inFm -and ($line -match "^\s*$Field\s*:\s*(.*)$")) {
            $val = $Matches[1]
            $val = $val -replace '\s+#.*$', ''
            $val = $val -replace '^["'']|[''"]$', ''
            $val = $val -replace '^\[|\]$', ''
            $val = $val.Trim()
            return $val
        }
    }
    return ""
}

function Parse-FmTitle {
    param([string]$File)
    if (-not (Test-Path $File)) { return "" }
    $lines = Get-Content $File
    $inFm = $false
    $fmCount = 0
    foreach ($line in $lines) {
        if ($line -match '^---\s*$') { $fmCount++; continue }
        if ($fmCount -ge 2 -and $line -match '^#\s+(.*)$') {
            return $Matches[1].Trim()
        }
    }
    return ""
}

# ============================================================================
# Heading-based fallback parser (handles legacy H2 and current H3)
# ============================================================================
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

function Parse-PdrHeadingTitle {
    param([string]$File)
    if (-not (Test-Path $File)) { return "" }
    $lines = Get-Content $File
    foreach ($line in $lines) {
        # Suffixed variants (e.g. PDR-<id>-amendment-2) must match, not just bare numerics.
        if ($line -match '^#+\s*PDR-[0-9A-Za-z-]+:\s*(.*)$') {
            return $Matches[1].Trim()
        }
    }
    return ""
}

# ============================================================================
# Combined parsers (frontmatter primary, heading fallback)
# ============================================================================
function Parse-PdrField {
    param([string]$File, [string]$Field)
    $fmField = $Field.ToLower()
    $val = Parse-FrontmatterField -File $File -Field $fmField
    if ($val) { return $val }
    $titleField = ($Field -split '-' | ForEach-Object { $_.Substring(0,1).ToUpper() + $_.Substring(1).ToLower() }) -join '-'
    $val = Parse-PdrHeadingField -File $File -Field $titleField
    if ($val) { return $val }
    $val = Parse-PdrHeadingField -File $File -Field $Field
    return $val
}

function Parse-PdrTitle {
    param([string]$File)
    $val = Parse-FrontmatterField -File $File -Field "title"
    if ($val) { return $val }
    $val = Parse-PdrHeadingTitle -File $File
    if ($val) { return $val }
    $val = Parse-FmTitle -File $File
    return $val
}

# ============================================================================
# Index generation
# ============================================================================
function Generate-PdrIndex {
    param([string]$Scope = "drafts")
    $pdrDir = Join-Path $REPO_ROOT ".adlc/$Scope/pdr"

    # dual-read: the memory scope indexes the canonical
    # docs/adlc/memory root plus any records still in the legacy .adlc/memory
    # root (migration stragglers). The index is written where the records
    # live — docs preferred whenever it holds any record, else legacy.
    $scanDirs = @($pdrDir)
    if ($Scope -eq "memory") {
        $docsPdrDir = Join-Path $REPO_ROOT "docs/adlc/memory/pdr"
        if (@(Get-ChildItem -Path $docsPdrDir -Filter 'PDR-*.md' -ErrorAction SilentlyContinue).Count -gt 0) {
            $scanDirs = @($docsPdrDir, $pdrDir)
        }
    }
    $indexFile = Join-Path $scanDirs[0] "pdr.md"
    if (-not (Test-Path $scanDirs[0])) { return }

    # publication closure: the Source line must name the directory
    # this index file actually lives in (docs for migrated repos).
    $indexRelDir = $scanDirs[0].Replace("$REPO_ROOT/", "").Replace("$REPO_ROOT\", "")
    $header = "# Product Decision Records"
    if ($Scope -eq "memory") {
        $header += " (Memory)`n`n> Auto-generated by /product-implement. Accepted PDRs only.`n> Source: $indexRelDir/PDR-*.md"
    } else {
        $header += " (Drafts)`n`n> Auto-generated by /product-clarify. Proposed PDRs only.`n> Source: $indexRelDir/PDR-*.md"
    }
    $header += "`n`n## PDR Index`n`n| ID | Feature-Area | Category | Status | Date | Owner | Title |`n|----|--------------|----------|--------|------|-------|-------|`n"

    $body = ""
    $warnings = @()
    # Lexical BaseName sort (zero-padded repo names keep amendment-before-base order). IDs are stems verbatim.
    $files = Get-ChildItem -Path $scanDirs -Filter 'PDR-*.md' | Sort-Object BaseName
    foreach ($f in $files) {
        $id = ($f.BaseName -replace '^PDR-','')
        # Purely numeric stems keep the legacy zero-padded display; suffixed stems render verbatim.
        if ($id -match '^[0-9]+$') { $paddedId = '{0:D3}' -f [int]$id } else { $paddedId = $id }

        $title = Parse-PdrTitle -File $f.FullName
        $status = Parse-PdrField -File $f.FullName -Field "status"
        $date = Parse-PdrField -File $f.FullName -Field "date"
        $owner = Parse-PdrField -File $f.FullName -Field "owner"
        $category = Parse-PdrField -File $f.FullName -Field "category"
        $featureArea = Parse-PdrField -File $f.FullName -Field "feature-area"

        # ${paddedId} must stay brace-delimited: "$var:" in a double-quoted
        # string is a PowerShell ParserError ("Variable reference is not
        # valid"), and one such line made this whole file refuse to load.
        if (-not $status) { $status = "Unknown"; $warnings += "PDR-${paddedId}: Status" }
        if (-not $date) { $date = "YYYY-MM-DD"; $warnings += "PDR-${paddedId}: Date" }
        if (-not $owner) { $owner = "Unknown"; $warnings += "PDR-${paddedId}: Owner" }
        if (-not $category) { $category = "Unknown"; $warnings += "PDR-${paddedId}: Category" }
        if (-not $featureArea) { $featureArea = "system"; $warnings += "PDR-${paddedId}: Feature-Area" }
        if (-not $title) { $title = "PDR-${paddedId}"; $warnings += "PDR-${paddedId}: Title" }

        $body += "| PDR-$paddedId | $featureArea | $category | $status | $date | $owner | $title |`n"
    }

    $content = $header + $body
    Set-Content -Path $indexFile -Value $content -NoNewline

    if ($warnings.Count -gt 0) {
        Write-Warning "Generate-PdrIndex ($Scope): $($warnings.Count) blank metadata cell(s) found; defaults applied."
        $warnings | ForEach-Object { Write-Warning "  - $_" }
    }
}

# ============================================================================
# Atomic move
# ============================================================================
function Move-Pdr {
    param([string]$PdrId, [string]$FromScope = "drafts", [string]$ToScope = "memory")
    # Resolve exact stems first (PDR-<given>.md verbatim); numeric fallback
    # only for bare IDs. Never strip suffixes. Reject path separators.
    if ($PdrId -match '[\\/]|^\.') { Write-Error "Move-Pdr: invalid id: $PdrId"; return $false }
    $fromDir = Join-Path $REPO_ROOT ".adlc/$FromScope/pdr"
    $toDir = Join-Path $REPO_ROOT ".adlc/$ToScope/pdr"
    if ($ToScope -eq "memory") {
        # dual-read: promotion writers write the NEW path only.
        $toDir = Join-Path $REPO_ROOT "docs/adlc/memory/pdr"
    }
    New-Item -ItemType Directory -Force -Path $toDir | Out-Null
    $srcFile = Join-Path $fromDir "PDR-$PdrId.md"
    if ((-not (Test-Path $srcFile)) -and ($PdrId -match '^[0-9]+$')) {
        $paddedId = '{0:D3}' -f [int]$PdrId
        $srcFile = Join-Path $fromDir "PDR-$paddedId.md"
    }
    $dstFile = Join-Path $toDir (Split-Path $srcFile -Leaf)
    if (-not (Test-Path $srcFile)) { Write-Warning "Move-Pdr: source not found: $srcFile"; return $false }
    Move-Item -Path $srcFile -Destination $dstFile -Force
    if (Test-Path $srcFile) { Write-Error "Move-Pdr: duplicate detected — still in $FromScope after move"; return $false }
    Generate-PdrIndex -Scope $FromScope
    Generate-PdrIndex -Scope $ToScope
    return $true
}

# ============================================================================
# One-time migration: heading-based metadata -> YAML frontmatter
# ============================================================================
function Migrate-PdrToFrontmatter {
    param([string]$File)
    if (-not (Test-Path $File)) { Write-Warning "Migrate: file not found: $File"; return $false }
    $firstLine = (Get-Content $File -TotalCount 1)
    if ($firstLine -match '^---\s*$') { return $false }

    $title = Parse-PdrHeadingTitle -File $File
    $status = Parse-PdrHeadingField -File $File -Field "Status"
    $date = Parse-PdrHeadingField -File $File -Field "Date"
    $owner = Parse-PdrHeadingField -File $File -Field "Owner"
    $category = Parse-PdrHeadingField -File $File -Field "Category"
    $featureArea = Parse-PdrHeadingField -File $File -Field "Feature-Area"
    if ($status) { $status = $status -replace '\*\*','' }
    if (-not $status) { $status = "Unknown" }
    if (-not $date) { $date = "YYYY-MM-DD" }
    if (-not $owner) { $owner = "Unknown" }
    if (-not $category) { $category = "Unknown" }
    if (-not $featureArea) { $featureArea = "system" }
    if (-not $title) { $title = "Untitled" }

    $fm = "---`nstatus: $status`ndate: $date`nowner: $owner`ncategory: $category`nfeature-area: $featureArea`ntitle: $title`n---`n"
    $body = Get-Content $File -Raw
    Set-Content -Path $File -Value ($fm + $body) -NoNewline
    return $true
}

function Migrate-PdrDir {
    param([string]$Dir)
    if (-not (Test-Path $Dir)) { Write-Warning "Migrate-PdrDir: dir not found: $Dir"; return }
    $count = 0; $skipped = 0
    Get-ChildItem -Path $Dir -Filter 'PDR-*.md' | ForEach-Object {
        $firstLine = (Get-Content $_.FullName -TotalCount 1)
        if ($firstLine -match '^---\s*$') { $skipped++ }
        else { if (Migrate-PdrToFrontmatter -File $_.FullName) { $count++ } }
    }
    Write-Output "[INFO] Migrate-PdrDir: migrated $count file(s), skipped $skipped (already had frontmatter)"
}

# ============================================================================
# Level-agnostic Accepted counter
# ============================================================================
function Count-PdrAccepted {
    param([string]$Dir)
    if (-not (Test-Path $Dir)) { return 0 }
    $count = 0
    Get-ChildItem -Path $Dir -Filter 'PDR-*.md' | ForEach-Object {
        $status = Parse-PdrField -File $_.FullName -Field "status"
        $status = ($status -replace '\*\*','').ToLower().Trim()
        if ($status -eq "accepted" -or $status -eq "completed") { $count++ }
    }
    return $count
}

###############################################################################
# Ledger slot allocation
###############################################################################

# Get-NextRecordNumber - the next free ledger slot for records named PREFIX-*.md.
#
# A record's number is the LEADING DIGITS of its filename stem:
# PDR-002-amendment-2.md is record 002. Suffixes are preserved and never
# arithmetically parsed -- the same rule Generate-PdrIndex pins in
# tests/unit/test_index_id_parsing.py.
#
# The maximum is taken across EVERY directory given. Scanning drafts alone
# reissues a slot that a published record still holds in docs/adlc/memory/.
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

###############################################################################
# Document-internal ledger slots (PRD.md)
###############################################################################
#
# Record ids are allocated by Get-NextRecordNumber above. PRD.md carries three
# further numbered slots: the delta SECTION number, the REQ id, and the Feature
# number. Each scan is deliberately OVER-inclusive -- an unused number is
# harmless, a reissued one collides.

function Get-NextPrdSection {
    param([string]$File)
    $max = 0
    if (Test-Path $File) {
        foreach ($line in (Get-Content $File)) {
            if ($line -cmatch '^## (\d+)\. ') {
                $n = [int]$Matches[1]
                if ($n -gt $max) { $max = $n }
            }
        }
    }
    return ($max + 1)
}

function Get-NextReqId {
    param([string]$File)
    $max = 0
    if (Test-Path $File) {
        foreach ($m in [regex]::Matches((Get-Content $File -Raw), 'REQ-(\d+)')) {
            $n = [int]$m.Groups[1].Value
            if ($n -gt $max) { $max = $n }
        }
    }
    return ($max + 1)
}

function Get-NextFeatureNumber {
    param([string]$File)
    $max = 0
    if (Test-Path $File) {
        foreach ($line in (Get-Content $File)) {
            if ($line -cmatch '^\|\s*(\d+)\s*\|') {
                $n = [int]$Matches[1]
                if ($n -gt $max) { $max = $n }
            }
        }
    }
    return ($max + 1)
}
