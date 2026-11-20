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
# --check-only posts nothing: it only answers "is a verdict for this head (and
# this run, with --run) on the thread?" — the question a lane step asks after
# the agent has exited.
#
# Exit codes:
#   0  the verdict is on the thread (posted now, or already there)
#   1  not on the thread after all retries (posting mode) / not found (check)
#   2  usage error, invalid body, or the tracker could not be read
# node is the JSON engine (same scripts as the bash twin).

$ErrorActionPreference = 'Stop'
$script:ErrorView = 'ConciseView'

function Die([string]$Message) {
    [Console]::Error.WriteLine("post-verdict: $Message")
    exit 2
}

$mr = ''; $headSha = ''; $bodyFile = ''; $checkOnly = $false; $retries = 3; $runFilter = ''
for ($i = 0; $i -lt $args.Count; $i++) {
    $a = [string]$args[$i]
    $next = if ($i + 1 -lt $args.Count) { [string]$args[$i + 1] } else { '' }
    switch -CaseSensitive ($a) {
        '--mr'         { if (-not $next) { Die '--mr requires a value' }; $mr = $next; $i++; continue }
        '--head'       { if (-not $next) { Die '--head requires a value' }; $headSha = $next; $i++; continue }
        '--body-file'  { if (-not $next) { Die '--body-file requires a value' }; $bodyFile = $next; $i++; continue }
        '--retries'    { if ($next -cnotmatch '^[1-9]\z') { Die '--retries takes 1-9' }; $retries = [int]$next; $i++; continue }
        '--run'        { if (-not $next) { Die '--run requires a value' }; $runFilter = $next; $i++; continue }
        '--check-only' { $checkOnly = $true; continue }
        { $_ -in @('-h', '--help') } {
            Get-Content -LiteralPath $PSCommandPath | Select-Object -Skip 1 -First 38 | ForEach-Object { $_ -replace '^# ?', '' }
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

function Api([string[]]$ApiArgs) {
    if ($provider -eq 'gitlab') { glab api --hostname $apiHost @ApiArgs } else { gh api --hostname github.com @ApiArgs }
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

$tmpFiles = [System.Collections.Generic.List[string]]::new()
function New-TempFile { $f = [System.IO.Path]::GetTempFileName(); $tmpFiles.Add($f); return $f }
function Remove-TempFiles { foreach ($f in $tmpFiles) { Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue } }

# All thread comments (GitLab notes; GitHub reviews + issue comments) written
# to a file as concatenated JSON. Fails closed: an unreadable thread is exit 2.
function Read-Thread {
    $out = [System.Collections.Generic.List[string]]::new()
    if ($provider -eq 'gitlab') {
        $r = Api @("projects/$p/merge_requests/$iid/notes?sort=desc&order_by=created_at&per_page=100") 2>$null
        if ($LASTEXITCODE -ne 0) { Remove-TempFiles; Die "cannot read the notes of $mr" }
        $out.Add((@($r) -join "`n"))
    } else {
        $r = Api @('--paginate', "repos/$project/pulls/$iid/reviews?per_page=100") 2>$null
        if ($LASTEXITCODE -ne 0) { Remove-TempFiles; Die "cannot read the reviews of $mr" }
        $out.Add((@($r) -join "`n"))
        $c = Api @('--paginate', "repos/$project/issues/$iid/comments?per_page=100") 2>$null
        if ($LASTEXITCODE -ne 0) { Remove-TempFiles; Die "cannot read the comments of $mr" }
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

$payloadFile = New-TempFile
if ($provider -eq 'gitlab') {
    node -e 'require("fs").writeFileSync(process.argv[2], JSON.stringify({body: require("fs").readFileSync(process.argv[1], "utf8")}))' $bodyFile $payloadFile
} else {
    node -e 'require("fs").writeFileSync(process.argv[2], JSON.stringify({body: require("fs").readFileSync(process.argv[1], "utf8"), event: "COMMENT", commit_id: process.argv[3]}))' $bodyFile $payloadFile $headSha
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
        Api @('-X', 'POST', "projects/$p/merge_requests/$iid/discussions", '-H', 'Content-Type: application/json', '--input', $payloadFile) *> $null
    } else {
        Api @('-X', 'POST', "repos/$project/pulls/$iid/reviews", '--input', $payloadFile) *> $null
    }
    if ($LASTEXITCODE -ne 0) { [Console]::Error.WriteLine("post-verdict: attempt ${attempt}: the tracker refused the post") }
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
