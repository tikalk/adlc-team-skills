#!/usr/bin/env pwsh
# setup-levelup-trace.ps1 — Setup for levelup-trace (self-contained)
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
$TraceFile = Join-Path $ProjectRoot ".adlc/drafts/trace.md"

New-Item -ItemType Directory -Path $CdrDraftsDir -Force | Out-Null
New-Item -ItemType Directory -Path (Split-Path $TraceFile -Parent) -Force | Out-Null

$result = @{
    REPO_ROOT = $ProjectRoot
    TEAM_AI_DIRECTIVE = $TeamAiDirective
    BRANCH = $Branch
    CDR_DRAFTS_DIR = $CdrDraftsDir
    TRACE_FILE = $TraceFile
}

$result | ConvertTo-Json -Compress
