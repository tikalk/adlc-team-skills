#!/usr/bin/env pwsh
# setup-change-init.ps1 — Setup for change-init (self-contained)
$ErrorActionPreference = "Stop"

###############################################################################
# Inline path resolution (no external helper dependency)
###############################################################################

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

function Resolve-TeamAiDirectives {
    param([string]$ProjectRoot)
    $td = $env:TEAM_AI_DIRECTIVES
    if ($td) { return $td }
    $initOpts = Join-Path $ProjectRoot ".adlc/init-options.json"
    if (Test-Path $initOpts) {
        try {
            $config = Get-Content $initOpts -Raw | ConvertFrom-Json
            if ($config.team_ai_directives) { return $config.team_ai_directives }
        } catch {}
    }
    return (Join-Path $ProjectRoot "team-ai-directives")
}

function Resolve-Branch {
    $b = git branch --show-current 2>$null
    if ($b) { return $b }
    return "unknown"
}

function Test-GitAvailable {
    git rev-parse --is-inside-work-tree 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { return "true" }
    return "false"
}

function Get-DefaultBranch {
    foreach ($b in @("main", "master")) {
        git show-ref --verify --quiet "refs/heads/$b" 2>$null
        if ($LASTEXITCODE -eq 0) { return $b }
    }
    $cur = git branch --show-current 2>$null
    if ($cur) { return $cur }
    return "unknown"
}

function Get-NextChdrNumber {
    param([string]$Dir)
    if (-not (Test-Path $Dir)) { New-Item -ItemType Directory -Path $Dir -Force | Out-Null }
    $max = 0
    Get-ChildItem -Path $Dir -Filter "ChDR-*.md" -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.BaseName -match 'ChDR-(\d+)') {
            $num = [int]$Matches[1]
            if ($num -gt $max) { $max = $num }
        }
    }
    return ('{0:D3}' -f ($max + 1))
}

###############################################################################
# Main
###############################################################################

$ProjectRoot = Resolve-ProjectRoot
$TeamAiDirectives = Resolve-TeamAiDirectives $projectRoot
$Branch = Resolve-Branch
$GitAvailable = Test-GitAvailable
$DefaultBranch = Get-DefaultBranch
$ChdrDraftsDir = Join-Path $projectRoot ".adlc/drafts/chdr"
$ChangeStateFile = Join-Path $projectRoot ".adlc/change/state.json"

$StateDir = Split-Path $ChangeStateFile -Parent
if (-not (Test-Path $ChdrDraftsDir)) { New-Item -ItemType Directory -Path $ChdrDraftsDir -Force | Out-Null }
if (-not (Test-Path $StateDir)) { New-Item -ItemType Directory -Path $StateDir -Force | Out-Null }

$NextChdr = Get-NextChdrNumber $ChdrDraftsDir
$ExistingChdrs = @(Get-ChildItem -Path $ChdrDraftsDir -Filter "ChDR-*.md" -ErrorAction SilentlyContinue).Count
$TdConfigured = if (Test-Path $TeamAiDirectives) { "true" } else { "false" }

$output = @{
    REPO_ROOT = $projectRoot
    CHDR_DRAFTS_DIR = $ChdrDraftsDir
    CHANGE_STATE_FILE = $ChangeStateFile
    TEAM_AI_DIRECTIVES = $TeamAiDirectives
    BRANCH = $Branch
    NEXT_CHDR = $NextChdr
    EXISTING_CHDRS = $ExistingChdrs
    TD_CONFIGURED = ($TdConfigured -eq "true")
    GIT_AVAILABLE = ($GitAvailable -eq "true")
    DEFAULT_BRANCH = $DefaultBranch
}
$output | ConvertTo-Json -Compress
