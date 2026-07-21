#!/usr/bin/env pwsh
# setup-levelup-clarify.ps1 — Setup for levelup-clarify (self-contained)
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
    return (Join-Path $ProjectRoot ".adlc/team-ai-directives")
}

function Resolve-Branch {
    $b = git branch --show-current 2>$null
    if ($b) { return $b }
    return "unknown"
}

###############################################################################
# Main
###############################################################################

$ProjectRoot = Resolve-ProjectRoot
$TeamAiDirective = Resolve-TeamAiDirective $ProjectRoot
$Branch = Resolve-Branch
$CdrDraftsDir = Join-Path $ProjectRoot ".adlc/drafts/cdr"

New-Item -ItemType Directory -Path $CdrDraftsDir -Force | Out-Null

# Count pending and accepted CDRs using single-line format:
#   ### Status: **Proposed** / **Discovered** / **Accepted** / **Rejected**
$PendingCount = 0
$AcceptedCount = 0
if (Test-Path $CdrDraftsDir) {
    Get-ChildItem -Path $CdrDraftsDir -Filter "CDR-*.md" -ErrorAction SilentlyContinue | ForEach-Object {
        $content = Get-Content $_.FullName -Raw
        if ($content -match '(?m)^### Status: \*\*(Discovered|Proposed)\*\*') { $PendingCount++ }
        if ($content -match '(?m)^### Status: \*\*Accepted\*\*') { $AcceptedCount++ }
    }
}

$TdConfigured = if (Test-Path $TeamAiDirective) { "true" } else { "false" }

$result = @{
    REPO_ROOT = $ProjectRoot
    CDR_DRAFTS_DIR = $CdrDraftsDir
    TEAM_AI_DIRECTIVE = $TeamAiDirective
    BRANCH = $Branch
    PENDING_COUNT = $PendingCount
    ACCEPTED_COUNT = $AcceptedCount
    TD_CONFIGURED = ($TdConfigured -eq "true")
}

$result | ConvertTo-Json -Compress
