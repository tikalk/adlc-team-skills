# product-init setup script (PowerShell)
# Self-contained — resolves paths, detects feature areas, finds next PDR number

param(
    [switch]$Json
)

$ErrorActionPreference = "Stop"

# shared layout constants (single definition in paths.ps1).
$AdlcPathsPs1 = "$PSScriptRoot/../../../../team/workspace/scripts/powershell/paths.ps1"
if (-not (Test-Path $AdlcPathsPs1)) {
    $AdlcPathsPs1 = "$PSScriptRoot/../../../workspace/scripts/powershell/paths.ps1"
}
if (Test-Path $AdlcPathsPs1) { . $AdlcPathsPs1 }

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

# Ledger slot allocation lives in pdr-lib.ps1 (Get-NextRecordNumber): leading
# digits of the filename stem, max across drafts AND published memory. This
# script previously carried its own copy, which silently skipped stemmed
# records (PDR-002-amendment-2.md) and scanned drafts alone.
$PdrLibPs1 = "$PSScriptRoot/../../../product-clarify/scripts/powershell/pdr-lib.ps1"
if (-not (Test-Path $PdrLibPs1)) {
    $PdrLibPs1 = "$PSScriptRoot/../product-clarify/pdr-lib.ps1"
}
if (-not (Test-Path $PdrLibPs1)) {
    Write-Error "pdr-lib.ps1 not loaded - install the product-clarify skill: adlc-cli skills add tikalk/adlc-team-skills --skill product-clarify"
    exit 1
}
. $PdrLibPs1

$featureAreas = Detect-FeatureAreas
$nextPdr = Get-NextRecordNumber -Prefix 'PDR' -Dirs @(
    $PdrDraftsDir,
    (Join-Path $RepoRoot "docs/adlc/memory/pdr")
)
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
        next_pdr = $nextPdr
        pdr_count = $pdrCount
    } | ConvertTo-Json -Depth 3)
} else {
    Write-Output "[INFO] product-init setup"
    Write-Output "  REPO_ROOT: $RepoRoot"
    Write-Output "  PDR_DRAFTS_DIR: $PdrDraftsDir"
    Write-Output "  Next PDR: PDR-$nextPdr"
    Write-Output "  Feature areas:"
    $featureAreas | ForEach-Object { Write-Output "    - $_" }
}
