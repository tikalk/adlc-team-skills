#!/usr/bin/env pwsh
# setup-change-clarify.ps1 — Setup for change-clarify (self-contained)
$ErrorActionPreference = "Stop"

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
$MemoryDir = Join-Path $projectRoot ".adlc/memory/chdr"

if (-not (Test-Path $ChdrDraftsDir)) { New-Item -ItemType Directory -Path $ChdrDraftsDir -Force | Out-Null }

$AcceptedChdrs = 0
$PendingChdrs = 0
$ExistingChdrs = @(Get-ChildItem -Path $ChdrDraftsDir -Filter "ChDR-*.md" -ErrorAction SilentlyContinue).Count
if ($ExistingChdrs -gt 0) {
    Get-ChildItem -Path $ChdrDraftsDir -Filter "ChDR-*.md" -ErrorAction SilentlyContinue | ForEach-Object {
        $content = Get-Content $_.FullName -Raw
        if ($content -match '### Status: \*\*Accepted\*\*') { $AcceptedChdrs++ }
        elseif ($content -match '### Status: \*\*(Discovered|Proposed)\*\*') { $PendingChdrs++ }
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
