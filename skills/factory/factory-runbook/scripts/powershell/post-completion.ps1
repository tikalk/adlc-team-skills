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
# Record format, the one-record-per-run-and-outcome rule (the run's newest
# record decides; a different outcome is posted as a record that names the one
# it replaces — SF-FIX-11), paginated reads and exit codes: see the bash twin.

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
    $notesPath = "repos/$project/issues/$iid/comments"; $listQ = '?per_page=100'
} else {
    Die "unsupported ISSUE_PROVIDER: $provider"
}

$errFile = [System.IO.Path]::GetTempFileName()

# Why the tracker CLI failed: the last line of its stderr (it carries the HTTP
# status) — one line, at most 200 characters, token-shaped strings removed.
function Get-Why {
    $l = ''
    if (Test-Path -LiteralPath $errFile) {
        $l = [string](@(Get-Content -LiteralPath $errFile | Where-Object { $_ -match '\S' }) | Select-Object -Last 1)
    }
    $l = $l -replace '[\x00-\x1f]', ''
    if ($l.Length -gt 200) { $l = $l.Substring(0, 200) }
    $l = $l -creplace '(glpat-|ghp_|gho_|ghs_|github_pat_)[A-Za-z0-9_-]+', '<redacted>'
    if ($l) { return $l }
    return 'no error text from the tracker CLI'
}

# The record search — the same script text as RECORD_JS in the bash twin
# (exit 0: the run's newest record says this outcome; 1: no record; 3: it says
# something else, printed on stdout; 2: not JSON).
$recordJs = @'
let s = ""; process.stdin.on("data", d => s += d).on("end", () => {
  const [run, want] = process.argv.slice(1);
  const values = []; let i = 0;
  try {
    while (i < s.length) {
      while (i < s.length && /\s/.test(s[i])) i++;
      if (i >= s.length) break;
      let depth = 0, inStr = false, esc = false, j = i;
      for (; j < s.length; j++) {
        const c = s[j];
        if (inStr) { if (esc) esc = false; else if (c === "\\") esc = true; else if (c === "\"") inStr = false; }
        else if (c === "\"") inStr = true;
        else if (c === "[" || c === "{") depth++;
        else if (c === "]" || c === "}") { depth--; if (depth === 0) { j++; break; } }
      }
      values.push(JSON.parse(s.slice(i, j))); i = j;
    }
  } catch (e) { process.exit(2); }
  const notes = values.flatMap(v => Array.isArray(v) ? v : [v]).filter(n => n && typeof n === "object");
  const tok = (seg, k) => { const m = seg.match(new RegExp("(?:^|\\s)" + k + "=(\\S+)")); return m ? m[1] : ""; };
  const old = new RegExp("<!--\\s*factory-mission:status=completed:run=" + run.replace(/[.]/g, "\\.") + "(?:\\s|-->|:)");
  const said = body => {
    for (const m of body.matchAll(/<!--\s*factory-mission:step=complete(?=\s)([^>]*)-->/g)) {
      if (tok(m[1], "run") !== run) continue;
      const o = tok(m[1], "outcome");
      if (["done", "no-op", "blocked", "failed"].includes(o)) return o;
      return tok(m[1], "status") === "failed" ? "ended" : "completed";
    }
    for (const m of body.matchAll(/<!--\s*factory-run:ended(?=\s)([^>]*)-->/g)) {
      if (tok(m[1], "run") === run) return "ended";
    }
    return old.test(body) ? "completed" : "";
  };
  const when = n => { const t = Date.parse(typeof n.created_at === "string" ? n.created_at : ""); return Number.isNaN(t) ? 0 : t; };
  const num = n => (Number.isFinite(Number(n.id)) ? Number(n.id) : 0);
  const records = notes.map(n => ({ n, said: said(typeof n.body === "string" ? n.body : "") })).filter(r => r.said);
  if (!records.length) process.exit(1);
  records.sort((a, b) => when(a.n) - when(b.n) || num(a.n) - num(b.n));
  const last = records[records.length - 1].said;
  const same = last === want ||
    (last === "completed" && (want === "done" || want === "no-op")) ||
    (last === "ended" && (want === "blocked" || want === "failed"));
  if (same) process.exit(0);
  process.stdout.write(last); process.exit(3);
});
'@

# 0: this run's newest completion record says $outcome; 1: the run has none;
# 3: its newest record says something else ($script:earlier); 2: unreadable.
$script:earlier = ''
function Test-Recorded {
    if ($provider -eq 'gitlab') {
        $raw = glab api --hostname $glHost --paginate "$notesPath$listQ" 2> $errFile
    } else {
        $raw = gh api --paginate "$notesPath$listQ" 2> $errFile
    }
    if ($LASTEXITCODE -ne 0) { return 2 }
    # The notes go in on stdin: a long thread can exceed the 128 KiB limit of
    # one command-line argument.
    $said = (@($raw) -join "`n") | node -e $recordJs $run $outcome
    $code = $LASTEXITCODE
    $script:earlier = (@($said) -join '').Trim()
    if ($code -eq 2) { Set-Content -LiteralPath $errFile -Value "the tracker's answer is not JSON" }
    return $code
}

$rc = Test-Recorded
if ($rc -eq 2) { Die "cannot read the notes of $issue — $(Get-Why)" }
if ($rc -eq 0) {
    Write-Output "post-completion: OK — a completion record ($outcome) for run $run is already on $issue"
    exit 0
}
$replaces = if ($rc -eq 3) { $script:earlier } else { '' }

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
if ($replaces) {
    $lines.Add(('**Replaces:** this run''s earlier record (`{0}`) — the same run was retried or resumed and ended differently; this record is the current one.' -f $replaces))
    $lines.Add('')
}
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

# Post only after a read that showed the record is not there: posting again
# without seeing the thread is how duplicate records were made.
$post = $true
for ($attempt = 1; $attempt -le 3; $attempt++) {
    if ($post) {
        $payload = json 'console.log(JSON.stringify({body: process.argv[1]}))' @($bodyText)
        if ($provider -eq 'gitlab') {
            $payload | glab api --hostname $glHost -X POST $notesPath -H 'Content-Type: application/json' --input - 2> $errFile | Out-Null
        } else {
            $payload | gh api -X POST $notesPath -H 'Content-Type: application/json' --input - 2> $errFile | Out-Null
        }
        if ($LASTEXITCODE -ne 0) { [Console]::Error.WriteLine("post-completion: attempt ${attempt}: the tracker refused the post — $(Get-Why)") }
    }
    $rc = Test-Recorded
    if ($rc -eq 0) {
        Write-Output "post-completion: OK — completion record ($outcome) posted on $issue for run $run"
        exit 0
    }
    if ($rc -eq 2) {
        $post = $false
        [Console]::Error.WriteLine("post-completion: attempt ${attempt}: cannot read the notes of $issue back — $(Get-Why)")
    } else {
        $post = $true
    }
    if ($attempt -lt 3) {
        $wait = if ($null -ne $env:POST_COMPLETION_BACKOFF -and $env:POST_COMPLETION_BACKOFF -ne '') { [int]$env:POST_COMPLETION_BACKOFF } else { $attempt * 5 }
        Start-Sleep -Seconds $wait
    }
}
if ($rc -eq 2) { Die "the notes of $issue cannot be read back, so the record is not confirmed (nothing more was posted) — $(Get-Why)" }
[Console]::Error.WriteLine("post-completion: FAIL — the completion record is not on $issue after 3 attempts")
exit 1
