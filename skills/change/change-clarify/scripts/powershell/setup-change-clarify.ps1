#!/usr/bin/env pwsh
# setup-change-clarify.ps1 — Setup for change-clarify (self-contained)
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
#  published ChDRs live under docs/adlc/memory (legacy .adlc/memory/chdr
# stays read-compatible — dual-read).
$MemoryDir = Join-Path $projectRoot "docs/adlc/memory/chdr"

if (-not (Test-Path $ChdrDraftsDir)) { New-Item -ItemType Directory -Path $ChdrDraftsDir -Force | Out-Null }

$AcceptedChdrs = 0
$PendingChdrs = 0
$ExistingChdrs = @(Get-ChildItem -Path $ChdrDraftsDir -Filter "ChDR-*.md" -ErrorAction SilentlyContinue).Count
if ($ExistingChdrs -gt 0) {
    Get-ChildItem -Path $ChdrDraftsDir -Filter "ChDR-*.md" -ErrorAction SilentlyContinue | ForEach-Object {
        $content = Get-Content $_.FullName -Raw
        # A ChDR draft carries its status in YAML frontmatter (the canonical
        # draft template) or, in a full record, in a "### Status: **X**"
        # heading. Both forms count -- matching only the heading form hid
        # every template-written draft.
        $status = ""
        if ($content -match '### Status: \*\*([A-Za-z]+)\*\*') {
            $status = $Matches[1].ToLower()
        }
        elseif ($content -match '(?m)^status:[ \t]*([A-Za-z]+)[ \t]*(#[^\r\n]*)?[ \t]*\r?$') {
            $status = $Matches[1].ToLower()
        }
        if ($status -eq "accepted" -or $status -eq "published") { $AcceptedChdrs++ }
        elseif ($status -eq "discovered" -or $status -eq "proposed") { $PendingChdrs++ }
    }
}

$output = @{
    REPO_ROOT = $projectRoot
    CHDR_DRAFTS_DIR = $ChdrDraftsDir
    MEMORY_DIR = $MemoryDir
    ACCEPTED_CHDRS = $AcceptedChdrs
    PENDING_CHDRS = $PendingChdrs
    EXISTING_CHDRS = $ExistingChdrs
}
$output | ConvertTo-Json -Compress
