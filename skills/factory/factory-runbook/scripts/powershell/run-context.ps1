#!/usr/bin/env pwsh
# run-context.ps1 — resolve the factory run context in one place
# (PowerShell twin of run-context.sh; SF-SKILL-03).
#
# Why: adlc-cli exports ADLC_RUN_ID / ADLC_ISSUE_REF only to the steps of a
# workflow run (supervised missions). Review runs and autonomous missions are
# raw agent runs in the same runner pods: adlc-cli never runs there, so
# ADLC_RUN_ID is unset, every helper used to no-op ("no run context —
# skipped") and agents invented run ids of their own. The Argo lane sets
# WORKFLOW_INPUTS on every runner pod:
#   {"issue_ref": <issue or MR ref>, "run_id": <GitLab event UUID>, "dispatch": ...}
#
# Sources, first hit wins:
#   run id    1. ADLC_RUN_ID      2. WORKFLOW_INPUTS.run_id
#   issue ref 1. ADLC_ISSUE_REF   2. WORKFLOW_INPUTS.issue_ref, only when it is
#             an issue ref (<group>/<project>#<iid>); a review's MR ref
#             (<group>/<project>!<iid>) is not an issue ref
# A run id must match ^[A-Za-z0-9][A-Za-z0-9._-]*$ and must not be the chart's
# placeholder "pending"; anything else counts as "no run id".
#
# Usage:
#   . run-context.ps1            # dot-sourced (the helpers do this): sets
#                                # $env:ADLC_RUN_ID and $env:ADLC_ISSUE_REF when
#                                # resolvable, changes nothing else
#   pwsh -File run-context.ps1   # prints four key=value lines:
#                                #   factory_run=yes|no  run_id=<id|>
#                                #   issue_ref=<ref|>    source=<adlc|lane|none>
# Exit: 0, also when nothing resolves (absence is an answer, not an error);
# 2 on a usage error. node is the JSON engine (same as the bash twin).

$__adlcRcDotSourced = ($MyInvocation.InvocationName -eq '.')

$__adlcRc = & {
    # \z, not $: .NET's $ also matches before a trailing newline, bash's does not.
    $safe = '^[A-Za-z0-9][A-Za-z0-9._-]*\z'
    $issue = '^(([A-Za-z0-9_][A-Za-z0-9._-]*/)+[A-Za-z0-9_][A-Za-z0-9._-]*)#[0-9]+\z'

    # One string field of WORKFLOW_INPUTS, or '' when it is absent, not JSON,
    # or not a string.
    function Get-LaneField([string]$Name) {
        if (-not $env:WORKFLOW_INPUTS) { return '' }
        if (-not (Get-Command node -ErrorAction SilentlyContinue)) { return '' }
        $js = @'
try {
  const o = JSON.parse(process.env.WORKFLOW_INPUTS);
  const v = o && typeof o === "object" && !Array.isArray(o) ? o[process.argv[1]] : undefined;
  process.stdout.write(typeof v === "string" ? v : "");
} catch (e) { process.stdout.write(""); }
'@
        $out = node -e $js $Name 2>$null
        if ($LASTEXITCODE -ne 0 -or $null -eq $out) { return '' }
        return (@($out) -join "`n")
    }

    $runId = ''; $issueRef = ''; $source = 'none'
    if ($env:ADLC_RUN_ID -and ($env:ADLC_RUN_ID -cmatch $safe)) {
        $runId = $env:ADLC_RUN_ID; $source = 'adlc'
    } else {
        $cand = Get-LaneField 'run_id'
        if ($cand -and ($cand -cne 'pending') -and ($cand -cmatch $safe)) {
            $runId = $cand; $source = 'lane'
        }
    }
    if ($env:ADLC_ISSUE_REF) {
        $issueRef = $env:ADLC_ISSUE_REF
    } else {
        $cand = Get-LaneField 'issue_ref'
        if ($cand -like '*..*') { $cand = '' }
        if ($cand -and ($cand -cmatch $issue)) { $issueRef = $cand }
    }
    [pscustomobject]@{ RunId = $runId; IssueRef = $issueRef; Source = $source }
}

if ($__adlcRcDotSourced) {
    # Dot-sourced: adopt what resolved, leave everything else alone.
    if ($__adlcRc.RunId) { $env:ADLC_RUN_ID = $__adlcRc.RunId }
    if ($__adlcRc.IssueRef) { $env:ADLC_ISSUE_REF = $__adlcRc.IssueRef }
    Remove-Variable -Name __adlcRc, __adlcRcDotSourced -ErrorAction SilentlyContinue
    return
}

if ($args.Count -gt 0) {
    [Console]::Error.WriteLine('usage: run-context.ps1   (or dot-source it: . run-context.ps1)')
    exit 2
}
if ($__adlcRc.RunId) { Write-Output 'factory_run=yes' } else { Write-Output 'factory_run=no' }
Write-Output "run_id=$($__adlcRc.RunId)"
Write-Output "issue_ref=$($__adlcRc.IssueRef)"
Write-Output "source=$($__adlcRc.Source)"
exit 0
