#!/usr/bin/env bash
# resolve-mr-ownership.sh — resolve MR/PR milestone + assignee propagation
# (the MR-ownership decision; ADR-432 chain; PowerShell twin:
# scripts/powershell/resolve-mr-ownership.ps1).
#
# The orchestrator opens (or reuses) the draft MR. This resolver decides what
# ownership fields that MR should carry, so the decision is a deterministic
# computation rather than an in-prompt judgement. The connector still performs
# every tracker call; this only answers *what to set, what to skip, and what
# to block on*.
#
# Usage:
#   resolve-mr-ownership.sh <payload.json>
#   ... | resolve-mr-ownership.sh          # payload on stdin
#
# Input (JSON), output (JSON on stdout) and the five locked rulings —
# all providers, silent skip, fallback chain, preserve-only, block on
# error — are pinned by tests/unit/test_resolve_mr_ownership.py, which
# runs both twins.
set -euo pipefail

die() { echo "resolve-mr-ownership: $*" >&2; exit 2; }

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  cat <<'USAGE'
resolve-mr-ownership.sh — resolve MR/PR milestone + assignee propagation

Usage:
  resolve-mr-ownership.sh <payload.json>
  ... | resolve-mr-ownership.sh          # payload on stdin

Input (JSON): provider, issue, mr, initiator, runner, denied_scope.
Output (JSON): action (set|skip|block), milestone, milestone_field,
assignee, assignee_field, reason.
USAGE
  exit 0
fi

if [ $# -gt 1 ]; then die "expected at most one payload JSON path (or payload on stdin)"; fi

payload=""
if [ $# -eq 1 ]; then
  [ -r "$1" ] || die "cannot read input: $1"
  payload="$(cat "$1")"
else
  payload="$(cat)"
fi

# node is the JSON engine (same dependency as open-mr.sh); the decision logic
# below is the bash twin's single source of truth. The quoted heredoc keeps
# the JS readable (apostrophes and template literals included).
RESOLVER_JS="$(cat <<'NODE_EOF'
const fs = require("node:fs");
const raw = fs.readFileSync(0, "utf8");
let payload;
try { payload = JSON.parse(raw); } catch { console.error("resolve-mr-ownership: invalid payload JSON"); process.exit(2); }
if (payload === null || typeof payload !== "object" || Array.isArray(payload)) {
  console.error("resolve-mr-ownership: expected a JSON object payload"); process.exit(2);
}
const PROVIDERS = {
  gitlab: { milestone_field: "milestone_id", milestone_source: "milestone_id", assignee_field: "assignee_ids" },
  github: { milestone_field: "milestone", milestone_source: "milestone.number", assignee_field: "assignees" },
  jira:   { milestone_field: null, milestone_source: null, assignee_field: "assignee" },
  linear: { milestone_field: null, milestone_source: null, assignee_field: "assigneeId" },
};
function readMilestone(issue, source) {
  if (source === null) return null;
  if (source === "milestone.number") {
    const m = issue.milestone;
    if (m !== null && typeof m === "object" && !Array.isArray(m)) {
      return (m.number === undefined || m.number === null) ? null : m.number;
    }
    return (m === undefined) ? null : m;
  }
  const v = issue[source];
  return (v === "" || v === null || v === undefined) ? null : v;
}
function mrFieldEmpty(mr, field) {
  if (field === null) return true;
  const v = mr[field];
  if (v === null || v === undefined) return true;
  if (Array.isArray(v)) return v.length === 0;
  if (typeof v === "object") return Object.keys(v).length === 0;
  if (typeof v === "string") return v.length === 0;
  return false;
}
function firstCandidate(initiator, issueAssignees, runner) {
  if (initiator) return initiator;
  if (Array.isArray(issueAssignees)) {
    for (const c of issueAssignees) if (c) return c;
  }
  if (runner) return runner;
  return null;
}
function resolve(p) {
  const provider = String(p.provider || "").toLowerCase();
  const adapter = PROVIDERS[provider];
  if (!adapter) {
    return { action: "block", milestone: null, milestone_field: null, assignee: null, assignee_field: null,
      reason: `unknown provider '${provider}' — expected one of ${Object.keys(PROVIDERS).sort().join(", ")}` };
  }
  const issue = (p.issue && typeof p.issue === "object" && !Array.isArray(p.issue)) ? p.issue : {};
  const mr = (p.mr && typeof p.mr === "object" && !Array.isArray(p.mr)) ? p.mr : {};
  if (p.denied_scope) {
    return { action: "block", milestone: null, milestone_field: null, assignee: null, assignee_field: null,
      reason: `missing ${p.denied_scope} scope for ${provider} — the run cannot read the Issue or write the MR's ` +
        `ownership fields. Grant the scope and re-run; the factory never guesses a milestone or an assignee it ` +
        `could not verify.` };
  }
  const notes = [];
  let milestone = null, milestone_field = null;
  if (adapter.milestone_field === null) {
    notes.push(`${provider} has no milestone concept — milestone is a permanent no-op`);
  } else {
    const value = readMilestone(issue, adapter.milestone_source);
    if (value === null) {
      notes.push("Issue has no milestone — skipped");
    } else if (!mrFieldEmpty(mr, adapter.milestone_field)) {
      notes.push(`MR already has a ${adapter.milestone_field} — preserved`);
    } else {
      milestone = value; milestone_field = adapter.milestone_field;
    }
  }
  let assignee = null, assignee_field = null;
  if (!mrFieldEmpty(mr, adapter.assignee_field)) {
    notes.push(`MR already has an ${adapter.assignee_field} — preserved`);
  } else {
    assignee = firstCandidate(p.initiator, issue.assignees, p.runner);
    if (assignee === null) {
      notes.push("no assignee candidate (no initiator, no Issue assignee, no runner identity) — skipped");
    } else {
      assignee_field = adapter.assignee_field;
    }
  }
  const action = (milestone !== null || assignee !== null) ? "set" : "skip";
  const reason = notes.length ? notes.join("; ") : "milestone and assignee propagated";
  return { action: action, milestone: milestone, milestone_field: milestone_field,
    assignee: assignee, assignee_field: assignee_field, reason: reason };
}
console.log(JSON.stringify(resolve(payload), null, 2));
NODE_EOF
)"

printf '%s' "$payload" | node -e "$RESOLVER_JS"
