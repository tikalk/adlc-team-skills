#!/usr/bin/env pwsh
# set-lifecycle.ps1 — the Set Lifecycle step (tracker-integration Operation 9)
# as one self-checking command (PowerShell twin of set-lifecycle.sh; SF-SKILL-04).
#
# Why: Operation 9 was prose only. A supervised mission that opened its code
# MR left its issue on `executing` (octopus-next#1507, 2026-11-09) although the
# skill told it to move the label: nothing ran the transition or checked it
# afterwards. This command adds the target, removes every other lifecycle
# label in the same call, re-reads the labels and fails unless exactly the
# target remains. It never touches `resume` (the gate runtime owns it).
#
# Usage: set-lifecycle.ps1 --to <state> [--issue <group>/<project>#<iid>]
#   states: intent spec-gated executing parked validation done cancelled
#   --issue defaults to the run's issue (ADLC_ISSUE_REF, else the lane's
#   WORKFLOW_INPUTS.issue_ref through run-context.ps1).
#   Provider: ISSUE_PROVIDER (gitlab, default | github). GitLab host:
#   GITLAB_HOST (required). Custom label names (`labels:` in
#   .adlc/issues-provider.yml) are refused (exit 2).
# Exit codes: 0 exactly the target remains; 1 another lifecycle label remains
# or the target is missing; 2 usage error, refused names, tracker unreadable.

$ErrorActionPreference = 'Stop'
$script:ErrorView = 'ConciseView'

function Die([string]$Message) {
    [Console]::Error.WriteLine("set-lifecycle: $Message")
    exit 2
}
# json <node-script> [args...] — node is the JSON engine (same as the bash twin).
function json([string]$Script, [string[]]$JArgs = @()) {
    if ($JArgs.Count -gt 0) { node -e $Script @JArgs } else { node -e $Script }
}

$States = @('intent', 'spec-gated', 'executing', 'parked', 'validation', 'done', 'cancelled')

$issue = ''; $to = ''
for ($i = 0; $i -lt $args.Count; $i++) {
    switch -Regex ($args[$i]) {
        '^--issue$' { $i++; if ($i -ge $args.Count) { Die 'missing --issue value' }; $issue = [string]$args[$i]; continue }
        '^--to$'    { $i++; if ($i -ge $args.Count) { Die 'missing --to value' }; $to = [string]$args[$i]; continue }
        default     { Die "unknown argument '$($args[$i])'" }
    }
}
if (-not $to) { Die '--to <state> is required' }
if ($States -cnotcontains $to) { Die "--to must be one of: $($States -join ' ')" }
if (-not $issue) {
    if (-not $env:ADLC_ISSUE_REF) { . (Join-Path $PSScriptRoot 'run-context.ps1') }
    $issue = [string]$env:ADLC_ISSUE_REF
}
if (-not $issue) { Die '--issue <group>/<project>#<iid> is required (no issue in the run context)' }
if ($issue -like '*..*') { Die 'invalid --issue' }
if (-not ($issue -cmatch '^(([A-Za-z0-9_][A-Za-z0-9._-]*/)+[A-Za-z0-9_][A-Za-z0-9._-]*)#([0-9]+)\z')) {
    Die '--issue must be <group>/<project>#<iid>'
}
$project = $Matches[1]; $iid = $Matches[3]
if (-not (Get-Command node -ErrorAction SilentlyContinue)) { Die 'node is required' }

$root = git rev-parse --show-toplevel 2>$null
if ($LASTEXITCODE -ne 0 -or -not $root) { $root = (Get-Location).Path } else { $root = ([string]$root).Trim() }
$providerFile = Join-Path $root '.adlc/issues-provider.yml'
if ((Test-Path -LiteralPath $providerFile) -and (Select-String -LiteralPath $providerFile -Pattern '^labels:' -CaseSensitive -Quiet)) {
    Die 'custom lifecycle label names (.adlc/issues-provider.yml labels:) are not supported by this command — follow tracker-integration Operation 9'
}

$provider = if ($env:ISSUE_PROVIDER) { $env:ISSUE_PROVIDER } else { 'gitlab' }
if ($provider -eq 'gitlab') {
    if (-not $env:GITLAB_HOST) { Die 'GITLAB_HOST is not set (the token is never sent to a guessed host)' }
    $glHost = ($env:GITLAB_HOST -replace '^https://', '').TrimEnd('/')
    $p = json 'console.log(encodeURIComponent(process.argv[1]))' @($project)
    $issuePath = "projects/$p/issues/$iid"
} elseif ($provider -eq 'github') {
    $issuePath = "repos/$project/issues/$iid"
} else {
    Die "unsupported ISSUE_PROVIDER: $provider"
}

# The issue's labels (GitLab: strings; GitHub: objects with .name). Ok is
# $false when the tracker cannot be read (an issue with no labels is Ok).
function Read-Labels {
    if ($provider -eq 'gitlab') { $raw = glab api --hostname $glHost $issuePath 2>$null } else { $raw = gh api $issuePath 2>$null }
    if ($LASTEXITCODE -ne 0) { return [pscustomobject]@{ Ok = $false; Labels = @() } }
    # The issue JSON goes in on stdin: a long description can exceed the
    # 128 KiB limit of one command-line argument.
    $names = (@($raw) -join "`n") | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>console.log((JSON.parse(s || "{}").labels || []).map(l => typeof l === "string" ? l : l.name).join("\n")))'
    if ($LASTEXITCODE -ne 0) { return [pscustomobject]@{ Ok = $false; Labels = @() } }
    return [pscustomobject]@{ Ok = $true; Labels = [string[]]@(@($names) | Where-Object { $_ }) }
}

$read = Read-Labels
if (-not $read.Ok) { Die "cannot read the labels of $issue" }
$current = @($read.Labels)
$others = @($current | Where-Object { ($States -ccontains $_) -and ($_ -cne $to) })
$hasTarget = $current -ccontains $to

if ($others.Count -eq 0 -and $hasTarget) {
    Write-Output "set-lifecycle: OK — $issue is already '$to'"
    exit 0
}

$othersCsv = $others -join ','
if ($provider -eq 'gitlab') {
    # One call: add the target and remove every other lifecycle label.
    $body = json 'const [a, r] = process.argv.slice(1); const o = {add_labels: a}; if (r) o.remove_labels = r; console.log(JSON.stringify(o))' @($to, $othersCsv)
    $body | glab api --hostname $glHost -X PUT $issuePath -H 'Content-Type: application/json' --input - *> $null
    if ($LASTEXITCODE -ne 0) { Die "the tracker refused to update the labels of $issue" }
} else {
    $body = json 'console.log(JSON.stringify({labels: [process.argv[1]]}))' @($to)
    $body | gh api -X POST "$issuePath/labels" --input - *> $null
    if ($LASTEXITCODE -ne 0) { Die "the tracker refused to add '$to' to $issue" }
    foreach ($l in $others) {
        gh api -X DELETE "$issuePath/labels/$l" *> $null
        if ($LASTEXITCODE -ne 0) { Die "the tracker refused to remove '$l' from $issue" }
    }
}

$after = Read-Labels
if (-not $after.Ok) { Die "cannot re-read the labels of $issue" }
$left = @(@($after.Labels) | Where-Object { $States -ccontains $_ }) -join ','
if ($left -ceq $to) {
    $removed = if ($othersCsv) { " (removed: $othersCsv)" } else { '' }
    Write-Output "set-lifecycle: OK — $issue moved to '$to'$removed"
    exit 0
}
$shown = if ($left) { $left } else { 'none' }
[Console]::Error.WriteLine("set-lifecycle: FAIL — $issue carries lifecycle label(s) '$shown' after moving to '$to'; report this on the issue, never as done")
exit 1
