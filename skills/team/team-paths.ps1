#!/usr/bin/env pwsh
# team-paths.ps1 — Path / workspace resolution (PowerShell).
# Dot-source safely: functions only; CLI runs only when executed directly.
param(
  [switch]$Json
)

$ErrorActionPreference = "Stop"

function Expand-Tilde {
  param([string]$Path)
  if ([string]::IsNullOrEmpty($Path)) { return "" }
  if ($Path -eq "~") { return $env:HOME }
  if ($Path.StartsWith("~/") -or $Path.StartsWith("~\")) {
    return (Join-Path $env:HOME $Path.Substring(2))
  }
  return $Path
}

function Resolve-ProjectRoot {
  $dir = (Get-Location).Path
  while ($dir -ne "" -and $dir -ne "/") {
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
  if (-not $ProjectRoot) { $ProjectRoot = Resolve-ProjectRoot }

  $result = ""
  # 1. Env (explicit env: lookup — not shell variable bleed)
  if ($env:TEAM_AI_DIRECTIVES) { $result = $env:TEAM_AI_DIRECTIVES }

  # 2. init-options.json
  if (-not $result) {
    $initOptions = Join-Path $ProjectRoot ".adlc" "init-options.json"
    if (Test-Path $initOptions) {
      try {
        $config = Get-Content $initOptions -Raw | ConvertFrom-Json
        if ($config.team_ai_directives) { $result = [string]$config.team_ai_directives }
      } catch {}
    }
  }

  # 3. Fallback
  if (-not $result) { $result = Join-Path $ProjectRoot "team-ai-directives" }
  return (Expand-Tilde $result)
}

function Resolve-WorkspaceRepoRoot {
  param([string]$ProjectRoot)
  if (-not $ProjectRoot) { $ProjectRoot = Resolve-ProjectRoot }

  $configured = $false
  $result = ""

  # 1. Env
  if ($env:WORKSPACE_REPO_ROOT) {
    $result = Expand-Tilde $env:WORKSPACE_REPO_ROOT
    $configured = $true
  }

  # 2. init-options.json
  if (-not $result) {
    $initOptions = Join-Path $ProjectRoot ".adlc" "init-options.json"
    if (Test-Path $initOptions) {
      try {
        $config = Get-Content $initOptions -Raw | ConvertFrom-Json
        if ($config.workspace_repo_root) {
          $result = Expand-Tilde ([string]$config.workspace_repo_root)
          $configured = $true
        }
      } catch {}
    }
  }

  # 3. Auto-discovery: parent of git toplevel contains .adlc/
  if (-not $result) {
    $gitTop = git -C $ProjectRoot rev-parse --show-toplevel 2>$null
    if ($gitTop) {
      $parent = Split-Path $gitTop -Parent
      if ($parent -and $parent -ne $gitTop -and (Test-Path (Join-Path $parent ".adlc"))) {
        $result = $parent
        $configured = $true
      }
    }
  }

  # 4. Project root default
  if (-not $result) {
    $result = $ProjectRoot
    $configured = $false
  }

  if (Test-Path $result) {
    $result = (Resolve-Path $result).Path
  }

  return [pscustomobject]@{
    ProjectRoot = $ProjectRoot
    WorkspaceRepoRoot = $result
    WorkspaceConfigured = $configured
  }
}

function Emit-WorkspacePaths {
  param([switch]$AsJson)
  $projectRoot = Resolve-ProjectRoot
  $ws = Resolve-WorkspaceRepoRoot -ProjectRoot $projectRoot
  $team = Resolve-TeamAiDirectives -ProjectRoot $projectRoot
  $branch = $env:BRANCH
  if (-not $branch) {
    $b = git -C $projectRoot branch --show-current 2>$null
    $branch = if ($b) { $b } else { "unknown" }
  }

  if ($AsJson) {
    @{
      REPO_ROOT = $ws.ProjectRoot
      PROJECT_ROOT = $ws.ProjectRoot
      WORKSPACE_REPO_ROOT = $ws.WorkspaceRepoRoot
      WORKSPACE_CONFIGURED = [bool]$ws.WorkspaceConfigured
      TEAM_AI_DIRECTIVES = $team
      BRANCH = $branch
    } | ConvertTo-Json -Compress
  } else {
    Write-Output "PROJECT_ROOT=$($ws.ProjectRoot)"
    Write-Output "REPO_ROOT=$($ws.ProjectRoot)"
    Write-Output "WORKSPACE_REPO_ROOT=$($ws.WorkspaceRepoRoot)"
    Write-Output "WORKSPACE_CONFIGURED=$($ws.WorkspaceConfigured)"
    Write-Output "TEAM_AI_DIRECTIVES=$team"
    Write-Output "BRANCH=$branch"
  }
}

# Side-effect guard: only run CLI when this script is the entry point
$isDirect = $MyInvocation.InvocationName -ne '.' -and $MyInvocation.Line -notmatch '^\s*\.'
if ($isDirect -and $MyInvocation.MyCommand.Path -and
    $MyInvocation.MyCommand.Path -eq $PSCommandPath) {
  Emit-WorkspacePaths -AsJson:$Json
}
