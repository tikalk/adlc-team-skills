#!/usr/bin/env pwsh
# setup-change-publish.ps1 — Setup for change-publish (self-contained)
$ErrorActionPreference = "Stop"

# shared layout constants (single definition in paths.ps1).
$AdlcPathsPs1 = "$PSScriptRoot/../../../../team/workspace/scripts/powershell/paths.ps1"
if (-not (Test-Path $AdlcPathsPs1)) {
    $AdlcPathsPs1 = "$PSScriptRoot/../../../workspace/scripts/powershell/paths.ps1"
}
if (Test-Path $AdlcPathsPs1) { . $AdlcPathsPs1 }

function Resolve-ProjectRoot {
    $dir = $PSScriptRoot
    while ($dir -ne "") {
        if (Test-Path (Join-Path $dir ".adlc")) { return $dir }
        $parent = Split-Path $dir -Parent
        if ($parent -eq $dir) { break }
        $dir = $parent
    }
    $gitRoot = git rev-parse --show-toplevel 2>$null
    if ($gitRoot) { return $gitRoot }
    return (Get-Location).Path
}

$ProjectRoot = Resolve-ProjectRoot
$ChdrDraftsDir = Join-Path $projectRoot ".adlc/drafts/chdr"
#  published ChDRs live under docs/adlc/memory — promotion writes the
# new path only; legacy .adlc/memory/chdr stays read-compatible (dual-read).
$MemoryDir = Join-Path $projectRoot "docs/adlc/memory/chdr"
$MemoryIndex = Join-Path $projectRoot "docs/adlc/memory/chdr/chdr.md"
$LegacyMemoryDir = Join-Path $projectRoot ".adlc/memory/chdr"

if (-not (Test-Path $MemoryDir)) { New-Item -ItemType Directory -Path $MemoryDir -Force | Out-Null }

$AcceptedChdrs = @()
$AcceptedCount = 0
$PublishedCount = 0
$draftFiles = @(Get-ChildItem -Path $ChdrDraftsDir -Filter "ChDR-*.md" -ErrorAction SilentlyContinue)
foreach ($f in $draftFiles) {
    $content = Get-Content $f.FullName -Raw
    if ($content -match '### Status: \*\*Accepted\*\*') {
        $AcceptedChdrs += $f.Name
        $AcceptedCount++
    } elseif ($content -match '### Status: \*\*Published\*\*') {
        $PublishedCount++
    }
}
# Dual-read: count records in both the new and the legacy root.
$MemoryCount = @(Get-ChildItem -Path $MemoryDir -Filter "ChDR-*.md" -ErrorAction SilentlyContinue).Count + @(Get-ChildItem -Path $LegacyMemoryDir -Filter "ChDR-*.md" -ErrorAction SilentlyContinue).Count
$MemoryIndexExists = Test-Path $MemoryIndex

$output = @{
    REPO_ROOT = $projectRoot
    CHDR_DRAFTS_DIR = $ChdrDraftsDir
    MEMORY_DIR = $MemoryDir
    MEMORY_INDEX = $MemoryIndex
    ACCEPTED_CHDRS = $AcceptedChdrs
    ACCEPTED_COUNT = $AcceptedCount
    PUBLISHED_COUNT = $PublishedCount
    MEMORY_COUNT = $MemoryCount
    MEMORY_INDEX_EXISTS = $MemoryIndexExists
}
$output | ConvertTo-Json -Compress
