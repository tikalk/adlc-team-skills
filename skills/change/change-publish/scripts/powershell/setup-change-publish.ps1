#!/usr/bin/env pwsh
# setup-change-publish.ps1 — Setup for change-publish (self-contained)
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
$MemoryIndex = Join-Path $projectRoot ".adlc/memory/chdr.md"

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
$MemoryCount = @(Get-ChildItem -Path $MemoryDir -Filter "ChDR-*.md" -ErrorAction SilentlyContinue).Count
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
