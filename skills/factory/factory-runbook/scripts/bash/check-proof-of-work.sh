#!/usr/bin/env bash
# check-proof-of-work.sh — every Definition-of-Done item is done with evidence,
# or disclosed as skipped / not applicable with a reason. Nothing is silently
# dropped (SF-SKILL-07). PowerShell twin: ../powershell/check-proof-of-work.ps1.
#
# Why: a mission skipped a required DoD item (a verified screenshot from a
# staging e2e script the issue named) and wrote "Staging screenshot: not run
# (no staging env in this pod)" (octopus-next#1508, 2026-11-09). The only
# proof-of-work check (octopus-next workflow override) was "mr_url is not
# empty"; nothing compared the issue's DoD with what the run did. The mission
# now writes a ledger, and this command checks it against the DoD.
#
# Usage:
#   check-proof-of-work.sh [--ledger <json>] [--issue <group>/<project>#<iid> | --dod-file <md>]
#                          [--summary-file <md>] [--fail-on-skip]
#   --ledger defaults to .adlc/workflows/runs/<run id>/proof-of-work.json in the
#   project root (run id from the run context: ADLC_RUN_ID, else the lane's
#   WORKFLOW_INPUTS.run_id through run-context.sh). --issue defaults to the
#   run's issue.
#
# DoD items = the list items (`- [ ] …`, `- …`, `1. …`) under the issue's
# `## Definition of Done` heading (or `###`), up to the next heading of the
# same or a higher level.
# The ledger (written by the mission, one entry per DoD item):
#   {"items": [{"item": "<the DoD item text>", "status": "done|skipped|not-applicable",
#               "evidence": "<file:line, command + result, URL>", "reason": "<why>"}]}
# Matching ignores case, checkbox marks, markdown emphasis and spacing.
# `done` needs evidence; `skipped` / `not-applicable` need a real reason —
# "pending", "todo", "tbd" are not reasons.
#
# Output: a markdown "Proof of work" block (stdout, and --summary-file) that
# lists every skipped and not-applicable item with its reason — pass it to
# post-completion.sh --details-file.
#
# Exit codes:
#   0  every item done, or not applicable with a reason (all disclosed)
#   3  every item accounted for, but some were skipped (disclosed in the block);
#      with --fail-on-skip this is exit 1 instead (owner policy, see SKILL.md)
#   1  a DoD item has no ledger entry, or an entry lacks its evidence/reason
#   2  usage error, no run context for the default ledger, unreadable issue or
#      ledger, or no DoD section / no items found
set -uo pipefail

die() { echo "check-proof-of-work: $*" >&2; exit 2; }
here="$(cd "$(dirname "$0")" && pwd)"

LEDGER="" ISSUE="" DOD_FILE="" SUMMARY="" FAIL_ON_SKIP=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --fail-on-skip) FAIL_ON_SKIP=1; shift; continue ;;
  esac
  [ "$#" -ge 2 ] || die "missing value for $1"
  case "$1" in
    --ledger) LEDGER="$2" ;;
    --issue) ISSUE="$2" ;;
    --dod-file) DOD_FILE="$2" ;;
    --summary-file) SUMMARY="$2" ;;
    *) die "unknown argument '$1'" ;;
  esac
  shift 2
done
[ -z "$ISSUE" ] || [ -z "$DOD_FILE" ] || die "give --issue or --dod-file, not both"
command -v node >/dev/null 2>&1 || die "node is required"

if [ -z "$LEDGER" ] || { [ -z "$ISSUE" ] && [ -z "$DOD_FILE" ]; }; then
  # shellcheck source=run-context.sh
  if [ -z "${ADLC_RUN_ID:-}" ] || [ -z "${ADLC_ISSUE_REF:-}" ]; then . "$here/run-context.sh"; fi
fi
if [ -z "$LEDGER" ]; then
  [ -n "${ADLC_RUN_ID:-}" ] || die "--ledger is required outside a factory run (no run context)"
  [[ "$ADLC_RUN_ID" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || die "invalid ADLC_RUN_ID"
  LEDGER="$(git rev-parse --show-toplevel 2>/dev/null || pwd)/.adlc/workflows/runs/$ADLC_RUN_ID/proof-of-work.json"
fi
[ -f "$LEDGER" ] || die "no ledger at $LEDGER — the mission must write one entry per Definition-of-Done item"

desc_file="$(mktemp)"; trap 'rm -f "$desc_file"' EXIT
if [ -n "$DOD_FILE" ]; then
  [ -f "$DOD_FILE" ] || die "--dod-file $DOD_FILE does not exist"
  cp "$DOD_FILE" "$desc_file"
else
  [ -n "$ISSUE" ] || ISSUE="${ADLC_ISSUE_REF:-}"
  [ -n "$ISSUE" ] || die "give --issue <ref> or --dod-file <md> (no issue in the run context)"
  case "$ISSUE" in *..*) die "invalid --issue" ;; esac
  [[ "$ISSUE" =~ ^(([A-Za-z0-9_][A-Za-z0-9._-]*/)+[A-Za-z0-9_][A-Za-z0-9._-]*)#([0-9]+)$ ]] || die "--issue must be <group>/<project>#<iid>"
  project="${BASH_REMATCH[1]}"; iid="${BASH_REMATCH[3]}"
  case "${ISSUE_PROVIDER:-gitlab}" in
    gitlab)
      [ -n "${GITLAB_HOST:-}" ] || die "GITLAB_HOST is not set (the token is never sent to a guessed host)"
      host="${GITLAB_HOST#https://}"; host="${host%/}"
      p="$(node -e 'console.log(encodeURIComponent(process.argv[1]))' "$project")"
      raw="$(glab api --hostname "$host" "projects/$p/issues/$iid" 2>/dev/null)" || die "cannot read $ISSUE"
      ;;
    github) raw="$(gh api "repos/$project/issues/$iid" 2>/dev/null)" || die "cannot read $ISSUE" ;;
    *) die "unsupported ISSUE_PROVIDER: ${ISSUE_PROVIDER}" ;;
  esac
  printf '%s' "$raw" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const o=JSON.parse(s);process.stdout.write(String(o.description||o.body||""))})' > "$desc_file" \
    || die "cannot parse $ISSUE"
fi

# The checker. Keep it identical to the one in the PowerShell twin.
node -e '
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
' "$desc_file" "$LEDGER" "${SUMMARY:--}" "$FAIL_ON_SKIP"
