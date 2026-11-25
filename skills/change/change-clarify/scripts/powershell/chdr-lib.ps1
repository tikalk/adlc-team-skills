# chdr-lib.ps1 — Shared ChDR lifecycle library for adlc-skills change-* skills (PowerShell twin of chdr-lib.sh)
#
# Mirrors the bash chdr-lib.sh so that the ChDR side has the same structural
# robustness on Windows as on Unix: script-driven index generation, atomic move
# promotion, and slug-based ID allocation.
#
# Usage:
#   . .\chdr-lib.ps1                        # load functions
#

$ErrorActionPreference = "Stop"

# Layout roots (.adlc/ machine pipeline; docs/adlc/ human-facing deliverables)
$ADLC_DIR = if ($env:ADLC_DIR) { $env:ADLC_DIR } else { ".adlc" }
$DOCS_ADLC_DIR = if ($env:DOCS_ADLC_DIR) { $env:DOCS_ADLC_DIR } else { "docs/adlc" }
$DOCS_ADLC_MEMORY = if ($env:DOCS_ADLC_MEMORY) { $env:DOCS_ADLC_MEMORY } else { "docs/adlc/memory" }
$DOCS_ADLC_PRODUCT = if ($env:DOCS_ADLC_PRODUCT) { $env:DOCS_ADLC_PRODUCT } else { "docs/adlc/product" }
$DOCS_ADLC_ARCHITECT = if ($env:DOCS_ADLC_ARCHITECT) { $env:DOCS_ADLC_ARCHITECT } else { "docs/adlc/architect" }
$ADLC_DRAFTS = if ($env:ADLC_DRAFTS) { $env:ADLC_DRAFTS } else { ".adlc/drafts" }

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
# Decision-record store resolution (ADR-514)
# ============================================================================

function Test-MemoryRootMarker {
    param([string]$Root)
    foreach ($mem in @("docs/adlc/memory", ".adlc/memory")) {
        if (-not (Test-Path (Join-Path $Root $mem))) { continue }
        foreach ($fam in @("adr", "pdr", "chdr")) {
            if ((Test-Path (Join-Path $Root "$mem/$fam")) -or 
                (Test-Path (Join-Path $Root "$mem/$fam.md")) -or 
                (Test-Path (Join-Path $Root "$mem/$fam/$fam.md"))) {
                return $true
            }
        }
    }
    return $false
}

function Test-WorkspaceRootAbove {
    param([string]$Dir)
    $up = Split-Path $Dir -Parent
    while ($up -and $up -ne [System.IO.Path]::GetPathRoot($up)) {
        if ((Test-Path (Join-Path $up ".gitmodules")) -or (Test-Path (Join-Path $up ".adlc/workspace.yml"))) {
            return $true
        }
        $up = Split-Path $up -Parent
    }
    return $false
}

function Resolve-MemoryRoot {
    $dir = (Get-Location).Path
    $toplevel = (git -C $dir rev-parse --show-toplevel 2>$null)
    while ($dir -ne [System.IO.Path]::GetPathRoot($dir)) {
        if (Test-MemoryRootMarker -Root $dir) {
            return $dir
        }
        if ((Test-Path (Join-Path $dir ".gitmodules")) -or (Test-Path (Join-Path $dir ".adlc/workspace.yml"))) {
            return $dir
        }
        if ($toplevel -and ($dir -eq $toplevel) -and -not (Test-WorkspaceRootAbove -Dir $dir)) {
            return $dir
        }
        $dir = Split-Path $dir -Parent
    }
    if ($toplevel) { return $toplevel }
    return (Get-Location).Path
}

function Ensure-MemoryStore {
    param([string]$Root, [string]$Family)
    $store = Join-Path $Root "$DOCS_ADLC_MEMORY/$Family"
    if (-not (Test-Path $store)) {
        New-Item -ItemType Directory -Path $store -Force | Out-Null
        $name = Split-Path $Root -Leaf
        [Console]::Error.WriteLine("No decision-record store found — initialized $store; commit it to opt $name into repo-scoped memory.")
    }
}

if (-not $MEMORY_ROOT) { $MEMORY_ROOT = Resolve-MemoryRoot }

# ============================================================================
# YAML frontmatter parser
# ============================================================================
function Parse-FrontmatterField {
    param([string]$File, [string]$Field)
    if (-not (Test-Path $File)) { return "" }
    $lines = Get-Content $File
    $inFm = $false
    foreach ($line in $lines) {
        if ($line -match '^---\s*$') {
            if ($inFm) { break }
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
# Heading-based fallback parser
# ============================================================================
function Parse-ChdrHeadingField {
    param([string]$File, [string]$Field)
    if (-not (Test-Path $File)) { return "" }
    $lines = Get-Content $File
    $found = $false
    foreach ($line in $lines) {
        if (-not $found) {
            if ($line -match "^#+\s*$Field\s*$") { $found = $true; continue }
        } else {
            if ($line -match '^#+') { break }
            if ($line.Trim() -ne "") {
                $val = $line -replace '\*\*', ''
                return $val.Trim()
            }
        }
    }
    return ""
}

function Parse-ChdrHeadingTitle {
    param([string]$File)
    if (-not (Test-Path $File)) { return "" }
    $lines = Get-Content $File
    foreach ($line in $lines) {
        if ($line -match '^#+\s*ChDR-[0-9A-Za-z-]+:\s*(.*)$') {
            return $Matches[1].Trim()
        }
    }
    return ""
}

# ============================================================================
# Combined parsers
# ============================================================================
function Parse-ChdrField {
    param([string]$File, [string]$Field)
    $fmField = $Field.ToLower()
    $val = Parse-FrontmatterField -File $File -Field $fmField
    if ($val) { return $val }
    $val = Parse-ChdrHeadingField -File $File -Field $Field
    return $val
}

function Parse-ChdrTitle {
    param([string]$File)
    $val = Parse-FrontmatterField -File $File -Field "title"
    if ($val) { return $val }
    $val = Parse-ChdrHeadingTitle -File $File
    if ($val) { return $val }
    $val = Parse-FmTitle -File $File
    return $val
}

# ============================================================================
# Slugification Rules
# ============================================================================

function Get-Slugify {
    param([string]$Title)
    if ([string]::IsNullOrWhiteSpace($Title)) {
        throw "Error: slugified title is empty"
    }

    $slug = $Title.ToLower()
    $normalized = $slug.Normalize([System.Text.NormalizationForm]::FormD)
    $sb = New-Object System.Text.StringBuilder
    foreach ($c in $normalized.ToCharArray()) {
        $category = [System.Globalization.CharUnicodeInfo]::GetUnicodeCategory($c)
        if ($category -ne [System.Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$sb.Append($c)
        }
    }
    $slug = $sb.ToString()
    $slug = [regex]::Replace($slug, "[^a-z0-9]", "-")
    $slug = [regex]::Replace($slug, "-{2,}", "-")
    $slug = $slug.Trim("-")
    if ($slug.Length -gt 60) { $slug = $slug.Substring(0, 60) }

    if ([string]::IsNullOrWhiteSpace($slug)) {
        throw "Error: slugified title is empty"
    }
    return $slug
}

function Get-MintChdrSlug {
    param([string]$Title, [string]$Root = (Get-ProjectRoot))
    $slug = Get-Slugify -Title $Title
    $candidate = $slug
    $count = 1

    while ($true) {
        $exists = $false
        foreach ($dir in @((Join-Path $Root "$ADLC_DRAFTS/chdr"), 
                           (Join-Path $MEMORY_ROOT "$DOCS_ADLC_MEMORY/chdr"),
                           (Join-Path $MEMORY_ROOT ".adlc/memory/chdr"))) {
            if (Test-Path (Join-Path $dir "ChDR-$candidate.md")) {
                $exists = $true
                break
            }
        }

        if (-not $exists) {
            return $candidate
        }

        $count++
        $candidate = "$slug-$count"
    }
}

# ============================================================================
# Lookup and Move
# ============================================================================

function Get-ChDRById {
    param([string]$ChDRId, [string]$Scope = "drafts")
    if ($ChDRId -like 'ChDR-*') { $ChDRId = $ChDRId.Substring(5) }
    if ($ChDRId -match '[\\/]|^\.') { return $null }

    $searchDirs = @(Join-Path $REPO_ROOT ".adlc/$Scope/chdr")
    if ($Scope -eq "memory") {
        $searchDirs = @((Join-Path $MEMORY_ROOT "$DOCS_ADLC_MEMORY/chdr"), (Join-Path $MEMORY_ROOT ".adlc/memory/chdr"))
    }

    foreach ($dir in $searchDirs) {
        $file = Join-Path $dir "ChDR-$ChDRId.md"
        if (Test-Path $file) {
            return Get-Content $file -Raw
        }
    }
    return $null
}

function Move-ChDR {
    param([string]$ChDRId, [string]$FromScope = "drafts", [string]$ToScope = "memory")
    if ($ChDRId -like 'ChDR-*') { $ChDRId = $ChDRId.Substring(5) }
    if ($ChDRId -match '[\\/]|^\.') { Write-Error "Move-ChDR: invalid id: $ChDRId"; return $false }
    
    $fromDir = Join-Path $REPO_ROOT ".adlc/$FromScope/chdr"
    $toDir = Join-Path $REPO_ROOT ".adlc/$ToScope/chdr"
    if ($ToScope -eq "memory") {
        $toDir = Join-Path $MEMORY_ROOT "$DOCS_ADLC_MEMORY/chdr"
        Ensure-MemoryStore -Root $MEMORY_ROOT -Family chdr
    }
    
    New-Item -ItemType Directory -Force -Path $toDir | Out-Null
    $srcFile = Join-Path $fromDir "ChDR-$ChDRId.md"
    $dstFile = Join-Path $toDir (Split-Path $srcFile -Leaf)
    if (-not (Test-Path $srcFile)) { Write-Warning "Move-ChDR: source not found: $srcFile"; return $false }
    Move-Item -Path $srcFile -Destination $dstFile -Force
    if (Test-Path $srcFile) { Write-Error "Move-ChDR: duplicate detected — still in $FromScope after move"; return $false }
    
    if (Get-Command Generate-ChDRIndex -ErrorAction SilentlyContinue) {
        Generate-ChDRIndex -Scope $FromScope
        Generate-ChDRIndex -Scope $ToScope
    }
    return $true
}

# ============================================================================
# Index generation
# ============================================================================

function Generate-ChDRIndex {
    param([string]$Scope = "drafts")
    $chdrDir = Join-Path $REPO_ROOT ".adlc/$Scope/chdr"
    $scanDirs = @($chdrDir)
    if ($Scope -eq "memory") {
        $docsChdrDir = Join-Path $MEMORY_ROOT "$DOCS_ADLC_MEMORY/chdr"
        if (@(Get-ChildItem -Path $docsChdrDir -Filter 'ChDR-*.md' -ErrorAction SilentlyContinue).Count -gt 0) {
            $scanDirs = @($docsChdrDir, $chdrDir)
        }
    }
    $indexFile = Join-Path $scanDirs[0] "chdr.md"
    if (-not (Test-Path $scanDirs[0])) { return }

    $indexRelDir = $scanDirs[0].Replace($REPO_ROOT, "").TrimStart("\").TrimStart("/")
    $header = "# Change Decision Records"
    if ($Scope -eq "memory") {
        $header += " (Memory)`n`n> Auto-generated by /change-publish. Accepted ChDRs only.`n> Source: $indexRelDir/ChDR-*.md"
    } else {
        $header += " (Drafts)`n`n> Auto-generated by /change-clarify. All ChDRs.`n> Source: $indexRelDir/ChDR-*.md"
    }
    $header += "`n`n## ChDR Index`n`n| ID | Status | Date | Title |`n|----|--------|------|-------|`n"

    $body = ""
    $existingDirs = @($scanDirs | Where-Object { Test-Path $_ })
    $files = @()
    if ($existingDirs.Count -gt 0) {
        $files = Get-ChildItem -Path $existingDirs -Filter 'ChDR-*.md' | Sort-Object BaseName
    }
    foreach ($f in $files) {
        $id = ($f.BaseName -replace '^ChDR-','')
        $title = Parse-ChdrTitle -File $f.FullName
        $status = Parse-ChdrField -File $f.FullName -Field "status"
        $date = Parse-ChdrField -File $f.FullName -Field "date"

        if ($status) { $status = (Get-Culture).TextInfo.ToTitleCase($status.ToLower()) }
        else { $status = "Unknown" }
        if (-not $date) { $date = "YYYY-MM-DD" }
        if (-not $title) { $title = "ChDR-$id" }

        $body += "| ChDR-$id | $status | $date | $title |`n"
    }

    $content = $header + $body
    Set-Content -Path $indexFile -Value $content -NoNewline
}
