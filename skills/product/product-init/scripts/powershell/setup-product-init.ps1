# product-init setup script (PowerShell)
# Self-contained — resolves paths, detects feature areas, finds next PDR slug

param(
    [switch]$Json
)

$ErrorActionPreference = "Stop"

# Layout roots (.adlc/ machine pipeline; docs/adlc/ human-facing deliverables)
$ADLC_DIR = if ($env:ADLC_DIR) { $env:ADLC_DIR } else { ".adlc" }
$DOCS_ADLC_DIR = if ($env:DOCS_ADLC_DIR) { $env:DOCS_ADLC_DIR } else { "docs/adlc" }
$DOCS_ADLC_MEMORY = if ($env:DOCS_ADLC_MEMORY) { $env:DOCS_ADLC_MEMORY } else { "docs/adlc/memory" }
$DOCS_ADLC_PRODUCT = if ($env:DOCS_ADLC_PRODUCT) { $env:DOCS_ADLC_PRODUCT } else { "docs/adlc/product" }
$DOCS_ADLC_ARCHITECT = if ($env:DOCS_ADLC_ARCHITECT) { $env:DOCS_ADLC_ARCHITECT } else { "docs/adlc/architect" }
$ADLC_DRAFTS = if ($env:ADLC_DRAFTS) { $env:ADLC_DRAFTS } else { ".adlc/drafts" }

$RepoRoot = $(git rev-parse --show-toplevel 2>$null)
if (-not $RepoRoot) { $RepoRoot = Get-Location }

$PdrDraftsDir = Join-Path $RepoRoot ".adlc/drafts/pdr"
$PrdFile = Join-Path $RepoRoot "docs/adlc/product/PRD.md"

New-Item -ItemType Directory -Force -Path $PdrDraftsDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $RepoRoot ".adlc/product") | Out-Null

function Detect-FeatureAreas {
    $areas = @()
    $dir = $RepoRoot

    foreach ($pattern in @('src','features','modules','apps','packages')) {
        $path = Join-Path $dir $pattern
        if (Test-Path $path -PathType Container) {
            Get-ChildItem -Path $path -Directory | ForEach-Object {
                $name = $_.Name
                $skip = @('utils','common','lib','shared','core','test','tests','__tests__')
                if ($skip -notcontains $name) { $areas += $name }
            }
        }
    }

    foreach ($compose in @('docker-compose.yml','docker-compose.yaml')) {
        $cpath = Join-Path $dir $compose
        if (Test-Path $cpath) {
            Get-Content $cpath | ForEach-Object {
                if ($_ -match '^\s*([a-zA-Z0-9_-]+):\s*$') {
                    $svc = $matches[1]
                    $skip = @('version','services','networks','volumes')
                    if ($skip -notcontains $svc) { $areas += $svc }
                }
            }
        }
    }

    $unique = $areas | Sort-Object -Unique
    if ($unique.Count -eq 0) { @('Product') } else { $unique }
}

# ID allocation: slugify(title) + collision check.
# Rules: lowercase, ASCII-fold, non-alnum -> -, collapse -, trim -, max 60 chars.
function Get-Slugify {
    param([string]$Title)
    if ([string]::IsNullOrWhiteSpace($Title)) {
        throw "Error: slugified title is empty"
    }

    # 1. Lowercase, 2. ASCII-fold, 3. Sanitize, 4. Collapse, 5. Trim, 6. Truncate
    $slug = $Title.ToLower()

    # ASCII-fold (Normalize FormD separates accents, then we filter them out)
    $normalized = $slug.Normalize([System.Text.NormalizationForm]::FormD)
    $sb = New-Object System.Text.StringBuilder
    foreach ($c in $normalized.ToCharArray()) {
        $category = [System.Globalization.CharUnicodeInfo]::GetUnicodeCategory($c)
        if ($category -ne [System.Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$sb.Append($c)
        }
    }
    $slug = $sb.ToString()

    # Sanitize & Collapse
    $slug = [regex]::Replace($slug, "[^a-z0-9]", "-")
    $slug = [regex]::Replace($slug, "-{2,}", "-")

    # Trim
    $slug = $slug.Trim("-")

    # Truncate
    if ($slug.Length -gt 60) {
        $slug = $slug.Substring(0, 60)
    }

    if ([string]::IsNullOrWhiteSpace($slug)) {
        throw "Error: slugified title is empty"
    }
    return $slug
}

# Get-MintPdrSlug TITLE [ROOT] - the next free PDR slug.
# Slugify title and append -2, -3 on collision across drafts AND memory.
function Get-MintPdrSlug {
    param([string]$Title, [string]$Root = $RepoRoot)
    $slug = Get-Slugify -Title $Title
    $candidate = $slug
    $count = 1

    $docsBase = $DOCS_ADLC_MEMORY
    if (-not $docsBase) { $docsBase = "docs/adlc/memory" }

    while ($true) {
        $exists = $false
        foreach ($dir in @((Join-Path $Root ".adlc/drafts/pdr"), 
                           (Join-Path $Root (Join-Path $docsBase "pdr")),
                           (Join-Path $Root ".adlc/memory/pdr"))) {
            if (Test-Path (Join-Path $dir "PDR-$candidate.md")) {
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

$featureAreas = Detect-FeatureAreas
$idAllocation = "slug"
$pdrCount = if (Test-Path $PdrDraftsDir) { (Get-ChildItem -Path $PdrDraftsDir -Filter 'PDR-*.md').Count } else { 0 }

$faJson = ($featureAreas | ForEach-Object {
    $id = $_.ToLower() -replace ' ','-'
    '{"id":"' + $id + '","name":"' + $_ + '"}'
}) -join ','

if ($Json) {
    Write-Output (@{
        REPO_ROOT = $RepoRoot
        PDR_DRAFTS_DIR = $PdrDraftsDir
        PRD_FILE = $PrdFile
        feature_areas = "[$faJson]"
        id_allocation = $idAllocation
        pdr_count = $pdrCount
    } | ConvertTo-Json -Depth 3)
} else {
    Write-Output "[INFO] product-init setup"
    Write-Output "  REPO_ROOT: $RepoRoot"
    Write-Output "  PDR_DRAFTS_DIR: $PdrDraftsDir"
    Write-Output "  ID allocation: PDR-{slug}"
    Write-Output "  Feature areas:"
    $featureAreas | ForEach-Object { Write-Output "    - $_" }
}
