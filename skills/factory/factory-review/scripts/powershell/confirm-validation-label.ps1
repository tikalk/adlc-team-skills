#!/usr/bin/env pwsh
# confirm-validation-label.ps1 — set the PR/MR `validation` label, then confirm
# it landed (PowerShell twin of confirm-validation-label.sh; adlc-team-skills#185).
#
# Why: a factory-review verdict has post-verdict's post-then-confirm loop
# (read back, retry, fail closed), but §2 step 6's label had no confirm — an
# agent that skipped the set, or a set the tracker silently dropped, looked
# exactly like a completed review. This command makes the label deterministic
# too: one invocation, one read-back, exit non-zero unless the target label
# remains.
#
# Usage:
#   confirm-validation-label.ps1 --mr <ref> [--to <label>] [--check-only]
#
#   <ref>  GitLab: <group>/<project>!<iid>   (the review lane's mr_ref)
#          GitHub: <owner>/<repo>#<number>
#   --to   label to set (default: validation)
#   --check-only  answer only: exit 0 when the label is on the PR/MR, 1 when
#          it is not (nothing is written).
# The ref picks the provider. GitLab calls go only to GITLAB_HOST (the token
# is never sent to a guessed host); GitHub calls only to github.com.
# Credentials are whatever `glab api` / `gh api` already use (GITLAB_TOKEN /
# GH_TOKEN in the environment) — this script never reads, prints or stores
# a token.
#
# Exit codes:
#   0  the label is on the PR/MR (set now, or already there)
#   1  the label is not on the PR/MR after the set (or --check-only found it
#      absent) — report this on the thread, never as done
#   2  usage error, unknown labels, or the tracker could not be read
# node is the JSON engine (same scripts as the bash twin).

$ErrorActionPreference = 'Stop'
$script:ErrorView = 'ConciseView'

function Die([string]$Message) {
    [Console]::Error.WriteLine("confirm-validation-label: $Message")
    if ($script:errFile) { Remove-Item -LiteralPath $script:errFile -Force -ErrorAction SilentlyContinue }
    exit 2
}

$mr = ''; $to = 'validation'; $checkOnly = $false
for ($i = 0; $i -lt $args.Count; $i++) {
    $a = [string]$args[$i]
    $next = if ($i + 1 -lt $args.Count) { [string]$args[$i + 1] } else { '' }
    switch -CaseSensitive ($a) {
        '--mr'         { if (-not $next) { Die '--mr is required' }; $mr = $next; $i++; continue }
        '--to'         { if (-not $next) { Die '--to requires a value' }; $to = $next; $i++; continue }
        '--check-only' { $checkOnly = $true; continue }
        { $_ -in @('-h', '--help') } {
            Get-Content -LiteralPath $PSCommandPath | Select-Object -Skip 1 -First 27 | ForEach-Object { $_ -replace '^# ?', '' }
            exit 0
        }
        default        { Die "unknown argument '$a'" }
    }
}
if (-not $mr) { Die '--mr is required' }
if ($to -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._/-]*\z') { Die '--to is not a valid label name' }
if (-not (Get-Command node -ErrorAction SilentlyContinue)) { Die 'node is required' }

$provider = ''; $project = ''; $iid = ''; $apiHost = ''; $p = ''
if ($mr -cmatch '^(([A-Za-z0-9_][A-Za-z0-9._-]*/)+[A-Za-z0-9_][A-Za-z0-9._-]*)!([0-9]+)\z') {
    $provider = 'gitlab'; $project = $Matches[1]; $iid = $Matches[3]
    if ($project -like '*..*') { Die 'invalid --mr' }
    $apiHost = [string]$env:GITLAB_HOST
    if ($apiHost.StartsWith('https://')) { $apiHost = $apiHost.Substring(8) }
    $apiHost = $apiHost.TrimEnd('/')
    if (-not $apiHost) { Die 'GITLAB_HOST is not set (the token is never sent to a guessed host)' }
    if (-not (Get-Command glab -ErrorAction SilentlyContinue)) { Die 'glab is required for a GitLab --mr' }
    $p = [uri]::EscapeDataString($project)
} elseif ($mr -cmatch '^([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)#([0-9]+)\z') {
    $provider = 'github'; $project = $Matches[1]; $iid = $Matches[2]
    if ($project -like '*..*') { Die 'invalid --mr' }
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { Die 'gh is required for a GitHub --mr' }
} else {
    Die '--mr must be <group>/<project>!<iid> (GitLab) or <owner>/<repo>#<number> (GitHub)'
}

# The CLI's stderr of the last call is kept in $script:errFile (see Get-Why).
$script:errFile = [System.IO.Path]::GetTempFileName()
function Api([string[]]$ApiArgs) {
    if ($provider -eq 'gitlab') { glab api --hostname $apiHost @ApiArgs 2> $script:errFile } else { gh api --hostname github.com @ApiArgs 2> $script:errFile }
}

# Why the tracker CLI failed: the line of its stderr that carries the HTTP
# status, else its last line — one line, at most 200 characters, token-shaped
# strings removed (same rule as the bash twin).
function Get-Why {
    $all = @()
    if (Test-Path -LiteralPath $script:errFile) { $all = @(Get-Content -LiteralPath $script:errFile | Where-Object { $_ -match '\S' }) }
    $l = [string](@($all | Where-Object { $_ -cmatch 'HTTP [0-9]{3}' }) | Select-Object -Last 1)
    if (-not $l) { $l = [string]($all | Select-Object -Last 1) }
    $l = $l -replace '[\x00-\x1f]', ''
    if ($l.Length -gt 200) { $l = $l.Substring(0, 200) }
    $l = $l -creplace '(glpat-|ghp_|gho_|ghs_|github_pat_)[A-Za-z0-9_-]+', '<redacted>'
    if ($l) { return $l }
    return 'no error text from the tracker CLI'
}

$readJs = @'
const raw = require("fs").readFileSync(process.argv[1], "utf8");
const labels = (JSON.parse(raw).labels || []).map(l => typeof l === "string" ? l : l.name);
console.log(labels.join("\n"));
'@

function Read-Labels {
    $f = [System.IO.Path]::GetTempFileName()
    try {
        if ($provider -eq 'gitlab') {
            $r = Api @("projects/$p/merge_requests/$iid")
            if ($LASTEXITCODE -ne 0) { Die "cannot read the labels of $mr — $(Get-Why)" }
            [System.IO.File]::WriteAllText($f, ((@($r) -join "`n")))
        } else {
            $r = Api @("repos/$project/pulls/$iid")
            if ($LASTEXITCODE -ne 0) { Die "cannot read the labels of $mr — $(Get-Why)" }
            [System.IO.File]::WriteAllText($f, ((@($r) -join "`n")))
        }
        return @(node -e $readJs $f)
    } finally {
        Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue
    }
}

$current = Read-Labels
if ($current -contains $to) {
    Remove-Item -LiteralPath $script:errFile -Force -ErrorAction SilentlyContinue
    Write-Output "confirm-validation-label: OK — $mr already carries '$to'"
    exit 0
}

if ($checkOnly) {
    Remove-Item -LiteralPath $script:errFile -Force -ErrorAction SilentlyContinue
    [Console]::Error.WriteLine("confirm-validation-label: MISSING — $mr does not carry '$to'")
    exit 1
}

function Remove-TempFiles { Remove-Item -LiteralPath $script:errFile -Force -ErrorAction SilentlyContinue }

# Only the stage-name label is set here; the command never moves the issue's
# lifecycle label (that stays the Set Lifecycle step, Operation 9).
$payload = [System.IO.Path]::GetTempFileName()
try {
    if ($provider -eq 'gitlab') {
        [System.IO.File]::WriteAllText($payload, ('{"add_labels": "' + $to + '"}'))
        Api @('-X', 'PUT', "projects/$p/merge_requests/$iid", '-H', 'Content-Type: application/json', '--input', $payload) | Out-Null
    } else {
        [System.IO.File]::WriteAllText($payload, ('{"labels": ["' + $to + '"]}'))
        Api @('-X', 'POST', "repos/$project/issues/$iid/labels", '-H', 'Content-Type: application/json', '--input', $payload) | Out-Null
    }
    if ($LASTEXITCODE -ne 0) { Remove-Item -LiteralPath $payload -Force -ErrorAction SilentlyContinue; Remove-TempFiles; Die "the tracker refused to label $mr — $(Get-Why)" }
} finally {
    Remove-Item -LiteralPath $payload -Force -ErrorAction SilentlyContinue
}
$after = Read-Labels
Remove-TempFiles
if ($after -contains $to) {
    Write-Output "confirm-validation-label: OK — $mr now carries '$to'"
    exit 0
}
[Console]::Error.WriteLine("confirm-validation-label: FAIL — '$to' is not on $mr after the set; report this on the thread, never as done")
exit 1
