#!/usr/bin/env pwsh
# check-proof-of-work.ps1 — every Definition-of-Done item is done with
# evidence, or disclosed as skipped / not applicable with a reason. Nothing is
# silently dropped (PowerShell twin of check-proof-of-work.sh; SF-SKILL-07).
#
# Why: a mission skipped a required DoD item (a verified screenshot from a
# staging e2e script the issue named) and wrote "not run (no staging env in
# this pod)" (octopus-next#1508, 2026-11-09); nothing compared the issue's DoD
# with what the run did.
#
# Usage: check-proof-of-work.ps1 [--ledger <json>] [--issue <group>/<project>#<iid> | --dod-file <md>]
#          [--summary-file <md>] [--fail-on-skip]
# Defaults, ledger format, output block and exit codes (0 / 3 / 1 / 2): see
# the bash twin. The checker below is the same node program as the bash
# twin's (a test keeps them identical).

$ErrorActionPreference = 'Stop'
$script:ErrorView = 'ConciseView'

function Die([string]$Message) {
    [Console]::Error.WriteLine("check-proof-of-work: $Message")
    exit 2
}

$opts = @{ ledger = ''; issue = ''; 'dod-file' = ''; 'summary-file' = '' }
$failOnSkip = '0'
for ($i = 0; $i -lt $args.Count; $i++) {
    $name = [string]$args[$i]
    if ($name -eq '--fail-on-skip') { $failOnSkip = '1'; continue }
    if ($name -notmatch '^--(ledger|issue|dod-file|summary-file)$') { Die "unknown argument '$name'" }
    if ($i + 1 -ge $args.Count) { Die "missing value for $name" }
    $i++
    $opts[$name.Substring(2)] = [string]$args[$i]
}
$ledger = $opts['ledger']; $issue = $opts['issue']; $dodFile = $opts['dod-file']; $summary = $opts['summary-file']
if ($issue -and $dodFile) { Die 'give --issue or --dod-file, not both' }
if (-not (Get-Command node -ErrorAction SilentlyContinue)) { Die 'node is required' }

if (-not $ledger -or (-not $issue -and -not $dodFile)) {
    if (-not $env:ADLC_RUN_ID -or -not $env:ADLC_ISSUE_REF) { . (Join-Path $PSScriptRoot 'run-context.ps1') }
}
if (-not $ledger) {
    if (-not $env:ADLC_RUN_ID) { Die '--ledger is required outside a factory run (no run context)' }
    if (-not ($env:ADLC_RUN_ID -cmatch '^[A-Za-z0-9][A-Za-z0-9._-]*\z')) { Die 'invalid ADLC_RUN_ID' }
    $root = git rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $root) { $root = (Get-Location).Path } else { $root = ([string]$root).Trim() }
    $ledger = Join-Path $root ".adlc/workflows/runs/$($env:ADLC_RUN_ID)/proof-of-work.json"
}
if (-not (Test-Path -LiteralPath $ledger -PathType Leaf)) { Die "no ledger at $ledger — the mission must write one entry per Definition-of-Done item" }

$descFile = [System.IO.Path]::GetTempFileName()
$code = 2
try {
    if ($dodFile) {
        if (-not (Test-Path -LiteralPath $dodFile -PathType Leaf)) { Die "--dod-file $dodFile does not exist" }
        Copy-Item -LiteralPath $dodFile -Destination $descFile -Force
    } else {
        if (-not $issue) { $issue = [string]$env:ADLC_ISSUE_REF }
        if (-not $issue) { Die 'give --issue <ref> or --dod-file <md> (no issue in the run context)' }
        if ($issue -like '*..*') { Die 'invalid --issue' }
        if (-not ($issue -cmatch '^(([A-Za-z0-9_][A-Za-z0-9._-]*/)+[A-Za-z0-9_][A-Za-z0-9._-]*)#([0-9]+)\z')) {
            Die '--issue must be <group>/<project>#<iid>'
        }
        $project = $Matches[1]; $iid = $Matches[3]
        $provider = if ($env:ISSUE_PROVIDER) { $env:ISSUE_PROVIDER } else { 'gitlab' }
        if ($provider -eq 'gitlab') {
            if (-not $env:GITLAB_HOST) { Die 'GITLAB_HOST is not set (the token is never sent to a guessed host)' }
            $glHost = ($env:GITLAB_HOST -replace '^https://', '').TrimEnd('/')
            $p = node -e 'console.log(encodeURIComponent(process.argv[1]))' $project
            $raw = glab api --hostname $glHost "projects/$p/issues/$iid" 2>$null
        } elseif ($provider -eq 'github') {
            $raw = gh api "repos/$project/issues/$iid" 2>$null
        } else {
            Die "unsupported ISSUE_PROVIDER: $provider"
        }
        if ($LASTEXITCODE -ne 0) { Die "cannot read $issue" }
        # The issue JSON goes in on stdin: a long description can exceed the
        # 128 KiB limit of one command-line argument.
        (@($raw) -join "`n") | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const o=JSON.parse(s);require("fs").writeFileSync(process.argv[1], String(o.description||o.body||""))})' $descFile
        if ($LASTEXITCODE -ne 0) { Die "cannot parse $issue" }
    }

    # The checker. Keep it identical to the one in the bash twin.
    $checker = @'
const fs = require("fs");
const [descFile, ledgerFile, summaryFile, failOnSkip] = process.argv.slice(1);
const lines = fs.readFileSync(descFile, "utf8").split(/\r?\n/);
const start = lines.findIndex(l => /^#{2,3}\s+Definition of Done\b/i.test(l.trim()));
if (start < 0) { console.error("check-proof-of-work: the issue has no `## Definition of Done` section"); process.exit(2); }
const level = lines[start].trim().match(/^#+/)[0].length;
const items = [];
for (const l of lines.slice(start + 1)) {
  const h = l.match(/^(#{1,6})\s/);
  if (h && h[1].length <= level) break;
  const m = l.match(/^\s*(?:[-*+]|\d+[.)])\s+(?:\[[ xX]\]\s+)?(.*\S)\s*$/);
  if (m) items.push(m[1]);
}
if (!items.length) { console.error("check-proof-of-work: the `Definition of Done` section lists no items"); process.exit(2); }
let ledger;
try { ledger = JSON.parse(fs.readFileSync(ledgerFile, "utf8")); } catch (e) { console.error("check-proof-of-work: the ledger is not JSON: " + e.message); process.exit(2); }
const entries = ledger && Array.isArray(ledger.items) ? ledger.items : [];
const norm = s => String(s || "").toLowerCase().replace(/\[[ x]\]/g, "").replace(/[*_`~]/g, "").replace(/\s+/g, " ").trim();
const notAReason = /^\s*(pending|todo|tbd)\b/i;
const errs = [], skipped = [], na = [];
let done = 0;
for (const it of items) {
  const e = entries.find(x => x && norm(x.item) === norm(it));
  if (!e) { errs.push(`no ledger entry for DoD item: "${it}"`); continue; }
  const st = e.status, reason = String(e.reason || "").replace(/\s+/g, " ").trim();
  if (st === "done") {
    if (!String(e.evidence || "").trim()) errs.push(`"${it}" is done but has no evidence`); else done++;
  } else if (st === "skipped" || st === "not-applicable") {
    if (!reason) errs.push(`"${it}" is ${st} without a reason`);
    else if (notAReason.test(reason)) errs.push(`"${it}": "${reason.split(" ")[0]}" is not a reason — say what was missing and what the issue asked for, or do the item`);
    else (st === "skipped" ? skipped : na).push(`- **${it}** — ${st}: ${reason}`);
  } else errs.push(`"${it}" has status "${st}" (expected done, skipped or not-applicable)`);
}
const head = `**Proof of work:** ${done} of ${items.length} Definition-of-Done item(s) done` +
  (na.length ? `, ${na.length} not applicable` : "") + (skipped.length ? `, ${skipped.length} skipped` : "") +
  (skipped.length || na.length ? ":" : ".");
const out = [head, ...skipped, ...na].join("\n") + "\n";
if (summaryFile && summaryFile !== "-") fs.writeFileSync(summaryFile, out);
process.stdout.write(out);
if (errs.length) { for (const e of errs) console.error("check-proof-of-work: " + e); process.exit(1); }
process.exit(skipped.length ? (failOnSkip === "1" ? 1 : 3) : 0);
'@
    $summaryArg = if ($summary) { $summary } else { '-' }
    node -e $checker $descFile $ledger $summaryArg $failOnSkip
    $code = $LASTEXITCODE
} finally {
    Remove-Item -Force -LiteralPath $descFile -ErrorAction SilentlyContinue
}
exit $code
