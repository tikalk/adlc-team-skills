#!/usr/bin/env pwsh
# setup-evals-init.ps1 — Setup for evals-init (self-contained)
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

$ProjectRoot = Resolve-ProjectRoot

# Resolve WORKSPACE_REPO_ROOT via shared team-paths (no per-project subfolders)
$_scriptDir = $PSScriptRoot
if (-not $_scriptDir) { $_scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$_teamPaths = $null
foreach ($_cand in @(
  (Join-Path $_scriptDir "../../../../team/team-paths.ps1"),
  (Join-Path $_scriptDir "../../../team/team-paths.ps1"),
  (Join-Path $_scriptDir "../../team/team-paths.ps1"),
  (Join-Path $_scriptDir "../team-paths.ps1"),
  (Join-Path $_scriptDir "team-paths.ps1")
)) {
  if (Test-Path $_cand) { $_teamPaths = $_cand; break }
}
if ($_teamPaths) {
  . $_teamPaths
  $_ws = Resolve-WorkspaceRepoRoot -ProjectRoot $ProjectRoot
  $WorkspaceRepoRoot = $_ws.WorkspaceRepoRoot
  $WorkspaceConfigured = $_ws.WorkspaceConfigured
} else {
  $WorkspaceRepoRoot = $ProjectRoot
  $WorkspaceConfigured = $false
}

$TeamAiDirectives = Resolve-TeamAiDirectives $ProjectRoot
$Branch = Resolve-Branch

$result = @{
    REPO_ROOT = $ProjectRoot
    TEAM_AI_DIRECTIVES = $TeamAiDirectives
    BRANCH = $Branch
    WORKSPACE_REPO_ROOT = $WorkspaceRepoRoot
}

$result | ConvertTo-Json -Compress