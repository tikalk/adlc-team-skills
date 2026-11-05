#!/usr/bin/env pwsh
# Read-only lifecycle lint (tracker-integration §2 lifecycle state machine).
# PowerShell twin of scripts/bash/lifecycle-lint.sh: same rules, output and
# exit codes. This script never writes to the tracker.
#
# Usage:
#   lifecycle-lint.ps1 -Provider <gitlab|github> -Project <path|owner/repo> [-Json <file>]
#   lifecycle-lint.ps1 -Issues <file> [-Json <file>]          # offline
#
# Exit codes: 0 = no violations, 1 = violations found, 2 = usage or tracker error.
[CmdletBinding()]
param(
  [string]$Provider = "",
  [string]$Project = "",
  [string]$Issues = "",
  [string]$Json = ""
)
$ErrorActionPreference = "Stop"

$Lifecycle = @("intent", "spec-gated", "executing", "parked", "validation", "done", "cancelled")
$Rank = @{ "intent" = 0; "spec-gated" = 1; "executing" = 2; "parked" = 3; "validation" = 4 }

function Get-Enc([string]$p) { [System.Uri]::EscapeDataString($p) }

function Get-Issues {
  switch ($Provider) {
    "gitlab" {
      $enc = Get-Enc $Project
      $pages = & glab api --paginate "projects/$enc/issues?state=all&per_page=100"
      if ($LASTEXITCODE -ne 0) { throw "tracker fetch failed" }
      # --paginate prints one JSON array per page; join them into one array.
      $text = ($pages -join "`n") -replace '\]\s*\[', ','
      return @($text | ConvertFrom-Json | ForEach-Object {
        [pscustomobject]@{ iid = [int]$_.iid; state = $_.state; labels = @($_.labels); closed_by_merged = $null } })
    }
    "github" {
      $raw = & gh issue list -R $Project --state all --limit 5000 --json number,state,labels
      if ($LASTEXITCODE -ne 0) { throw "tracker fetch failed" }
      return @(($raw -join "`n") | ConvertFrom-Json | ForEach-Object {
        [pscustomobject]@{ iid = [int]$_.number; state = $(if ($_.state -eq "CLOSED") { "closed" } else { "opened" });
          labels = @($_.labels | ForEach-Object { $_.name }); closed_by_merged = $null } })
    }
    default { Write-Error "lifecycle-lint: -Provider must be gitlab or github"; exit 2 }
  }
}

function Test-ClosedByMerged([int]$iid) {
  if ($Provider -eq "gitlab") {
    $enc = Get-Enc $Project
    $mrs = (& glab api "projects/$enc/issues/$iid/closed_by") -join "`n" | ConvertFrom-Json
    return [bool](@($mrs | Where-Object { $_.state -eq "merged" }).Count -gt 0)
  }
  $v = (& gh issue view $iid -R $Project --json closedByPullRequestsReferences) -join "`n" | ConvertFrom-Json
  return [bool](@($v.closedByPullRequestsReferences).Count -gt 0)
}

try {
  if ($Issues) {
    $data = @((Get-Content -Raw $Issues) | ConvertFrom-Json)
  } elseif ($Provider -and $Project) {
    $data = Get-Issues
    foreach ($i in $data) {
      if ($i.state -ne "closed") { continue }
      $t = @($i.labels | Where-Object { $_ -eq "done" -or $_ -eq "cancelled" }).Count
      if ($t -ne 1) { $i.closed_by_merged = Test-ClosedByMerged $i.iid }
    }
  } else {
    Write-Error "lifecycle-lint: give -Issues <file>, or -Provider and -Project"; exit 2
  }
} catch {
  [Console]::Error.WriteLine("lifecycle-lint: $($_.Exception.Message)"); exit 2
}

function Get-Classification($i) {
  $lc = @($i.labels | Where-Object { $Lifecycle -contains $_ })
  $nt = @($lc | Where-Object { $_ -ne "done" -and $_ -ne "cancelled" })
  $n = $lc.Count
  if ($i.state -eq "closed") {
    $t = $n - $nt.Count
    if ($n -eq 1 -and $t -eq 1) { return $null }
    $violation = if ($n -eq 0) { "closed, no lifecycle label" } elseif ($t -eq 0) { "closed, not terminal" } else { "closed, extra lifecycle labels" }
    $hasDone = $lc -contains "done"; $hasCancelled = $lc -contains "cancelled"
    $proposed = if ($hasDone -and -not $hasCancelled) { "done" }
                elseif ($hasCancelled -and -not $hasDone) { "cancelled" }
                elseif ($i.closed_by_merged -eq $true) { "done" } else { "cancelled" }
    return @{ lifecycle = $lc; violation = $violation; proposed = $proposed }
  }
  if ($n -eq 1 -and $nt.Count -eq 1) { return $null }
  if ($n -eq 0) { return @{ lifecycle = @(); violation = "open, no lifecycle label"; proposed = "intent" } }
  if ($nt.Count -eq 0) { return @{ lifecycle = $lc; violation = "open, terminal label only"; proposed = "-" } }
  $violation = if ($nt.Count -lt $n) { "open, terminal label on an open issue" } else { "open, $n lifecycle labels" }
  $furthest = $nt | Sort-Object { $Rank[$_] } | Select-Object -Last 1
  return @{ lifecycle = $lc; violation = $violation; proposed = $furthest }
}

$violations = @(); $interactive = @()
foreach ($i in ($data | Sort-Object { [int]$_.iid })) {
  $c = Get-Classification $i
  if ($null -eq $c) { continue }
  $row = [ordered]@{ iid = [int]$i.iid; state = $i.state; labels = @($i.labels);
    lifecycle = @($c.lifecycle); violation = $c.violation; proposed = $c.proposed }
  if ($i.labels -contains "interactive") { $interactive += [pscustomobject]$row } else { $violations += [pscustomobject]$row }
}

if ($violations.Count -gt 0) {
  "| Issue | State | Lifecycle labels | Violation | Proposed |"
  "|--|--|--|--|--|"
  foreach ($v in $violations) {
    $lcText = if ($v.lifecycle.Count -eq 0) { "none" } else { $v.lifecycle -join ", " }
    "| #$($v.iid) | $($v.state) | $lcText | $($v.violation) | $($v.proposed) |"
  }
  ""
}
if ($interactive.Count -gt 0) {
  "Interactive issues (reported, not counted):"
  foreach ($v in $interactive) { "- #$($v.iid) ($($v.state)): $($v.violation)" }
  ""
}
"lifecycle-lint: $($data.Count) issues, $($violations.Count) violations, $($interactive.Count) interactive (reported, not counted)"

if ($Json) {
  [ordered]@{ issues = $data.Count; violations = $violations; interactive = $interactive } |
    ConvertTo-Json -Depth 6 | Set-Content -Encoding utf8 $Json
}
if ($violations.Count -gt 0) { exit 1 }
exit 0
