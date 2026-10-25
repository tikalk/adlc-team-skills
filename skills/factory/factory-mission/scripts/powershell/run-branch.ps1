#!/usr/bin/env pwsh
# run-branch.ps1 — check out the intent run branch in the project root
# (PowerShell twin of run-branch.sh; ADR-431-amendment §1, adlc-workspace#26).
#
# Factory run context (ADLC_RUN_ID, ADR-444): check out
# factory/intent/<repo>-<iid> from ADLC_ISSUE_REF (<group>/<repo>#<iid>), or
# factory/intent/run-<run_id> without an issue, reusing the local branch or
# continuing from origin (local copy fast-forwarded; diverged halts), else
# creating it. The branch is shared by both intent lanes and by re-dispatches
# of the same issue. Without ADLC_RUN_ID: no-op (interactive sessions never
# switch branches). Prints the branch name on stdout.

$ErrorActionPreference = 'Stop'
$script:ErrorView = 'ConciseView'

function Die([string]$Message) {
    [Console]::Error.WriteLine("run-branch: $Message")
    exit 2
}

if (-not $env:ADLC_RUN_ID) {
    [Console]::Error.WriteLine("run-branch: no run context (ADLC_RUN_ID unset) — skipped")
    exit 0
}
if ($env:ADLC_RUN_ID -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') { Die "invalid ADLC_RUN_ID" }

$root = git rev-parse --show-toplevel 2>$null
if ($LASTEXITCODE -ne 0 -or -not $root) { Die "not inside a git work tree" }
Set-Location $root.Trim()

$branch = $null
if ($env:ADLC_ISSUE_REF) {
    # Never build anything but a plain <path>#<number>
    # (same rule as open-mr.ps1).
    if ($env:ADLC_ISSUE_REF -like '*..*') { Die "invalid ADLC_ISSUE_REF" }
    if ($env:ADLC_ISSUE_REF -match '^(([A-Za-z0-9_][A-Za-z0-9._-]*/)+([A-Za-z0-9_][A-Za-z0-9._-]*))#([0-9]+)$') {
        $branch = "factory/intent/$($Matches[3])-$($Matches[4])"
    } else { Die "invalid ADLC_ISSUE_REF" }
} else {
    $branch = "factory/intent/run-$($env:ADLC_RUN_ID)"
}

git check-ref-format "refs/heads/$branch" 2>$null
if ($LASTEXITCODE -ne 0) { Die "invalid ref name: $branch" }

$onOrigin = $false
git ls-remote --exit-code --heads origin $branch *> $null
if ($LASTEXITCODE -eq 0) {
    git fetch -q origin "+refs/heads/${branch}:refs/remotes/origin/${branch}"
    if ($LASTEXITCODE -ne 0) { Die "fetch of origin/$branch failed" }
    $onOrigin = $true
}

$localExists = $false
git show-ref --verify --quiet "refs/heads/$branch" *> $null
if ($LASTEXITCODE -eq 0) { $localExists = $true }

if ($localExists) {
    if ($onOrigin) {
        git merge-base --is-ancestor "refs/heads/$branch" "refs/remotes/origin/$branch" *> $null
        $a = $LASTEXITCODE
        git merge-base --is-ancestor "refs/remotes/origin/$branch" "refs/heads/$branch" *> $null
        $b = $LASTEXITCODE
        if ($a -ne 0 -and $b -ne 0) { Die "local $branch and origin have diverged — resolve by hand" }
    }
    git switch -q $branch
    if ($LASTEXITCODE -ne 0) { Die "git switch failed" }
    # Continue from origin: fast-forward when origin is ahead (no-op otherwise).
    if ($onOrigin) {
        git merge -q --ff-only "origin/$branch" *> $null
        if ($LASTEXITCODE -ne 0) { Die "fast-forward from origin/$branch failed (diverged?)" }
    }
} elseif ($onOrigin) {
    git switch -q -c $branch --track "origin/$branch"
    if ($LASTEXITCODE -ne 0) { Die "git switch --track failed" }
} else {
    git switch -q -c $branch
    if ($LASTEXITCODE -ne 0) { Die "git switch -c failed" }
}
Write-Output $branch
