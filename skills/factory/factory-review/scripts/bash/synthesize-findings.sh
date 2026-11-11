#!/usr/bin/env bash
# synthesize-findings.sh — deterministic synthesis of adversarial review
# findings (PowerShell twin: scripts/powershell/synthesize-findings.ps1).
#
# Reads findings JSON (file arg or stdin) shaped like:
# {"findings":[{"id":"F1","reports":["Auditor","Adversary"],
# "validations":[],"challenges":[],"adds":[]}, ...]}
# writes tags JSON to stdout. Deterministic: same input -> byte-identical
# output. Counting rule: >=2 *distinct* reporters -> cross-validated; 1
# report + >=1 validate from a *different* persona (no challenge) ->
# consensus; 1 report + >=1 challenge -> disputed; else solo.
# Round-2 `add` moves arrive as separate findings with the adder in
# `reports`; the script never invents findings — every `add` is already a
# record.
set -euo pipefail

die() { echo "synthesize-findings: $*" >&2; exit 2; }

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  cat <<'USAGE'
synthesize-findings.sh — deterministic synthesis of adversarial review findings

Usage:
  synthesize-findings.sh [findings.json | -]     # - or no arg reads stdin

Reads {"findings":[{"id","reports","validations","challenges"}, ...]},
writes {"tags":[{"id","tag"}]} to stdout. Tags: cross-validated (>=2
distinct reporters), consensus (1 report + validate from a different
persona, no challenge), disputed (1 report + challenge), solo.
USAGE
  exit 0
fi

if [ $# -gt 1 ]; then die "expected at most one findings JSON path"; fi

src="${1:--}"
raw=""
if [ "$src" != "-" ]; then
  [ -r "$src" ] || die "no such file: $src"
  raw="$(cat "$src")"
else
  raw="$(cat)"
fi

# node is the JSON engine; the synthesis rules below are the bash twin's
# single source of truth.
SYNTH_JS="$(cat <<'NODE_EOF'
const fs = require("node:fs");
const raw = fs.readFileSync(0, "utf8");
let data;
try { data = JSON.parse(raw); } catch (e) { console.error("synthesize-findings: invalid findings JSON: " + e.message); process.exit(2); }
if (data === null || typeof data !== "object" || Array.isArray(data) || !Array.isArray(data.findings)) {
  console.error('synthesize-findings: expected {"findings": [...]}'); process.exit(2);
}
if (data.findings.some((f) => f === null || typeof f !== "object" || Array.isArray(f))) {
  console.error("synthesize-findings: every finding must be an object"); process.exit(2);
}
function personas(value) {
  if (!Array.isArray(value)) return new Set();
  return new Set(value.filter((v) => typeof v === "string" && v));
}
function tag(f) {
  const reports = personas(f.reports);
  const validations = personas(f.validations);
  let challenges = f.challenges === undefined ? [] : f.challenges;
  if (!challenges) challenges = [];
  if (!Array.isArray(challenges)) challenges = [challenges];
  if (reports.size >= 2) return "cross-validated";
  if (reports.size === 1 && challenges.length > 0) return "disputed";
  if (reports.size === 1) {
    for (const v of validations) if (!reports.has(v)) return "consensus";
  }
  return "solo";
}
const tags = data.findings.map((f) => ({ id: f.id === undefined ? "" : f.id, tag: tag(f) }));
process.stdout.write(JSON.stringify({ tags: tags }) + "\n");
NODE_EOF
)"

printf '%s' "$raw" | node -e "$SYNTH_JS"
