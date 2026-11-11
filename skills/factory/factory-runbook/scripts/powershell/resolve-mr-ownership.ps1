#!/usr/bin/env pwsh
# resolve-mr-ownership.ps1 — resolve MR/PR milestone + assignee propagation
# (PowerShell twin of bash/resolve-mr-ownership.sh; the MR-ownership
# decision; ADR-432 chain). One behavior, two platform scripts; keep in
# lockstep. The contract is pinned by tests/unit/test_resolve_mr_ownership.py,
# which runs both twins.
#
# Usage:
#   resolve-mr-ownership.ps1 <payload.json>
#   ... | resolve-mr-ownership.ps1          # payload on stdin
#
# The orchestrator opens (or reuses) the draft MR. This resolver decides what
# ownership fields that MR should carry, so the decision is a deterministic
# computation rather than an in-prompt judgement. The connector still performs
# every tracker call; this only answers *what to set, what to skip, and what
# to block on*.

$ErrorActionPreference = 'Stop'
$script:ErrorView = 'ConciseView'

function Die([string]$Message) {
    [Console]::Error.WriteLine("resolve-mr-ownership: $Message")
    exit 2
}

if ($args.Count -eq 1 -and ($args[0] -eq '-h' -or $args[0] -eq '--help')) {
    Write-Output @'
resolve-mr-ownership.ps1 — resolve MR/PR milestone + assignee propagation

Usage:
  resolve-mr-ownership.ps1 <payload.json>
  ... | resolve-mr-ownership.ps1          # payload on stdin

Input (JSON): provider, issue, mr, initiator, runner, denied_scope.
Output (JSON): action (set|skip|block), milestone, milestone_field,
assignee, assignee_field, reason.
'@
    exit 0
}
if ($args.Count -gt 1) { Die 'expected at most one payload JSON path (or payload on stdin)' }

$raw = $null
if ($args.Count -eq 1) {
    if (-not (Test-Path -LiteralPath $args[0] -PathType Leaf)) { Die "cannot read input: $($args[0])" }
    $raw = Get-Content -Raw -LiteralPath $args[0]
} else {
    $raw = [Console]::In.ReadToEnd()
}
try { $payload = $raw | ConvertFrom-Json -Depth 20 } catch { Die 'invalid payload JSON' }
if ($null -eq $payload -or $payload -is [array] -or -not ($payload -is [psobject])) {
    Die 'expected a JSON object payload'
}

$PROVIDERS = @{
    gitlab = @{ milestone_field = 'milestone_id'; milestone_source = 'milestone_id'; assignee_field = 'assignee_ids' }
    github = @{ milestone_field = 'milestone';    milestone_source = 'milestone.number'; assignee_field = 'assignees' }
    jira   = @{ milestone_field = $null;          milestone_source = $null;              assignee_field = 'assignee' }
    linear = @{ milestone_field = $null;          milestone_source = $null;              assignee_field = 'assigneeId' }
}

# The Issue's milestone in the provider's own value space, or $null.
function Read-Milestone($Issue, $Source) {
    if ($null -eq $Source) { return $null }
    if ($Source -eq 'milestone.number') {
        $m = $Issue.milestone
        if ($null -ne $m -and $m -is [psobject] -and $m -isnot [array]) {
            if ($null -eq $m.number) { return $null } else { return $m.number }
        }
        return $m
    }
    $v = $Issue.$Source
    if ($null -eq $v -or ($v -is [string] -and $v -eq '')) { return $null }
    return $v
}

# True when the MR's field is unset — the preserve-only guard.
function Test-MrFieldEmpty($Mr, [string]$Field) {
    if ($null -eq $Field) { return $true }
    $v = $Mr.$Field
    if ($null -eq $v) { return $true }
    if ($v -is [string]) { return $v.Length -eq 0 }
    if ($v -is [array]) { return $v.Count -eq 0 }
    if ($v -is [psobject]) { return @($v.PSObject.Properties).Count -eq 0 }
    return $false
}

# initiator -> Issue assignees -> runner identity (the fallback chain).
function Get-FirstCandidate($Initiator, $IssueAssignees, $Runner) {
    if ($Initiator) { return $Initiator }
    if ($IssueAssignees -is [array]) {
        foreach ($c in $IssueAssignees) { if ($c) { return $c } }
    }
    if ($Runner) { return $Runner }
    return $null
}

function Resolve-Ownership($Payload) {
    $provider = String-Coalesce $Payload.provider
    $provider = $provider.ToLowerInvariant()
    if (-not $PROVIDERS.ContainsKey($provider)) {
        return [ordered]@{
            action = 'block'; milestone = $null; milestone_field = $null
            assignee = $null; assignee_field = $null
            reason  = "unknown provider '$provider' — expected one of $($($PROVIDERS.Keys | Sort-Object) -join ', ')"
        }
    }
    $adapter = $PROVIDERS[$provider]
    $issue = if ($null -ne $Payload.issue -and $Payload.issue -is [psobject] -and $Payload.issue -isnot [array]) { $Payload.issue } else { [psobject]@{} }
    $mr = if ($null -ne $Payload.mr -and $Payload.mr -is [psobject] -and $Payload.mr -isnot [array]) { $Payload.mr } else { [psobject]@{} }

    # (7) pre-flight scope check -> (6) block the run with an actionable error.
    if ($Payload.denied_scope) {
        return [ordered]@{
            action = 'block'; milestone = $null; milestone_field = $null
            assignee = $null; assignee_field = $null
            reason  = "missing $($Payload.denied_scope) scope for $provider — the run cannot read the Issue or " +
                "write the MR's ownership fields. Grant the scope and re-run; the factory never guesses a " +
                "milestone or an assignee it could not verify."
        }
    }

    $notes = [System.Collections.Generic.List[string]]::new()

    # (2) map the milestone through the provider adapter.
    $milestone = $null; $milestoneField = $null
    if ($null -eq $adapter.milestone_field) {
        $notes.Add("$provider has no milestone concept — milestone is a permanent no-op")
    } else {
        $value = Read-Milestone $issue $adapter.milestone_source
        if ($null -eq $value) {
            # (5) silent skip — no milestone on the Issue is not an error.
            $notes.Add('Issue has no milestone — skipped')
        } elseif (-not (Test-MrFieldEmpty $mr $adapter.milestone_field)) {
            # (4) preserve-only — never overwrite a milestone a human set.
            $notes.Add("MR already has a $($adapter.milestone_field) — preserved")
        } else {
            $milestone = $value
            $milestoneField = $adapter.milestone_field
        }
    }

    # (3) resolve the assignee through the fallback chain.
    $assignee = $null; $assigneeField = $null
    if (-not (Test-MrFieldEmpty $mr $adapter.assignee_field)) {
        $notes.Add("MR already has an $($adapter.assignee_field) — preserved")
    } else {
        $assignee = Get-FirstCandidate $Payload.initiator $issue.assignees $Payload.runner
        if ($null -eq $assignee) {
            $notes.Add('no assignee candidate (no initiator, no Issue assignee, no runner identity) — skipped')
        } else {
            $assigneeField = $adapter.assignee_field
        }
    }

    $action = if ($null -ne $milestone -or $null -ne $assignee) { 'set' } else { 'skip' }
    $reason = if ($notes.Count -gt 0) { $notes -join '; ' } else { 'milestone and assignee propagated' }
    return [ordered]@{
        action = $action; milestone = $milestone; milestone_field = $milestoneField
        assignee = $assignee; assignee_field = $assigneeField; reason = $reason
    }
}

# "" and $null both count as absent (JSON null vs empty string).
function String-Coalesce($Value) {
    if ($null -eq $Value) { return '' }
    return [string]$Value
}

$result = Resolve-Ownership $payload
Write-Output ($result | ConvertTo-Json -Depth 10)
