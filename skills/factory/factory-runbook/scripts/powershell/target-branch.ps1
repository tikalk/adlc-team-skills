#!/usr/bin/env pwsh
# target-branch.ps1 — resolve the run's target branch in one place
# (PowerShell twin of target-branch.sh; SF-FIX-23).
#
# Why: a factory mission normally cuts its work branch from origin's default
# branch and opens its merge request into it. To test the factory end to end
# without touching the default branch, the Argo lane can dispatch a mission
# against another branch: an issue labelled `target-branch::<branch>` makes the
# runner pod clone that branch and sets
#   ADLC_TARGET_BRANCH=<branch>            (every mission pod; empty = none)
#   WORKFLOW_INPUTS.target_branch=<branch>  (only when a branch was accepted)
# run-branch and open-mr read the answer from here, so "which branch does this
# run work against" has one definition.
#
# Sources, first hit wins:
#   1. ADLC_TARGET_BRANCH   2. WORKFLOW_INPUTS.target_branch
# Neither set (or both empty) = no target: the helpers use the default branch,
# exactly as before this script existed.
#
# A target that IS set must be a plain branch name:
#   ^[A-Za-z0-9][A-Za-z0-9._/-]{0,200}$, no "..", not ending in "/" or ".lock",
#   and accepted by `git check-ref-format`.
# Anything else is an ERROR, never "no target": a run that was dispatched
# against a branch must not quietly fall back to the default branch. The same
# holds when the two sources name different branches, and when
# WORKFLOW_INPUTS carries a target that cannot be read (no node, not a string,
# or not valid JSON while its text names "target_branch").
# Whether the branch exists on origin is checked by the helper that uses it.
#
# Usage:
#   . target-branch.ps1            # dot-sourced (the helpers do this): sets
#                                  # $env:ADLC_TARGET_BRANCH when a target
#                                  # resolved, and the variable
#                                  # $AdlcTargetBranchError (not an environment
#                                  # variable; empty when all is well). The
#                                  # dot-sourcing script must stop on a
#                                  # non-empty error.
#   pwsh -File target-branch.ps1   # prints two key=value lines:
#                                  #   target_branch=<branch|>   source=<env|lane|none>
# Exit (when executed): 0 with or without a target; 2 on an invalid target or a
# usage error, with the reason on stderr. node is the JSON engine (same as the
# bash twin).

$__adlcTbDotSourced = ($MyInvocation.InvocationName -eq '.')

$__adlcTb = & {
    # \z, not $: .NET's $ also matches before a trailing newline, bash's does not.
    $plain = '^[A-Za-z0-9][A-Za-z0-9._/-]{0,200}\z'

    # "<state> <value>" for WORKFLOW_INPUTS.target_branch: none | str <value> |
    # bad (present, not a string) | nonode (cannot tell without node) |
    # corrupt (not valid JSON and the text names the key; unparseable text
    # that does not name the key stays "none").
    function Get-LaneTarget {
        if (-not $env:WORKFLOW_INPUTS) { return 'none' }
        if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
            if ($env:WORKFLOW_INPUTS -like '*"target_branch"*') { return 'nonode' }
            return 'none'
        }
        $js = @'
let o;
try { o = JSON.parse(process.env.WORKFLOW_INPUTS); } catch (e) {
  if (process.env.WORKFLOW_INPUTS.includes('"target_branch"')) { process.stdout.write("corrupt"); process.exit(0); }
  o = null;
}
if (!o || typeof o !== "object" || Array.isArray(o) || !Object.prototype.hasOwnProperty.call(o, "target_branch")) {
  process.stdout.write("none");
} else if (typeof o.target_branch === "string") {
  process.stdout.write("str " + o.target_branch);
} else {
  process.stdout.write("bad");
}
'@
        $out = node -e $js 2>$null
        if ($LASTEXITCODE -ne 0 -or $null -eq $out) { return 'nonode' }
        return (@($out) -join "`n")
    }

    $branch = ''; $source = 'none'; $err = ''; $laneBranch = ''
    $lane = Get-LaneTarget
    if ($lane -ceq 'none') {
    } elseif ($lane.StartsWith('str ', [System.StringComparison]::Ordinal)) {
        $laneBranch = $lane.Substring(4)
    } elseif ($lane -ceq 'corrupt') {
        $err = 'WORKFLOW_INPUTS names target_branch but is not valid JSON — refusing to fall back to the default branch'
    } elseif ($lane -ceq 'bad') {
        $err = 'WORKFLOW_INPUTS.target_branch is not a string — refusing to fall back to the default branch'
    } else {
        $err = 'cannot read WORKFLOW_INPUTS.target_branch (node is needed) — refusing to fall back to the default branch'
    }
    if (-not $err) {
        if ($env:ADLC_TARGET_BRANCH) {
            $branch = $env:ADLC_TARGET_BRANCH; $source = 'env'
            if ($laneBranch -and ($laneBranch -cne $env:ADLC_TARGET_BRANCH)) {
                $branch = ''
                $err = 'ADLC_TARGET_BRANCH and WORKFLOW_INPUTS.target_branch name different branches — refusing to guess'
            }
        } elseif ($laneBranch) {
            $branch = $laneBranch; $source = 'lane'
        }
    }
    if ($branch) {
        # A set target is validated; a bad one is an error, not "no target".
        $ok = $true
        if ($branch.Contains("`n") -or $branch.Contains('..') -or $branch.EndsWith('/') -or
            $branch.EndsWith('.lock', [System.StringComparison]::Ordinal)) { $ok = $false }
        if ($branch -cnotmatch $plain) { $ok = $false }
        if ($ok) {
            git check-ref-format "refs/heads/$branch" *> $null
            if ($LASTEXITCODE -ne 0) { $ok = $false }
        }
        if (-not $ok) {
            $branch = ''
            $err = "invalid target branch (from $source): not a plain branch name — refusing to fall back to the default branch"
        }
    }
    [pscustomobject]@{ Branch = $branch; Source = $source; Error = $err }
}

if ($__adlcTbDotSourced) {
    # Dot-sourced: hand the answer to the dot-sourcing script, leave everything
    # else alone.
    $AdlcTargetBranchError = $__adlcTb.Error
    if ($__adlcTb.Branch) { $env:ADLC_TARGET_BRANCH = $__adlcTb.Branch }
    Remove-Variable -Name __adlcTb, __adlcTbDotSourced -ErrorAction SilentlyContinue
    return
}

if ($args.Count -gt 0) {
    [Console]::Error.WriteLine('usage: target-branch.ps1   (or dot-source it: . target-branch.ps1)')
    exit 2
}
if ($__adlcTb.Error) {
    [Console]::Error.WriteLine("target-branch: $($__adlcTb.Error)")
    exit 2
}
Write-Output "target_branch=$($__adlcTb.Branch)"
Write-Output "source=$($__adlcTb.Source)"
exit 0
