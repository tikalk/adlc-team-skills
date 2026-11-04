#!/usr/bin/env pwsh
# resolve-hierarchy-strategy.ps1 — pick the epic hierarchy strategy from a
# capability probe result (the capability-aware hierarchy decision).
# PowerShell twin of bash/resolve-hierarchy-strategy.sh. One behavior, two
# platform scripts; keep in lockstep. The contract is pinned by
# tests/unit/test_factory_queue_hierarchy.py, which runs both twins.
#
# Usage:
#   resolve-hierarchy-strategy.ps1 <payload.json>
#   ... | resolve-hierarchy-strategy.ps1          # payload on stdin

$ErrorActionPreference = 'Stop'

function Die([string]$Message) {
    [Console]::Error.WriteLine("resolve-hierarchy-strategy: $Message")
    exit 2
}

if ($args.Count -eq 1 -and ($args[0] -eq '-h' -or $args[0] -eq '--help')) {
    Write-Output 'resolve-hierarchy-strategy.ps1 — pick the epic hierarchy strategy'
    Write-Output ''
    Write-Output 'Usage:'
    Write-Output '  resolve-hierarchy-strategy.ps1 <payload.json>'
    Write-Output '  ... | resolve-hierarchy-strategy.ps1          # payload on stdin'
    exit 0
}
if ($args.Count -gt 1) { Die 'expected at most one payload JSON path (or payload on stdin)' }

$raw = $null
if ($args.Count -eq 1) {
    if (-not (Test-Path -LiteralPath $args[0] -PathType Leaf)) { Die ('cannot read input: ' + $args[0]) }
    $raw = Get-Content -Raw -LiteralPath $args[0]
} else {
    $raw = [Console]::In.ReadToEnd()
}
try { $payload = $raw | ConvertFrom-Json -Depth 20 } catch { Die 'invalid payload JSON' }
if ($null -eq $payload) { Die 'expected a JSON object payload' }

$instance = $payload.instance
if (-not $instance) { $instance = 'unknown instance' }
$version = $payload.version
if (-not $version) { $version = 'unknown version' }
$caps = $payload.capabilities
$fresh = $payload.probe_fresh -eq $true
$sameTarget = ($payload.probe_from_instance -eq $payload.instance) -and ($payload.probe_from_version -eq $payload.version)
$useFail = $payload.use_time_failure

$prefix = 'Hierarchy probe on ' + $instance + ' ' + $version + ': strategy '

if ((-not $fresh) -or (-not $sameTarget)) {
    $out = [ordered]@{
        strategy = 'degraded_no_tree'
        attach = $false
        convert = $false
        disclosure = $prefix + 'degraded_no_tree. Probe is stale or from another target; no hierarchy used.'
        degraded = $true
        reason = 'stale-or-foreign probe counts as no probe'
    }
} elseif ($useFail) {
    $out = [ordered]@{
        strategy = 'degraded_no_tree'
        attach = $false
        convert = $false
        disclosure = $prefix + 'degraded_no_tree. Hierarchy operation ' + $useFail + ' failed at use time; fell back for this epic only.'
        degraded = $true
        reason = 'use-time failure downgrades only the affected epic'
    }
} elseif ($caps.epic_type -eq $true) {
    $out = [ordered]@{
        strategy = 'native_epic'
        attach = $true
        convert = $false
        disclosure = $prefix + 'native_epic. Native epic type carries the children; no conversion needed.'
        degraded = $false
        reason = 'best available: native epic type'
    }
} elseif ($caps.issue_parent_task_children -eq $true) {
    $tail = ' Issue parent holds Task children'
    if ($caps.work_item_convert -eq $true) { $tail = $tail + '; children convert from Issue to Task and the plan output names the trade-off.' }
    else { $tail = $tail + '.' }
    $converting = $false
    if ($caps.work_item_convert -eq $true) { $converting = $true }
    $out = [ordered]@{
        strategy = 'issue_parent_task_children'
        attach = $true
        convert = $converting
        disclosure = $prefix + 'issue_parent_task_children.' + $tail
        degraded = $false
        reason = 'best available: issue parent with task children'
    }
} else {
    $out = [ordered]@{
        strategy = 'degraded_no_tree'
        attach = $false
        convert = $false
        disclosure = $prefix + 'degraded_no_tree. Tracker has no hierarchy support; label convention used.'
        degraded = $true
        reason = 'no hierarchy capability; degraded mode, never silent'
    }
}

$out | ConvertTo-Json -Depth 20 -Compress
