#!/usr/bin/env pwsh
# Confirm-gated lifecycle backfill (factory-setup Mode 3).
# PowerShell twin of scripts/bash/lifecycle-backfill.sh: same table, rules and
# exit codes. Without -Apply it makes NO tracker call. Run -Apply only after the
# human has approved the dry-run table, and never in a headless run.
#
# Usage:
#   lifecycle-backfill.ps1 -Plan <lint.json> -Provider <gitlab|github> -Project <path|owner/repo> [-Apply] [-Config <file>]
# A plan for another project and an active `labels:` mapping are refused; a row
# whose live state, lifecycle labels or `interactive` flag changed since the
# lint is skipped as stale.
#
# Exit codes: 0 = done (or dry run), 1 = a row failed verification, 2 = usage or tracker error.
[CmdletBinding()]
param(
  [string]$Plan = "",
  [string]$Provider = "",
  [string]$Project = "",
  [switch]$Apply,
  [string]$Config = ".adlc/issues-provider.yml"
)
$ErrorActionPreference = "Stop"

if (-not $Plan -or -not (Test-Path $Plan)) { [Console]::Error.WriteLine("lifecycle-backfill: -Plan <file> is required"); exit 2 }
if ($Provider -notin @("gitlab", "github")) { [Console]::Error.WriteLine("lifecycle-backfill: -Provider must be gitlab or github"); exit 2 }
if (-not $Project) { [Console]::Error.WriteLine("lifecycle-backfill: -Project is required"); exit 2 }

if ((Test-Path $Config) -and (Select-String -Path $Config -Pattern '^labels:' -Quiet)) {
  [Console]::Error.WriteLine("lifecycle-backfill: $Config has an active labels: mapping; this backfill only knows the canonical names. Relabel by hand, or remove the mapping.")
  exit 2
}
$Lifecycle = @("intent", "spec-gated", "executing", "parked", "validation", "done", "cancelled")
$planObj = (Get-Content -Raw $Plan) | ConvertFrom-Json
if ($planObj.project -and $planObj.project -ne $Project) {
  [Console]::Error.WriteLine("lifecycle-backfill: the plan was written for project $($planObj.project), not $Project"); exit 2
}
$rows = @($planObj.violations)
$enc = [System.Uri]::EscapeDataString($Project)

"## Lifecycle backfill ($(if ($Apply) { 'apply' } else { 'dry run' }))"
""
"| Issue | Current labels | Proposed |"
"|--|--|--|"
foreach ($r in $rows) { "| #$($r.iid) | $(@($r.labels) -join ', ') | $($r.proposed) |" }
""

if (-not $Apply) {
  "Dry run: no tracker writes. Re-run with -Apply only after the human approves this table."
  exit 0
}

# Live issue as @{ state = opened|closed; labels = @(..) }.
function Get-LiveIssue([int]$iid) {
  if ($Provider -eq "gitlab") {
    $raw = & glab api "projects/$enc/issues/$iid"
    if ($LASTEXITCODE -ne 0) { throw "cannot read #$iid" }
    $i = ($raw -join "`n") | ConvertFrom-Json
    return @{ state = $i.state; labels = @($i.labels) }
  }
  $raw = & gh issue view $iid -R $Project --json state,labels
  if ($LASTEXITCODE -ne 0) { throw "cannot read #$iid" }
  $i = ($raw -join "`n") | ConvertFrom-Json
  return @{ state = $(if ($i.state -eq "CLOSED") { "closed" } else { "opened" }); labels = @($i.labels | ForEach-Object { $_.name }) }
}

$failed = 0
foreach ($r in $rows) {
  $iid = [int]$r.iid; $target = [string]$r.proposed
  if ($target -eq "-") { "skipped #$iid (needs a human decision)"; continue }
  try { $live = Get-LiveIssue $iid } catch { [Console]::Error.WriteLine("lifecycle-backfill: cannot read #$iid"); exit 2 }
  # Approval covers the state the lint saw. Anything else is stale.
  $liveLc = (@($live.labels | Where-Object { $Lifecycle -contains $_ }) | Sort-Object) -join ","
  $planLc = (@($r.lifecycle) | Sort-Object) -join ","
  if ($liveLc -ne $planLc -or $live.state -ne $r.state -or $live.labels -contains "interactive") {
    "stale #$iid (changed since the lint; re-run the lint)"; continue
  }
  $others = (@($live.labels | Where-Object { $Lifecycle -contains $_ -and $_ -ne $target }) -join ",")
  if ($Provider -eq "gitlab") {
    if ($others) { & glab api -X PUT "projects/$enc/issues/$iid" -f "add_labels=$target" -f "remove_labels=$others" | Out-Null }
    else { & glab api -X PUT "projects/$enc/issues/$iid" -f "add_labels=$target" | Out-Null }
  } else {
    if ($others) { & gh issue edit $iid -R $Project --add-label $target --remove-label $others | Out-Null }
    else { & gh issue edit $iid -R $Project --add-label $target | Out-Null }
  }
  $left = (@((Get-LiveIssue $iid).labels | Where-Object { $Lifecycle -contains $_ }) -join ",")
  if ($left -eq $target) {
    "set #$iid -> $target$(if ($others) { " (removed: $others)" })"
  } else {
    "FAILED #${iid}: expected exactly $target, found: $(if ($left) { $left } else { 'none' })"
    $failed = 1
  }
}
exit $failed
