#!/usr/bin/env pwsh
# post-completion.ps1 — leave the one completion record of a mission run on
# its issue (PowerShell twin of post-completion.sh; SF-SKILL-05).
#
# Why: missions ended with no word on the issue (octopus-next#1507, #1510,
# #1512, #1516), or with records in three marker spellings, one with an
# invented run id (#1523), or wrote "completed" for a run a gate then parked
# (#1530). This command writes exactly one record per run, in one format, for
# every outcome, and reads it back.
#
# Usage: post-completion.ps1 --outcome <done|no-op|blocked|failed> --conclusion "<one line>"
#          [--issue <group>/<project>#<iid>] [--mr-url <https url>]
#          [--details-file <markdown>] [--step <step id>]
# The run id comes from the run context (ADLC_RUN_ID, else the lane's
# WORKFLOW_INPUTS.run_id through run-context.ps1); without one: exit 2.
# Record format, one-record-per-run rule and exit codes: see the bash twin.

$ErrorActionPreference = 'Stop'
$script:ErrorView = 'ConciseView'

function Die([string]$Message) {
    [Console]::Error.WriteLine("post-completion: $Message")
    exit 2
}
# json <node-script> [args...] — node is the JSON engine (same as the bash twin).
function json([string]$Script, [string[]]$JArgs = @()) {
    if ($JArgs.Count -gt 0) { node -e $Script @JArgs } else { node -e $Script }
}

$opts = @{ issue = ''; outcome = ''; conclusion = ''; 'mr-url' = ''; 'details-file' = ''; step = 'execute' }
for ($i = 0; $i -lt $args.Count; $i += 2) {
    $name = [string]$args[$i]
    if ($name -notmatch '^--(issue|outcome|conclusion|mr-url|details-file|step)$') { Die "unknown argument '$name'" }
    if ($i + 1 -ge $args.Count) { Die "missing value for $name" }
    $opts[$name.Substring(2)] = [string]$args[$i + 1]
}
$outcome = $opts['outcome']
switch -CaseSensitive ($outcome) {
    'done'    { $status = 'completed' }
    'no-op'   { $status = 'completed' }
    'blocked' { $status = 'failed' }
    'failed'  { $status = 'failed' }
    default   { Die '--outcome must be done, no-op, blocked or failed' }
}
$conclusion = (($opts['conclusion'] -replace '[\r\n\t]', ' ') -replace ' +', ' ')
if ($conclusion.Length -gt 300) { $conclusion = $conclusion.Substring(0, 300) }
if (-not $conclusion.Trim()) { Die '--conclusion is required' }
$details = $opts['details-file']
if ($details -and -not (Test-Path -LiteralPath $details -PathType Leaf)) { Die "--details-file $details does not exist" }
$mrUrl = $opts['mr-url']
if ($mrUrl -and ($mrUrl -notlike 'https://*' -or $mrUrl -match '\s')) { Die '--mr-url must be one https URL' }
$step = $opts['step']
if (-not ($step -cmatch '^[A-Za-z0-9][A-Za-z0-9._-]*\z')) { Die 'invalid --step' }
if (-not (Get-Command node -ErrorAction SilentlyContinue)) { Die 'node is required' }

$issue = $opts['issue']
if (-not $env:ADLC_RUN_ID -or -not ($issue + $env:ADLC_ISSUE_REF)) { . (Join-Path $PSScriptRoot 'run-context.ps1') }
if (-not $env:ADLC_RUN_ID) { Die 'no run context (ADLC_RUN_ID unset, no run_id in WORKFLOW_INPUTS) — a completion record names its run' }
if (-not ($env:ADLC_RUN_ID -cmatch '^[A-Za-z0-9][A-Za-z0-9._-]*\z')) { Die 'invalid ADLC_RUN_ID' }
$run = $env:ADLC_RUN_ID
if (-not $issue) { $issue = [string]$env:ADLC_ISSUE_REF }
if (-not $issue) { Die '--issue <group>/<project>#<iid> is required (no issue in the run context)' }
if ($issue -like '*..*') { Die 'invalid --issue' }
if (-not ($issue -cmatch '^(([A-Za-z0-9_][A-Za-z0-9._-]*/)+[A-Za-z0-9_][A-Za-z0-9._-]*)#([0-9]+)\z')) {
    Die '--issue must be <group>/<project>#<iid>'
}
$project = $Matches[1]; $iid = $Matches[3]

$provider = if ($env:ISSUE_PROVIDER) { $env:ISSUE_PROVIDER } else { 'gitlab' }
if ($provider -eq 'gitlab') {
    if (-not $env:GITLAB_HOST) { Die 'GITLAB_HOST is not set (the token is never sent to a guessed host)' }
    $glHost = ($env:GITLAB_HOST -replace '^https://', '').TrimEnd('/')
    $p = json 'console.log(encodeURIComponent(process.argv[1]))' @($project)
    $notesPath = "projects/$p/issues/$iid/notes"; $listQ = '?sort=desc&order_by=created_at&per_page=100'
} elseif ($provider -eq 'github') {
    # GitHub lists the oldest 100 comments first (see the bash twin).
    $notesPath = "repos/$project/issues/$iid/comments"; $listQ = '?per_page=100'
} else {
    Die "unsupported ISSUE_PROVIDER: $provider"
}

# 0: a completion record for this run is on the issue; 1: none; 2: unreadable.
function Test-Recorded {
    if ($provider -eq 'gitlab') { $raw = glab api --hostname $glHost "$notesPath$listQ" 2>$null } else { $raw = gh api "$notesPath$listQ" 2>$null }
    if ($LASTEXITCODE -ne 0) { return 2 }
    # The notes go in on stdin: a long thread can exceed the 128 KiB limit of
    # one command-line argument.
    $js = @'
let s = ""; process.stdin.on("data", d => s += d).on("end", () => {
let notes; try { notes = JSON.parse(s || "[]"); } catch (e) { process.exit(2); }
const run = process.argv[1].replace(/[.]/g, "\\.");
const re = new RegExp("<!--\\s*factory-(?:mission:step=complete\\b[^>]*\\brun=" + run + "(?:\\s|-->)|run:ended\\b[^>]*\\brun=" + run + "(?:\\s|-->)|mission:status=completed:run=" + run + "(?:\\s|-->|:))");
process.exit(Array.isArray(notes) && notes.some(n => re.test(String(n.body || ""))) ? 0 : 1);
});
'@
    (@($raw) -join "`n") | node -e $js $run | Out-Null
    return $LASTEXITCODE
}

$rc = Test-Recorded
if ($rc -eq 2) { Die "cannot read the notes of $issue" }
if ($rc -eq 0) {
    Write-Output "post-completion: OK — a completion record for run $run is already on $issue"
    exit 0
}

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("<!-- factory-mission:step=complete status=$status run=$run type=decision outcome=$outcome -->")
if ($status -eq 'failed') { $lines.Add("<!-- factory-run:ended reason=step-failed run=$run step=$step -->") }
$lines.Add('')
$lines.Add("### Mission $outcome")
$lines.Add('')
$lines.Add("**Code MR:** $(if ($mrUrl) { $mrUrl } else { 'none' })")
$lines.Add('')
$lines.Add("**Conclusion:** $conclusion")
$lines.Add('')
if ($env:ADLC_STEP_OUTPUT) {
    $lines.Add('**Next:** the completion gate — a person approves or rejects the result in Slack; the gate records its own answer on this issue.')
    $lines.Add('')
}
if ($details) {
    $lines.Add(([System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $details).Path)).TrimEnd("`n"))
    $lines.Add('')
}
$lines.Add("**Run:** $run")
$bodyText = ($lines -join "`n") + "`n"

for ($attempt = 1; $attempt -le 3; $attempt++) {
    $payload = json 'console.log(JSON.stringify({body: process.argv[1]}))' @($bodyText)
    if ($provider -eq 'gitlab') {
        $payload | glab api --hostname $glHost -X POST $notesPath -H 'Content-Type: application/json' --input - *> $null
    } else {
        $payload | gh api -X POST $notesPath -H 'Content-Type: application/json' --input - *> $null
    }
    if ($LASTEXITCODE -ne 0) { [Console]::Error.WriteLine("post-completion: attempt ${attempt}: the tracker refused the post") }
    if ((Test-Recorded) -eq 0) {
        Write-Output "post-completion: OK — completion record ($outcome) posted on $issue for run $run"
        exit 0
    }
    if ($attempt -lt 3) {
        $wait = if ($null -ne $env:POST_COMPLETION_BACKOFF -and $env:POST_COMPLETION_BACKOFF -ne '') { [int]$env:POST_COMPLETION_BACKOFF } else { $attempt * 5 }
        Start-Sleep -Seconds $wait
    }
}
[Console]::Error.WriteLine("post-completion: FAIL — the completion record is not on $issue after 3 attempts")
exit 1
