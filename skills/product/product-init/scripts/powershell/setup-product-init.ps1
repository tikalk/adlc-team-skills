# product-init setup script (PowerShell)
# Self-contained — resolves paths, detects feature areas, finds next PDR number

param(
    [switch]$Json
)

$ErrorActionPreference = "Stop"

function Resolve-ProjectRoot {
    $dir = (Get-Location).Path
    $root = [System.IO.Path]::GetPathRoot($dir)
    while ($dir -and $dir -ne $root) {
        if (Test-Path (Join-Path $dir ".adlc") -PathType Container) {
            return $dir
        }
        $dir = Split-Path $dir -Parent
    }
    $gitRoot = git rev-parse --show-toplevel 2>$null
    if ($gitRoot) { return $gitRoot }
    return (Get-Location).Path
}

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

$ProjectRoot = Resolve-ProjectRoot
$RepoRoot = $ProjectRoot

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
$PrdFile = Join-Path $SddRoot "PRD.md"

New-Item -ItemType Directory -Force -Path $PdrDraftsDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $SddRoot ".adlc/product") | Out-Null

function Detect-FeatureAreas {
    $areas = @()
    $dir = $ProjectRoot

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

function Get-NextPdrNumber {
    $max = 0
    if (Test-Path $PdrDraftsDir) {
        Get-ChildItem -Path $PdrDraftsDir -Filter 'PDR-*.md' | ForEach-Object {
            $num = $_.Name -replace 'PDR-','' -replace '\.md',''
            if ($num -match '^\d+$') {
                $n = [int]$num
                if ($n -gt $max) { $max = $n }
            }
        }
    }
    '{0:D3}' -f ($max + 1)
}

$featureAreas = Detect-FeatureAreas
$nextPdr = Get-NextPdrNumber
$pdrCount = if (Test-Path $PdrDraftsDir) { (Get-ChildItem -Path $PdrDraftsDir -Filter 'PDR-*.md').Count } else { 0 }

$faJson = ($featureAreas | ForEach-Object {
    $id = $_.ToLower() -replace ' ','-'
    '{"id":"' + $id + '","name":"' + $_ + '"}'
}) -join ','

if ($Json) {
    Write-Output (@{
        REPO_ROOT = $RepoRoot
        SDD_DOCS_LOCATION = $SddDocsLocation
        SDD_ROOT = $SddRoot
        PDR_DRAFTS_DIR = $PdrDraftsDir
        PRD_FILE = $PrdFile
        feature_areas = "[$faJson]"
        next_pdr = $nextPdr
        pdr_count = $pdrCount
    } | ConvertTo-Json -Depth 3)
} else {
    Write-Output "[INFO] product-init setup"
    Write-Output "  REPO_ROOT: $RepoRoot"
    Write-Output "  SDD_ROOT: $SddRoot"
    Write-Output "  PDR_DRAFTS_DIR: $PdrDraftsDir"
    Write-Output "  Next PDR: PDR-$nextPdr"
    Write-Output "  Feature areas:"
    $featureAreas | ForEach-Object { Write-Output "    - $_" }
}
