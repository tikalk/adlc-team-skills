#!/usr/bin/env pwsh
# post-verdict.ps1 — post a factory-review verdict, then confirm it landed
# (PowerShell twin of post-verdict.sh; SF-SKILL-01).
#
# Why: a review that composes a verdict but never posts it looks exactly like
# a finished review — the run ends Succeeded and the Slack status line quotes
# the agent's last message (octopus-next!1298 and !1302, 2026-11-09). Posting
# and the read-back are therefore one deterministic command, not prose.
#
# Usage:
#   post-verdict.ps1 --mr <ref> --head <sha40> --body-file <file> [--retries <1-9>]
#                    [--pipeline-wait <0-3600 seconds>]
#   post-verdict.ps1 --mr <ref> --head <sha40> --check-only [--run <run_id>]
#
#   <ref>  GitLab: <group>/<project>!<iid>   (the review lane's mr_ref)
#          GitHub: <owner>/<repo>#<number>
#   The ref picks the provider. GitLab calls go only to GITLAB_HOST (the token
#   is never sent to a guessed host); GitHub calls only to github.com.
#   Credentials are whatever `glab api` / `gh api` already use (GITLAB_TOKEN /
#   GH_TOKEN in the environment) — this script never reads, prints or stores
#   a token. `glab api` works in runner pods even where `glab auth status`
#   reports no login.
#
# Posting mode checks the body before anything is sent: its first non-blank
# line must be the ONE `<!-- factory-review:step=review … -->` marker, the
# marker's head= must equal --head and it must carry a run=, and the whole
# body must pass `verdict-schema.ps1 lint` (SF-SKILL-02). It then posts
# (GitLab: a threaded MR discussion; GitHub: a COMMENT review bound to --head —
# never an approval), reads the thread back and requires a comment carrying a
# review marker with this head, run= and iter=. A verdict already on the
# thread for the same run=, iter= and head= is not posted twice.
#
# Pipeline at posting (SF-RT-05): before it posts, the script reads the head's
# CI as it is now (GitLab: the head's latest pipeline and its jobs; GitHub:
# the head's check runs) and appends one generated line to the body —
# "**Pipeline at posting (generated):** #<id> <status> — <job> <status> · …".
# It refuses the body (exit 2, nothing posted) when the verdict's own words
# call a job green/passed/success while that job is not `success`, or when the
# marker says outcome=merge-ready while a job that is not allowed to fail is
# unfinished or failed. Jobs named like "verdict" (checks that wait for the
# verdict itself) are ignored. When the pipeline cannot be read, the line says
# so and the verdict is posted as before. --pipeline-wait <s> re-reads the
# pipeline every POST_VERDICT_PIPELINE_POLL seconds (default 30) for up to <s>
# seconds while the only reason to refuse is a job that has not finished.
# (octopus-next!1352, 2026-11-23: "unit-tests green" posted at 23:18:29; the
# job was running and failed at 23:20:50.)
#
# --check-only posts nothing: it only answers "is a verdict for this head (and
# this run, with --run) on the thread?" — the question a lane step asks after
# the agent has exited.
#
# Exit codes:
#   0  the verdict is on the thread (posted now, or already there)
#   1  not on the thread after all retries (posting mode) / not found (check)
#   2  usage error, invalid body (schema, or a claim the pipeline contradicts),
#      or the tracker could not be read
# node is the JSON engine (same scripts as the bash twin).

$ErrorActionPreference = 'Stop'
$script:ErrorView = 'ConciseView'

function Die([string]$Message) {
    [Console]::Error.WriteLine("post-verdict: $Message")
    # The file that holds the tracker CLI's last stderr (set further down).
    if ($script:errFile) { Remove-Item -LiteralPath $script:errFile -Force -ErrorAction SilentlyContinue }
    exit 2
}

$mr = ''; $headSha = ''; $bodyFile = ''; $checkOnly = $false; $retries = 3; $runFilter = ''; $pipelineWait = 0
for ($i = 0; $i -lt $args.Count; $i++) {
    $a = [string]$args[$i]
    $next = if ($i + 1 -lt $args.Count) { [string]$args[$i + 1] } else { '' }
    switch -CaseSensitive ($a) {
        '--mr'         { if (-not $next) { Die '--mr requires a value' }; $mr = $next; $i++; continue }
        '--head'       { if (-not $next) { Die '--head requires a value' }; $headSha = $next; $i++; continue }
        '--body-file'  { if (-not $next) { Die '--body-file requires a value' }; $bodyFile = $next; $i++; continue }
        '--retries'    { if ($next -cnotmatch '^[1-9]\z') { Die '--retries takes 1-9' }; $retries = [int]$next; $i++; continue }
        '--run'        { if (-not $next) { Die '--run requires a value' }; $runFilter = $next; $i++; continue }
        '--pipeline-wait' {
            if ($next -cnotmatch '^[0-9]{1,4}\z' -or [int]$next -gt 3600) { Die '--pipeline-wait takes 0-3600 (seconds)' }
            $pipelineWait = [int]$next; $i++; continue
        }
        '--check-only' { $checkOnly = $true; continue }
        { $_ -in @('-h', '--help') } {
            Get-Content -LiteralPath $PSCommandPath | Select-Object -Skip 1 -First 56 | ForEach-Object { $_ -replace '^# ?', '' }
            exit 0
        }
        default        { Die "unknown argument '$a'" }
    }
}
if (-not $mr) { Die '--mr is required' }
if ($headSha -cnotmatch '^[0-9a-fA-F]{40}\z') { Die '--head must be the full 40-character SHA' }
$headSha = $headSha.ToLowerInvariant()
if ($runFilter -and ($runFilter -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._-]*\z')) { Die '--run is not a valid run id' }
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

# Same marker parser as the bash twin. Prints
# "<count>\t<first-line-ok>\t<head>\t<run>\t<iter>" ("-" for an absent field).
$markerJs = @'
const s = require("fs").readFileSync(process.argv[1], "utf8");
const re = /<!--\s*(factory-review:step=review(?=\s|-->)[\s\S]*?)-->/g;
const all = [...s.matchAll(re)];
const first = (s.split(/\r?\n/).find(l => l.trim() !== "") || "").trim();
const firstOk = /^<!--\s*factory-review:step=review(?=\s|-->).*-->$/.test(first) ? "yes" : "no";
const seg = all.length ? all[0][1] : "";
const tok = k => { const m = seg.match(new RegExp("(?:^|\\s)" + k + "=(\\S+)")); return m ? m[1] : "-"; };
console.log([all.length, firstOk, tok("head").toLowerCase(), tok("run"), tok("iter")].join("\t"));
'@

# Same thread search as the bash twin; reads the payload file (one or more
# concatenated JSON arrays). Exit 3 = not JSON (a read failure, never "absent").
$findJs = @'
const s = require("fs").readFileSync(process.argv[1], "utf8");
const [head, run, iter] = process.argv.slice(2);
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
} catch (e) { process.exit(3); }
const notes = values.flatMap(v => Array.isArray(v) ? v : [v]).filter(n => n && typeof n === "object");
const re = /<!--\s*(factory-review:step=review(?=\s|-->)[\s\S]*?)-->/;
const tok = (seg, k) => { const m = seg.match(new RegExp("(?:^|\\s)" + k + "=(\\S+)")); return m ? m[1] : ""; };
const hits = notes.filter(n => {
  const m = re.exec(typeof n.body === "string" ? n.body : "");
  if (!m) return false;
  if (tok(m[1], "head").toLowerCase() !== head) return false;
  if (run && tok(m[1], "run") !== run) return false;
  if (iter && tok(m[1], "iter") !== iter) return false;
  return true;
});
if (hits.length) console.log(String(hits[0].id));
'@

# Same CI reader as the bash twin (SF-RT-05): `id` picks the newest pipeline
# of a pipeline list; `eval` prints the generated pipeline line, then one line
# per refusal, and writes body + line to the out-file. Exit 0 = post,
# 4 = refuse, 5 = refuse only because a job has not finished, 3 = bad input.
$pipelineJs = @'
const fs = require("fs");
const [mode, provider, a1, a2, a3, a4] = process.argv.slice(1);
const parseAll = s => {
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
  } catch (e) { return null; }
  return values;
};
const read = f => { try { return fs.readFileSync(f, "utf8"); } catch (e) { return null; } };
const objs = v => v.flatMap(x => Array.isArray(x) ? x : [x]).filter(o => o && typeof o === "object");
const clean = s => String(s).replace(/[\x00-\x1f<>`*_|\[\]\\]/g, "").trim().slice(0, 80);
if (mode === "id") {
  // argv: id gitlab <pipelines-file>. Prints "<id>\t<status>" of the newest
  // pipeline, nothing when there is none; exit 3 when the answer is not JSON.
  const v = parseAll(read(a1) || "\u0000");
  if (!v) process.exit(3);
  const list = objs(v).filter(o => Number.isInteger(o.id)).sort((x, y) => y.id - x.id);
  if (list.length) console.log(list[0].id + "\t" + (String(list[0].status || "unknown").replace(/[^a-z_]/g, "") || "unknown"));
  process.exit(0);
}
// argv: eval <gitlab|github> <body-file> <jobs-file or "-"> <label> <out-file>
// Line 1 of stdout: the generated pipeline line. Further lines: one refusal
// each. Exit 0 = post (out-file then holds the body plus the generated line);
// 4 = refuse; 5 = refuse, but only for jobs that have not finished (waiting
// may clear it).
const body = read(a1);
if (body === null) process.exit(3);
let label = clean(a3 || "unavailable");
let jobs = null;
if (a2 && a2 !== "-") {
  const v = parseAll(read(a2) || "\u0000");
  if (!v) label += " — the job list was not JSON";
  else if (provider === "gitlab") {
    jobs = objs(v).filter(j => typeof j.name === "string" && typeof j.status === "string")
      .sort((x, y) => (Number(x.id) || 0) - (Number(y.id) || 0))
      .map(j => ({ name: j.name, status: j.status, allowed: j.allow_failure === true }));
  } else {
    const gh = { success: "success", neutral: "skipped", skipped: "skipped", failure: "failed", timed_out: "failed",
      startup_failure: "failed", cancelled: "canceled", stale: "canceled", action_required: "manual" };
    jobs = objs(v).flatMap(o => Array.isArray(o.check_runs) ? o.check_runs : (typeof o.name === "string" ? [o] : []))
      .filter(c => c && typeof c.name === "string")
      .map(c => ({ name: c.name, allowed: false,
        status: c.status !== "completed" ? (c.status === "in_progress" ? "running" : "pending") : (gh[c.conclusion] || "failed") }));
  }
}
// A job that waits for the verdict itself (the "Verdict names the current
// head" check) is never evidence about the code.
if (jobs) jobs = jobs.filter(j => !/verdict/i.test(j.name));
const done = s => ["success", "skipped", "manual"].includes(s);
const bad = s => ["failed", "canceled"].includes(s);
let line = "**Pipeline at posting (generated):** " + label;
if (jobs) line += " — " + (jobs.length ? jobs.map(j => `${clean(j.name)} ${clean(j.status)}${j.allowed ? " (allowed to fail)" : ""}`).join(" · ") : "no jobs");
const reasons = []; let final = false;
if (jobs && jobs.length) {
  // Only the words the reviewer wrote: fenced blocks and block quotes are quotations.
  let quoted = false;
  const prose = body.split(/\r?\n/).map(l => {
    const t = l.trim();
    if (/^(```|~~~)/.test(t)) { quoted = !quoted; return ""; }
    return quoted || t.startsWith(">") ? "" : l;
  }).join("\n");
  const esc = s => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const names = [...new Set(jobs.map(j => j.name))].filter(n => n.trim().length >= 2);
  for (const name of names) {
    const re = new RegExp("(?:^|[^A-Za-z0-9_.-])" + esc(name) + "(?![A-Za-z0-9_-])[`*\"\\x27]*\\s*" +
      "(?:(?:[:=]|->|→|—|–|-)\\s*|(?:is|are|was|were)\\s+)*[`*\"\\x27]*\\s*(?:✅|green|passed|passing|succeeded|successful|success)(?![A-Za-z])", "i");
    if (!re.test(prose)) continue;
    for (const j of jobs.filter(x => x.name === name && x.status !== "success")) {
      reasons.push(`the verdict calls "${clean(name)}" green, but at posting its status is ${clean(j.status)}`);
      if (bad(j.status) || done(j.status)) final = true;
    }
  }
  const marker = body.match(/<!--\s*factory-review:step=review(?=\s|-->)([\s\S]*?)-->/);
  const outcome = marker ? ((marker[1].match(/(?:^|\s)outcome=(\S+)/) || [])[1] || "") : "";
  if (outcome === "merge-ready") {
    for (const j of jobs.filter(x => !x.allowed && !done(x.status))) {
      reasons.push(`outcome=merge-ready, but at posting "${clean(j.name)}" is ${clean(j.status)} (a job that is not allowed to fail)`);
      if (bad(j.status)) final = true;
    }
  }
}
console.log(line);
for (const r of reasons) console.log(r);
if (reasons.length) process.exit(final ? 4 : 5);
try { fs.writeFileSync(a4, body + (body.endsWith("\n") ? "" : "\n") + "\n" + line + "\n"); } catch (e) { process.exit(3); }
'@

$tmpFiles = [System.Collections.Generic.List[string]]::new()
$tmpFiles.Add($script:errFile)
function New-TempFile { $f = [System.IO.Path]::GetTempFileName(); $tmpFiles.Add($f); return $f }
function Remove-TempFiles { foreach ($f in $tmpFiles) { Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue } }

# All thread comments (GitLab notes; GitHub reviews + issue comments) written
# to a file as concatenated JSON. Fails closed: an unreadable thread is exit 2.
function Read-Thread {
    $out = [System.Collections.Generic.List[string]]::new()
    if ($provider -eq 'gitlab') {
        # Every page: the newest 100 notes are not the whole thread (SF-FIX-11).
        $r = Api @('--paginate', "projects/$p/merge_requests/$iid/notes?sort=desc&order_by=created_at&per_page=100")
        if ($LASTEXITCODE -ne 0) { $why = Get-Why; Remove-TempFiles; Die "cannot read the notes of $mr — $why" }
        $out.Add((@($r) -join "`n"))
    } else {
        $r = Api @('--paginate', "repos/$project/pulls/$iid/reviews?per_page=100")
        if ($LASTEXITCODE -ne 0) { $why = Get-Why; Remove-TempFiles; Die "cannot read the reviews of $mr — $why" }
        $out.Add((@($r) -join "`n"))
        $c = Api @('--paginate', "repos/$project/issues/$iid/comments?per_page=100")
        if ($LASTEXITCODE -ne 0) { $why = Get-Why; Remove-TempFiles; Die "cannot read the comments of $mr — $why" }
        $out.Add((@($c) -join "`n"))
    }
    $f = New-TempFile
    [System.IO.File]::WriteAllText($f, ($out -join "`n"))
    return $f
}

# The id of a verdict for $headSha (run $Run, iter $Iter when given) on the
# thread, or '' when there is none. Exits 2 when the thread cannot be read.
function Find-Verdict([string]$Run, [string]$Iter) {
    $f = Read-Thread
    $id = node -e $findJs $f $headSha $Run $Iter
    if ($LASTEXITCODE -ne 0) { Remove-TempFiles; Die "cannot parse the comments of $mr" }
    return ([string](@($id) -join '')).Trim()
}

if ($checkOnly) {
    if ($bodyFile) { Die '--check-only takes no --body-file' }
    $id = Find-Verdict $runFilter ''
    Remove-TempFiles
    if ($id) {
        Write-Output "post-verdict: OK — verdict for head=$headSha is on $mr (comment $id)"
        exit 0
    }
    $runNote = if ($runFilter) { " run=$runFilter" } else { '' }
    Write-Output "post-verdict: MISSING — no factory-review verdict for head=$headSha$runNote on $mr"
    exit 1
}

if (-not $bodyFile -or -not (Test-Path -LiteralPath $bodyFile -PathType Leaf)) { Die '--body-file <file> is required and must exist' }
$fields = node -e $markerJs $bodyFile
if ($LASTEXITCODE -ne 0) { Die 'cannot read --body-file' }
$parts = ([string](@($fields) -join '')).Split("`t")
$count = $parts[0]; $firstOk = $parts[1]; $bodyHead = $parts[2]; $bodyRun = $parts[3]; $bodyIter = $parts[4]
if ($count -ne '1') { Die "the body must carry exactly one factory-review:step=review marker (found $count)" }
if ($firstOk -ne 'yes') { Die 'the marker must be the first non-blank line of the body' }
if ($bodyHead -cne $headSha) { Die "the marker names head=$bodyHead but --head is $headSha" }
if ($bodyRun -eq '-') { Die 'the marker carries no run=' }
if ($bodyRun -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._-]*\z') { Die "the marker's run=$bodyRun is not a valid run id" }
if ($bodyIter -eq '-') { $bodyIter = '' }
# The full schema — marker fields, run id, counts, headings, wording
# (SF-SKILL-02). A body that fails it is never sent.
$lintOut = & (Join-Path $PSScriptRoot 'verdict-schema.ps1') lint $bodyFile
if ($LASTEXITCODE -ne 0) {
    foreach ($l in @($lintOut)) { [Console]::Error.WriteLine([string]$l) }
    Die 'the body does not follow the verdict schema (verdict-schema.ps1 lint); nothing was posted'
}

$id = Find-Verdict $bodyRun $bodyIter
if ($id) {
    Remove-TempFiles
    Write-Output "post-verdict: OK — already on $mr (comment $id), not posted twice"
    exit 0
}

# Sets $script:jobsArg (a file with the head's jobs, or '-') and $script:label
# (what the generated line says about the pipeline). Never fails: an
# unreadable pipeline is stated in the label and posting goes on as before.
function Read-Pipeline {
    $script:jobsArg = '-'
    if ($provider -eq 'gitlab') {
        $r = Api @("projects/$p/pipelines?sha=$headSha&order_by=id&sort=desc&per_page=1")
        if ($LASTEXITCODE -ne 0) { $script:label = "unavailable — $(Get-Why)"; return }
        $pl = New-TempFile
        [System.IO.File]::WriteAllText($pl, (@($r) -join "`n"))
        $idst = node -e $pipelineJs id gitlab $pl
        if ($LASTEXITCODE -ne 0) { $script:label = 'unavailable — the pipeline list was not JSON'; return }
        $idst = ([string](@($idst) -join '')).Trim()
        if (-not $idst) { $script:label = "no pipeline for head $($headSha.Substring(0, 8))"; return }
        $parts = $idst -split "`t", 2
        $id = $parts[0]; $st = $parts[1]
        $script:label = "#$id $st"
        $j = Api @('--paginate', "projects/$p/pipelines/$id/jobs?per_page=100")
        if ($LASTEXITCODE -ne 0) { $script:label = "#$id $st — jobs unavailable — $(Get-Why)"; return }
    } else {
        $j = Api @('--paginate', "repos/$project/commits/$headSha/check-runs?per_page=100")
        if ($LASTEXITCODE -ne 0) { $script:label = "unavailable — $(Get-Why)"; return }
        $script:label = "check runs on $($headSha.Substring(0, 8))"
    }
    $jf = New-TempFile
    [System.IO.File]::WriteAllText($jf, (@($j) -join "`n"))
    $script:jobsArg = $jf
}

# The verdict as it is posted: the body plus the generated pipeline line.
# Refuses (exit 2) a body the pipeline contradicts; see the header.
$finalBody = New-TempFile
$waited = 0
$poll = 30
if ($env:POST_VERDICT_PIPELINE_POLL -cmatch '^[0-9]{1,4}\z') { $poll = [int]$env:POST_VERDICT_PIPELINE_POLL }
while ($true) {
    Read-Pipeline
    $gateOut = @(node -e $pipelineJs eval $provider $bodyFile $script:jobsArg $script:label $finalBody)
    $gateRc = $LASTEXITCODE
    if ($gateRc -eq 0) { break }
    if ($gateRc -ne 4 -and $gateRc -ne 5) { Remove-TempFiles; Die "cannot evaluate the pipeline of head=$headSha (exit $gateRc)" }
    if ($gateRc -eq 5 -and $waited -lt $pipelineWait) {
        [Console]::Error.WriteLine("post-verdict: the pipeline has not finished; reading it again in ${poll}s (waited ${waited}s of ${pipelineWait}s)")
        Start-Sleep -Seconds $poll
        $waited += [Math]::Max($poll, 1)
        continue
    }
    foreach ($l in @($gateOut | Select-Object -Skip 1)) { [Console]::Error.WriteLine("post-verdict: $l") }
    [Console]::Error.WriteLine("post-verdict: $([string]($gateOut | Select-Object -First 1))")
    Remove-TempFiles
    if ($gateRc -eq 5) {
        Die 'the verdict states a result the pipeline does not have yet; nothing was posted — post when the pipeline has finished (re-run with --pipeline-wait <seconds>), or say the job is still running'
    }
    Die 'the verdict contradicts the pipeline at posting; nothing was posted — correct the verdict to match the jobs above'
}

$payloadFile = New-TempFile
if ($provider -eq 'gitlab') {
    node -e 'require("fs").writeFileSync(process.argv[2], JSON.stringify({body: require("fs").readFileSync(process.argv[1], "utf8")}))' $finalBody $payloadFile
} else {
    node -e 'require("fs").writeFileSync(process.argv[2], JSON.stringify({body: require("fs").readFileSync(process.argv[1], "utf8"), event: "COMMENT", commit_id: process.argv[3]}))' $finalBody $payloadFile $headSha
}
if ($LASTEXITCODE -ne 0) { Remove-TempFiles; Die 'cannot build the request body' }

for ($attempt = 1; $attempt -le $retries; $attempt++) {
    if ($attempt -gt 1) {
        $id = Find-Verdict $bodyRun $bodyIter
        if ($id) {
            Remove-TempFiles
            Write-Output "post-verdict: OK — posted and confirmed on $mr (comment $id, head=$headSha, run=$bodyRun)"
            exit 0
        }
    }
    if ($provider -eq 'gitlab') {
        Api @('-X', 'POST', "projects/$p/merge_requests/$iid/discussions", '-H', 'Content-Type: application/json', '--input', $payloadFile) | Out-Null
    } else {
        Api @('-X', 'POST', "repos/$project/pulls/$iid/reviews", '--input', $payloadFile) | Out-Null
    }
    if ($LASTEXITCODE -ne 0) { [Console]::Error.WriteLine("post-verdict: attempt ${attempt}: the tracker refused the post — $(Get-Why)") }
    $id = Find-Verdict $bodyRun $bodyIter
    if ($id) {
        Remove-TempFiles
        Write-Output "post-verdict: OK — posted and confirmed on $mr (comment $id, head=$headSha, run=$bodyRun)"
        exit 0
    }
    if ($attempt -lt $retries) {
        $backoff = if ($env:POST_VERDICT_BACKOFF -cmatch '^[0-9]+\z') { [int]$env:POST_VERDICT_BACKOFF } else { $attempt * 5 }
        Start-Sleep -Seconds $backoff
    }
}
Remove-TempFiles
[Console]::Error.WriteLine("post-verdict: FAIL — the verdict for head=$headSha is not on $mr after $retries attempt(s); the review failed")
exit 1
