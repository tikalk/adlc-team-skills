# pdr-lib.ps1 — Shared PDR lifecycle library for adlc-skills product-* skills (PowerShell twin of pdr-lib.sh)
#
# Mirrors the bash pdr-lib.sh so that the PDR side has the same structural
# robustness on Windows as on Unix: script-driven index generation, atomic move
# promotion, and a frontmatter-primary + heading-fallback parser that handles
# both legacy H2 (## Status) and current H3 (### Status) metadata.
#
# Usage:
#   . .\pdr-lib.ps1                        # load functions
#   Generate-PdrIndex memory              # regenerate .adlc/memory/pdr/pdr.md
#   Generate-PdrIndex drafts               # regenerate .adlc/drafts/pdr/pdr.md
#   Move-Pdr 020 drafts memory             # atomically move PDR-020 drafts→memory
#   Migrate-PdrToFrontmatter .adlc\memory\pdr\PDR-001.md   # one-time legacy migration
$ErrorActionPreference = "Stop"

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
        if ($line -match '^#+\s*PDR-\d+:\s*(.*)$') {
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
    $indexFile = Join-Path $pdrDir "pdr.md"
    if (-not (Test-Path $pdrDir)) { return }

    $header = "# Product Decision Records"
    if ($Scope -eq "memory") {
        $header += " (Memory)`n`n> Auto-generated by /product-implement. Accepted PDRs only.`n> Source: .adlc/$Scope/pdr/PDR-*.md"
    } else {
        $header += " (Drafts)`n`n> Auto-generated by /product-clarify. Proposed PDRs only.`n> Source: .adlc/$Scope/pdr/PDR-*.md"
    }
    $header += "`n`n## PDR Index`n`n| ID | Feature-Area | Category | Status | Date | Owner | Title |`n|----|--------------|----------|--------|------|-------|-------|`n"

    $body = ""
    $warnings = @()
    $files = Get-ChildItem -Path $pdrDir -Filter 'PDR-*.md' | Sort-Object { [int]($_.BaseName -replace 'PDR-','') }
    foreach ($f in $files) {
        $id = ($f.BaseName -replace 'PDR-','')
        $paddedId = '{0:D3}' -f [int]$id

        $title = Parse-PdrTitle -File $f.FullName
        $status = Parse-PdrField -File $f.FullName -Field "status"
        $date = Parse-PdrField -File $f.FullName -Field "date"
        $owner = Parse-PdrField -File $f.FullName -Field "owner"
        $category = Parse-PdrField -File $f.FullName -Field "category"
        $featureArea = Parse-PdrField -File $f.FullName -Field "feature-area"

        if (-not $status) { $status = "Unknown"; $warnings += "PDR-$paddedId: Status" }
        if (-not $date) { $date = "YYYY-MM-DD"; $warnings += "PDR-$paddedId: Date" }
        if (-not $owner) { $owner = "Unknown"; $warnings += "PDR-$paddedId: Owner" }
        if (-not $category) { $category = "Unknown"; $warnings += "PDR-$paddedId: Category" }
        if (-not $featureArea) { $featureArea = "system"; $warnings += "PDR-$paddedId: Feature-Area" }
        if (-not $title) { $title = "PDR-$paddedId"; $warnings += "PDR-$paddedId: Title" }

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
    $numericId = ($PdrId -replace '[^0-9]','')
    $paddedId = '{0:D3}' -f [int]$numericId
    $fromDir = Join-Path $REPO_ROOT ".adlc/$FromScope/pdr"
    $toDir = Join-Path $REPO_ROOT ".adlc/$ToScope/pdr"
    New-Item -ItemType Directory -Force -Path $toDir | Out-Null
    $srcFile = Join-Path $fromDir "PDR-$paddedId.md"
    $dstFile = Join-Path $toDir "PDR-$paddedId.md"
    if (-not (Test-Path $srcFile)) { Write-Warning "Move-Pdr: source not found: $srcFile"; return $false }
    Move-Item -Path $srcFile -Destination $dstFile -Force
    if (Test-Path $srcFile) { Write-Error "Move-Pdr: duplicate detected — PDR-$paddedId still in $FromScope after move"; return $false }
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
