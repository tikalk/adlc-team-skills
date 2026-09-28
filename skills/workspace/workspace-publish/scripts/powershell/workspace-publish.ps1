#!/usr/bin/env pwsh
# workspace-publish.ps1 — Full publish workflow for WORKSPACE_REPO_ROOT metadata.
# Never stages the entire working tree. Explicit pathspec for status/stage/commit.
param(
  [switch]$Ready,
  [switch]$Json
)
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TeamPaths = $null
foreach ($c in @(
  (Join-Path $ScriptDir "../../../../team/team-paths.ps1"),
  (Join-Path $ScriptDir "../../../team/team-paths.ps1"),
  (Join-Path $ScriptDir "../../team/team-paths.ps1"),
  (Join-Path $ScriptDir "team-paths.ps1")
)) {
  if (Test-Path $c) { $TeamPaths = $c; break }
}
if (-not $TeamPaths) { throw "team-paths.ps1 not found" }
. $TeamPaths

# Explicit pathspec — status, staging, AND commit
$Pathspec = @(".adlc", "PRD.md", "AD.md", "specs", "evals")

$ProjectRoot = Resolve-ProjectRoot
$ws = Resolve-WorkspaceRepoRoot -ProjectRoot $ProjectRoot

function Emit-Json {
  param([string]$Outcome, [string]$PrUrl = "", [string]$Message = "")
  @{
    PUBLISH_OUTCOME = $Outcome
    PR_URL = if ($PrUrl) { $PrUrl } else { $null }
    MESSAGE = if ($Message) { $Message } else { $null }
    REPO_ROOT = $ProjectRoot
    WORKSPACE_REPO_ROOT = $ws.WorkspaceRepoRoot
    WORKSPACE_CONFIGURED = [bool]$ws.WorkspaceConfigured
  } | ConvertTo-Json -Compress
}

if (-not $ws.WorkspaceConfigured) {
  $msg = "workspace_repo_root is not configured. Nothing to publish — SDD artifacts are stored in-project. Set WORKSPACE_REPO_ROOT or workspace_repo_root in .adlc/init-options.json to enable external storage and publishing."
  if ($Json) { Emit-Json -Outcome "not_configured" -Message $msg }
  else { Write-Output $msg }
  exit 0
}

$Target = $ws.WorkspaceRepoRoot
$gitCheck = git -C $Target rev-parse --is-inside-work-tree 2>$null
if ($LASTEXITCODE -ne 0 -or -not $gitCheck) {
  $msg = "Target directory is not a git repository. Offer: git init + commit, or write-only/no-op."
  if ($Json) { Emit-Json -Outcome "git_init_offered" -Message $msg }
  else {
    Write-Output "PUBLISH_OUTCOME=git_init_offered"
    Write-Output "TARGET_DIR=$Target"
    Write-Output $msg
  }
  exit 0
}

# Explicit conditional assignment (NOT PowerShell -or Boolean misuse)
$WsName = Split-Path -Leaf $Target
$BranchName = "workspace-publish/$WsName"

$status = git -C $Target status --porcelain -- @Pathspec 2>$null

$null = git -C $Target checkout -b $BranchName main 2>$null
if ($LASTEXITCODE -ne 0) {
  $null = git -C $Target checkout -b $BranchName 2>$null
  if ($LASTEXITCODE -ne 0) {
    $null = git -C $Target checkout $BranchName 2>$null
  }
}

if ($status) {
  $toAdd = @()
  foreach ($p in $Pathspec) {
    if (Test-Path (Join-Path $Target $p)) { $toAdd += $p }
  }
  if ($toAdd.Count -gt 0) {
    git -C $Target add -- @toAdd
    $commitStatus = git -C $Target status --porcelain -- @Pathspec 2>$null
    $commitMsg = "Publish workspace metadata`n`n$commitStatus"
    git -C $Target commit -m $commitMsg
  }
}

$remoteUrl = git -C $Target remote get-url origin 2>$null
if ($remoteUrl) {
  git -C $Target push -u origin $BranchName
  $gh = Get-Command gh -ErrorAction SilentlyContinue
  if ($gh) {
    $prTitle = "Publish workspace metadata from $WsName"
    $prBody = "Automated publish of workspace SDD metadata (.adlc, PRD.md, AD.md, specs, evals)."
    $draftArgs = if ($Ready) { @() } else { @("--draft") }
    Push-Location $Target
    try {
      $prUrl = (gh pr create @draftArgs --title $prTitle --body $prBody 2>$null) -join "`n"
    } finally { Pop-Location }
    if ($prUrl) {
      $outcome = if ($Ready) { "ready_pr" } else { "draft_pr" }
      if ($Json) { Emit-Json -Outcome $outcome -PrUrl $prUrl }
      else {
        Write-Output "PUBLISH_OUTCOME=$outcome"
        Write-Output "PR_URL=$prUrl"
      }
      exit 0
    }
  }
  $msg = "Pushed to origin/$BranchName. Open a PR manually at your Git host."
  if ($Json) { Emit-Json -Outcome "push_only" -Message $msg }
  else {
    Write-Output "PUBLISH_OUTCOME=push_only"
    Write-Output "MESSAGE=$msg"
  }
} else {
  $msg = "Committed to local branch $BranchName. Add a remote and push when ready."
  if ($Json) { Emit-Json -Outcome "local_only" -Message $msg }
  else {
    Write-Output "PUBLISH_OUTCOME=local_only"
    Write-Output "MESSAGE=$msg"
  }
}
