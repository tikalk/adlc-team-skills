#!/usr/bin/env pwsh
# Confirm-gated lifecycle backfill (factory-setup Mode 3).
# PowerShell twin of scripts/bash/lifecycle-backfill.sh: same table, rules and
# exit codes. Without -Apply it makes NO tracker call. Run -Apply only after the
# human has approved the dry-run table, and never in a headless run.
#
# Usage:
#   lifecycle-backfill.ps1 -Plan <lint.json> -Provider <gitlab|github> -Project <path|owner/repo> [-Apply]
#
# Exit codes: 0 = done (or dry run), 1 = a row failed verification, 2 = usage or tracker error.
[CmdletBinding()]
param(
  [string]$Plan = "",
  [string]$Provider = "",
  [string]$Project = "",
  [switch]$Apply
)
$ErrorActionPreference = "Stop"

if (-not $Plan -or -not (Test-Path $Plan)) { [Console]::Error.WriteLine("lifecycle-backfill: -Plan <file> is required"); exit 2 }
if ($Provider -notin @("gitlab", "github")) { [Console]::Error.WriteLine("lifecycle-backfill: -Provider must be gitlab or github"); exit 2 }
if (-not $Project) { [Console]::Error.WriteLine("lifecycle-backfill: -Project is required"); exit 2 }

$Lifecycle = @("intent", "spec-gated", "executing", "parked", "validation", "done", "cancelled")
$rows = @(((Get-Content -Raw $Plan) | ConvertFrom-Json).violations)
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

function Get-LiveLabels([int]$iid) {
  if ($Provider -eq "gitlab") {
    return @(((& glab api "projects/$enc/issues/$iid") -join "`n" | ConvertFrom-Json).labels)
  }
  return @(((& gh issue view $iid -R $Project --json labels) -join "`n" | ConvertFrom-Json).labels | ForEach-Object { $_.name })
}

$failed = 0
foreach ($r in $rows) {
  $iid = [int]$r.iid; $target = [string]$r.proposed
  if ($target -eq "-") { "skipped #$iid (needs a human decision)"; continue }
  try { $current = Get-LiveLabels $iid } catch { [Console]::Error.WriteLine("lifecycle-backfill: cannot read #$iid"); exit 2 }
  $others = (@($current | Where-Object { $Lifecycle -contains $_ -and $_ -ne $target }) -join ",")
  if ($Provider -eq "gitlab") {
    if ($others) { & glab api -X PUT "projects/$enc/issues/$iid" -f "add_labels=$target" -f "remove_labels=$others" | Out-Null }
    else { & glab api -X PUT "projects/$enc/issues/$iid" -f "add_labels=$target" | Out-Null }
  } else {
    if ($others) { & gh issue edit $iid -R $Project --add-label $target --remove-label $others | Out-Null }
    else { & gh issue edit $iid -R $Project --add-label $target | Out-Null }
  }
  $left = (@(Get-LiveLabels $iid | Where-Object { $Lifecycle -contains $_ }) -join ",")
  if ($left -eq $target) {
    "set #$iid -> $target$(if ($others) { " (removed: $others)" })"
  } else {
    "FAILED #${iid}: expected exactly $target, found: $(if ($left) { $left } else { 'none' })"
    $failed = 1
  }
}
exit $failed
