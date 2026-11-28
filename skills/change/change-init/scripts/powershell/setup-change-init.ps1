#!/usr/bin/env pwsh
# setup-change-init.ps1 — Setup for change-init (self-contained)
$ErrorActionPreference = "Stop"

# Layout roots (.adlc/ machine pipeline; docs/adlc/ human-facing deliverables)
$ADLC_DIR = if ($env:ADLC_DIR) { $env:ADLC_DIR } else { ".adlc" }
$DOCS_ADLC_DIR = if ($env:DOCS_ADLC_DIR) { $env:DOCS_ADLC_DIR } else { "docs/adlc" }
$DOCS_ADLC_MEMORY = if ($env:DOCS_ADLC_MEMORY) { $env:DOCS_ADLC_MEMORY } else { "docs/adlc/memory" }
$DOCS_ADLC_PRODUCT = if ($env:DOCS_ADLC_PRODUCT) { $env:DOCS_ADLC_PRODUCT } else { "docs/adlc/product" }
$DOCS_ADLC_ARCHITECT = if ($env:DOCS_ADLC_ARCHITECT) { $env:DOCS_ADLC_ARCHITECT } else { "docs/adlc/architect" }
$ADLC_DRAFTS = if ($env:ADLC_DRAFTS) { $env:ADLC_DRAFTS } else { ".adlc/drafts" }

# Sibling library — chdr-lib.ps1 sits next to this script (each skill vendors
# its own copy).
. (Join-Path $PSScriptRoot "chdr-lib.ps1")

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

# ID allocation: slugify(title) + collision check.
$IdAllocation = "slug"
$ExistingChdrs = @(Get-ChildItem -Path $ChdrDraftsDir -Filter "ChDR-*.md" -ErrorAction SilentlyContinue).Count
$TdConfigured = if (Test-Path $TeamAiDirectives) { "true" } else { "false" }

$output = @{
    REPO_ROOT = $projectRoot
    CHDR_DRAFTS_DIR = $ChdrDraftsDir
    CHANGE_STATE_FILE = $ChangeStateFile
    TEAM_AI_DIRECTIVES = $TeamAiDirectives
    BRANCH = $Branch
    id_allocation = $IdAllocation
    EXISTING_CHDRS = $ExistingChdrs
    TD_CONFIGURED = ($TdConfigured -eq "true")
    GIT_AVAILABLE = ($GitAvailable -eq "true")
    DEFAULT_BRANCH = $DefaultBranch
}
$output | ConvertTo-Json -Compress
