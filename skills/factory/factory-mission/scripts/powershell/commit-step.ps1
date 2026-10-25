#!/usr/bin/env pwsh
# commit-step.ps1 — one commit per lifecycle step (PowerShell twin of
# commit-step.sh; ADR-431 §2, ADR-431-amendment §1a–2, adlc-workspace#26).
#
# Usage: commit-step.ps1 [--commit] --orchestrator <name> --step <id>
#          --output-type draft|decision|artifact-ref|findings
#          --summary <one line> [--records ADR-1,PDR-2] -- <path>...
#
# Acts only with a factory run context (ADLC_RUN_ID), `adlc.commit_steps: true`
# in .adlc/init-options.json, or --commit (ADR-431 §6); otherwise prints
# `sha: none` and changes nothing. Stages ONLY the given paths, and only when
# they are inside the ADR-433 lifecycle write allowlist; run state
# (.adlc/workflows/**, ADR-393) is never staged. Deletions inside the
# allowlist (a promoted draft's old path) are committed with the step.
# Requires an explicit committer identity (ADR-339). Prints `sha: <sha>`, or
# `sha: none` when nothing changed.

$ErrorActionPreference = 'Stop'
$script:ErrorView = 'ConciseView'

function Die([string]$Message) {
    [Console]::Error.WriteLine("commit-step: $Message")
    exit 2
}

$orchestrator = ''; $step = ''; $outputType = ''; $summary = ''; $records = ''
$force = $false; $paths = [System.Collections.Generic.List[string]]::new()
$rest = $args
for ($i = 0; $i -lt $rest.Count; $i++) {
    switch -Regex ($rest[$i]) {
        '^--orchestrator$' { $i++; if ($i -ge $rest.Count) { Die 'missing --orchestrator value' }; $orchestrator = [string]$rest[$i]; continue }
        '^--step$'         { $i++; if ($i -ge $rest.Count) { Die 'missing --step value' }; $step = [string]$rest[$i]; continue }
        '^--output-type$'  { $i++; if ($i -ge $rest.Count) { Die 'missing --output-type value' }; $outputType = [string]$rest[$i]; continue }
        '^--summary$'      { $i++; if ($i -ge $rest.Count) { Die 'missing --summary value' }; $summary = [string]$rest[$i]; continue }
        '^--records$'      { $i++; if ($i -ge $rest.Count) { Die 'missing --records value' }; $records = [string]$rest[$i]; continue }
        '^--commit$'       { $force = $true; continue }
        '^--$'             { for ($j = $i + 1; $j -lt $rest.Count; $j++) { $paths.Add([string]$rest[$j]) }; $i = $rest.Count; continue }
        default            { Die "unknown argument: $($rest[$i])" }
    }
}

if ($orchestrator -notmatch '^[a-z][a-z0-9-]*$') { Die 'invalid --orchestrator' }
if ($step -notmatch '^[a-z][a-z0-9-]*$') { Die 'invalid --step' }
if ($outputType -notin @('draft', 'decision', 'artifact-ref', 'findings')) { Die "invalid --output-type: $outputType" }
if ($records -notmatch '^[A-Za-z0-9._,-]*$') { Die 'invalid --records' }
# One line, no trailer smuggling: newlines/tabs become spaces, length is capped.
$summary = ($summary -replace '[\r\n\t]', ' ') -replace ' {2,}', ' '
$summary = $summary.Trim()
if ($summary.Length -gt 100) { $summary = $summary.Substring(0, 100) }
if (-not $summary) { Die 'missing --summary' }
if ($paths.Count -eq 0) { Die 'no paths given' }

$root = git rev-parse --show-toplevel 2>$null
if ($LASTEXITCODE -ne 0 -or -not $root) { Die 'not inside a git work tree' }
$prefix = (git rev-parse --show-prefix).Trim()
Set-Location $root.Trim()

$active = $false
if ($env:ADLC_RUN_ID -or $force) { $active = $true }
elseif ((Test-Path '.adlc/init-options.json') -and
        ((Get-Content '.adlc/init-options.json' -Raw) -match '"commit_steps"\s*:\s*true')) { $active = $true }
if (-not $active) {
    [Console]::Error.WriteLine('commit-step: commits disabled (no run context or opt-in)')
    Write-Output 'sha: none'
    exit 0
}

# Path rules: repo-relative, no parent traversal, inside the ADR-433 allowlist.
$rel = [System.Collections.Generic.List[string]]::new()
foreach ($p in $paths) {
    if ($p.StartsWith('/') -or $p.Contains('\')) { Die "path $p is outside the repository (outside the allowlist)" }
    $rp = "$prefix$p"
    if ("/$rp/" -match '/\.\./|/\./') { Die "path $rp is outside the repository (outside the allowlist)" }
    if ($rp -like '.adlc/workflows/*') { Die "refusing run state $rp (outside the allowlist; run state stays on refs/factory-runs)" }
    $ok = ($rp -like '.adlc/drafts/pdr/*') -or ($rp -like '.adlc/drafts/adr/*') -or
          ($rp -like 'docs/adlc/memory/pdr/*') -or ($rp -like 'docs/adlc/memory/adr/*') -or
          ($rp -eq 'docs/adlc/product/PRD.md') -or ($rp -eq 'docs/adlc/architect/AD.md') -or
          ($rp -like 'docs/adlc/architect/views/*') -or
          ($rp -like '.adlc/product/sections/*') -or ($rp -eq '.adlc/product/state.json')
    if (-not $ok) { Die "path $rp is outside the ADR-433 lifecycle write allowlist" }
    $rel.Add($rp)
}

# Deletions inside the allowlist belong to the step too: a promotion moves a
# draft into memory, and the agent passes the new path only. Without this the
# old draft stays an uncommitted deletion and the engine's gate refuses it.
$allow = @('.adlc/drafts/pdr', '.adlc/drafts/adr', 'docs/adlc/memory/pdr', 'docs/adlc/memory/adr',
           'docs/adlc/product/PRD.md', 'docs/adlc/architect/AD.md', 'docs/adlc/architect/views',
           '.adlc/product/sections', '.adlc/product/state.json')
$deleted = @(git ls-files --deleted -- $allow) + @(git diff --cached --name-only --diff-filter=D -- $allow)
foreach ($d in $deleted) { if ($d -and -not $rel.Contains($d)) { $rel.Add($d) } }

$name = if ($env:GIT_COMMITTER_NAME) { $env:GIT_COMMITTER_NAME } else { (git config user.name 2>$null) }
$email = if ($env:GIT_COMMITTER_EMAIL) { $env:GIT_COMMITTER_EMAIL } else { (git config user.email 2>$null) }
if (-not $name -or -not $email) { Die 'no committer identity (set user.name/user.email, ADR-339)' }

git add -A -- $rel
if ($LASTEXITCODE -ne 0) { Die "git add failed" }
git diff --cached --quiet -- $rel
if ($LASTEXITCODE -eq 0) {
    Write-Output 'sha: none'
    exit 0
}

$runId = if ($env:ADLC_RUN_ID) { $env:ADLC_RUN_ID } else { 'interactive' }
$msgLines = @(
    "docs(adlc): $orchestrator $step — $summary",
    '',
    "Run-Id: $runId",
    "Step: $step",
    "Output-Type: $outputType"
)
if ($records) { $msgLines += "Records: $records" }
$msg = $msgLines -join "`n"
$tmp = [System.IO.Path]::GetTempFileName()
try {
    [System.IO.File]::WriteAllText($tmp, $msg + "`n")
    # --only: commit exactly these paths, whatever else is staged.
    git commit -q --only -F $tmp -- $rel
    if ($LASTEXITCODE -ne 0) { Die 'git commit failed' }
} finally {
    Remove-Item $tmp -ErrorAction SilentlyContinue
}
Write-Output "sha: $(git rev-parse HEAD)"
