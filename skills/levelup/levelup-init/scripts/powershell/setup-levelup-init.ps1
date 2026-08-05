#!/usr/bin/env pwsh
# setup-levelup-init.ps1 — Setup for levelup-init (self-contained)
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

function Resolve-SddDocsLocation {
  param([string]$ProjectRoot)
  $loc = $env:SDD_DOCS_LOCATION
  if ($loc) { return $loc }
  $initOpts = Join-Path $ProjectRoot ".adlc" "init-options.json"
  if (Test-Path $initOpts) {
    try {
      $config = Get-Content $initOpts -Raw | ConvertFrom-Json
      if ($config.sdd_docs_location) { return $config.sdd_docs_location }
    } catch {}
  }
  return ""
}

function Get-SddProjectSubfolderName {
  param([string]$ProjectRoot)
  $commonDir = git -C $ProjectRoot rev-parse --git-common-dir 2>$null
  if ($commonDir) {
    $parent = Split-Path $commonDir -Parent
    $normalized = (Resolve-Path $parent -ErrorAction SilentlyContinue).Path
    if ($normalized) { return Split-Path $normalized -Leaf }
  }
  return Split-Path $ProjectRoot -Leaf
}

function Resolve-Branch {
    $b = git branch --show-current 2>$null
    if ($b) { return $b }
    return "unknown"
}

function Get-NextCdrNumber {
    param([string]$Dir)
    if (-not (Test-Path $Dir)) { New-Item -ItemType Directory -Path $Dir -Force | Out-Null }
    $max = 0
    Get-ChildItem -Path $Dir -Filter "CDR-*.md" -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.BaseName -match 'CDR-(\d+)') {
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
$TeamAiDirectives = Resolve-TeamAiDirectives $ProjectRoot
$SddDocsLocation = Resolve-SddDocsLocation -ProjectRoot $ProjectRoot
if ($SddDocsLocation) {
  if ($SddDocsLocation.StartsWith("~")) {
    $SddDocsLocation = Join-Path $env:HOME $SddDocsLocation.Substring(1).TrimStart("/", "\")
  }
  $SddRoot = Join-Path $SddDocsLocation.TrimEnd("/", "\") (Get-SddProjectSubfolderName -ProjectRoot $ProjectRoot)
} else {
  $SddRoot = $ProjectRoot
}
$Branch = Resolve-Branch
$CdrDraftsDir = Join-Path $SddRoot ".adlc/drafts/cdr"
$SkillsDraftsDir = Join-Path $SddRoot ".adlc/drafts/skills"
$LevelupStateFile = Join-Path $SddRoot ".adlc/levelup/state.json"

New-Item -ItemType Directory -Path $CdrDraftsDir -Force | Out-Null
New-Item -ItemType Directory -Path $SkillsDraftsDir -Force | Out-Null
New-Item -ItemType Directory -Path (Split-Path $LevelupStateFile -Parent) -Force | Out-Null

$NextCdr = Get-NextCdrNumber $CdrDraftsDir
$ExistingCdrs = (Get-ChildItem -Path $CdrDraftsDir -Filter "CDR-*.md" -ErrorAction SilentlyContinue | Measure-Object).Count
$TdConfigured = if (Test-Path $TeamAiDirectives) { "true" } else { "false" }

$result = @{
    REPO_ROOT = $ProjectRoot
    SDD_ROOT = $SddRoot
    CDR_DRAFTS_DIR = $CdrDraftsDir
    SKILLS_DRAFTS_DIR = $SkillsDraftsDir
    LEVELUP_STATE_FILE = $LevelupStateFile
    TEAM_AI_DIRECTIVES = $TeamAiDirectives
    BRANCH = $Branch
    NEXT_CDR = $NextCdr
    EXISTING_CDRS = $ExistingCdrs
    TD_CONFIGURED = ($TdConfigured -eq "true")
}

$result | ConvertTo-Json -Compress
