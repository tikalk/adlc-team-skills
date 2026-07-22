#!/usr/bin/env pwsh
# setup-levelup-publish.ps1 — Setup for levelup-publish (self-contained)
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
$SkillsDraftsDir = Join-Path $ProjectRoot ".adlc/drafts/skills"
$TraceFile = Join-Path $ProjectRoot ".adlc/drafts/trace.md"

New-Item -ItemType Directory -Path $CdrDraftsDir -Force | Out-Null
New-Item -ItemType Directory -Path $SkillsDraftsDir -Force | Out-Null
$TraceExists = (Test-Path $TraceFile)

# Find accepted CDRs using single-line format: ### Status: **Accepted**
$AcceptedCdrs = @()
if (Test-Path $CdrDraftsDir) {
    Get-ChildItem -Path $CdrDraftsDir -Filter "CDR-*.md" -ErrorAction SilentlyContinue | Sort-Object Name | ForEach-Object {
        $content = Get-Content $_.FullName -Raw
        if ($content -match '(?m)^### Status: \*\*Accepted\*\*') {
            $AcceptedCdrs += $_.BaseName
        }
    }
}

$TdConfigured = if (Test-Path $TeamAiDirective) { "true" } else { "false" }

# Check if team-ai-directives is a git repo with a clean working tree
$TdIsGit = "false"
$TdClean = "false"
if ($TdConfigured -eq "true") {
    $gitCheck = git -C $TeamAiDirective rev-parse --is-inside-work-tree 2>$null
    if ($LASTEXITCODE -eq 0) {
        $TdIsGit = "true"
        $status = git -C $TeamAiDirective status --porcelain 2>$null
        if (-not $status) { $TdClean = "true" }
    }
}

$result = @{
    REPO_ROOT = $ProjectRoot
    CDR_DRAFTS_DIR = $CdrDraftsDir
    SKILLS_DRAFTS_DIR = $SkillsDraftsDir
    TEAM_AI_DIRECTIVE = $TeamAiDirective
    BRANCH = $Branch
    ACCEPTED_CDRS = $AcceptedCdrs
    TD_CONFIGURED = ($TdConfigured -eq "true")
    TD_IS_GIT = ($TdIsGit -eq "true")
    TD_CLEAN = ($TdClean -eq "true")
    TRACE_FILE = $TraceFile
    TRACE_EXISTS = $TraceExists
}

$result | ConvertTo-Json -Compress
