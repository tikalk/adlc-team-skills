#!/usr/bin/env pwsh
# setup-team-constitution.ps1 — Setup for team-constitution (self-contained)
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

function Resolve-TeamAiDirective {
    param([string]$ProjectRoot)
    $td = $env:TEAM_AI_DIRECTIVE
    if ($td) { return $td }
    $initOpts = Join-Path $ProjectRoot ".adlc/init-options.json"
    if (Test-Path $initOpts) {
        try {
            $config = Get-Content $initOpts -Raw | ConvertFrom-Json
            if ($config.team_ai_directive) { return $config.team_ai_directive }
        } catch {}
    }
    return (Join-Path $ProjectRoot "team-ai-directives")
}

###############################################################################
# Main
###############################################################################

$ProjectRoot = Resolve-ProjectRoot
$TeamAiDirective = Resolve-TeamAiDirective $ProjectRoot
$ConstitutionFile = Join-Path $TeamAiDirective "context_modules/constitution.md"

# Detect constitution state: missing | placeholder | populated
$ConstitutionState = "missing"
if (Test-Path $ConstitutionFile) {
    $content = Get-Content $ConstitutionFile -Raw
    if ($content -match "No team-wide principles defined yet") {
        $ConstitutionState = "placeholder"
    } else {
        $ConstitutionState = "populated"
    }
}

# Check if team-ai-directives is a git repo with a clean working tree
$TdIsGit = "false"
$TdClean = "false"
if (Test-Path $TeamAiDirective) {
    $gitCheck = git -C $TeamAiDirective rev-parse --is-inside-work-tree 2>$null
    if ($LASTEXITCODE -eq 0) {
        $TdIsGit = "true"
        $status = git -C $TeamAiDirective status --porcelain 2>$null
        if (-not $status) { $TdClean = "true" }
    }
}

$result = @{
    REPO_ROOT = $ProjectRoot
    TEAM_AI_DIRECTIVE = $TeamAiDirective
    CONSTITUTION_FILE = $ConstitutionFile
    CONSTITUTION_STATE = $ConstitutionState
    TD_IS_GIT = ($TdIsGit -eq "true")
    TD_CLEAN = ($TdClean -eq "true")
}

$result | ConvertTo-Json -Compress
