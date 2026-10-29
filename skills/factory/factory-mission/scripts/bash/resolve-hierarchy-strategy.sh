#!/usr/bin/env bash
# resolve-hierarchy-strategy.sh — pick the epic hierarchy strategy from a
# capability probe result (the capability-aware hierarchy decision).
# PowerShell twin: scripts/powershell/resolve-hierarchy-strategy.ps1.
#
# The orchestrator probes the tracker before any hierarchy use. This
# resolver turns the probe result into a deterministic strategy, so the
# choice is a computation rather than an in-prompt judgement. The
# connector still performs every tracker call; this only answers
# *which shape to use and what to disclose*.
#
# Usage:
#   resolve-hierarchy-strategy.sh <payload.json>
#   ... | resolve-hierarchy-strategy.sh          # payload on stdin
#
# Input (JSON): instance, version, probe_fresh, probe_from_instance,
#   probe_from_version, capabilities {epic_type, issue_parent_task_children,
#   work_item_convert}, use_time_failure (optional: the failed operation).
# Output (JSON): strategy (native_epic | issue_parent_task_children |
#   degraded_no_tree), attach (bool), convert (bool), disclosure (string),
#   degraded (bool), reason.
#
# A stale probe, or a probe from another instance or version, counts as
# no probe: the strategy is degraded_no_tree.
set -euo pipefail

die() { echo "resolve-hierarchy-strategy: $*" >&2; exit 2; }

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  cat <<'USAGE'
resolve-hierarchy-strategy.sh — pick the epic hierarchy strategy

Usage:
  resolve-hierarchy-strategy.sh <payload.json>
  ... | resolve-hierarchy-strategy.sh          # payload on stdin

Input (JSON): instance, version, probe_fresh, probe_from_instance,
  probe_from_version, capabilities, use_time_failure (optional).
Output (JSON): strategy, attach, convert, disclosure, degraded, reason.
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

# node is the JSON engine (same dependency as open-mr.sh and
# resolve-mr-ownership.sh); the decision logic below is the bash twin's
# single source of truth.
RESOLVER_JS="$(cat <<'NODE_EOF'
const fs = require("node:fs");
const raw = fs.readFileSync(0, "utf8");
let payload;
try { payload = JSON.parse(raw); } catch { console.error("resolve-hierarchy-strategy: invalid payload JSON"); process.exit(2); }
if (payload === null || typeof payload !== "object" || Array.isArray(payload)) {
  console.error("resolve-hierarchy-strategy: expected a JSON object payload"); process.exit(2);
}
const instance = payload.instance || "unknown instance";
const version = payload.version || "unknown version";
const caps = payload.capabilities || {};
const fresh = payload.probe_fresh === true;
const sameTarget = (payload.probe_from_instance === payload.instance) && (payload.probe_from_version === payload.version);
const useFail = payload.use_time_failure || null;

function disclosureLine(strategy) {
  return "Hierarchy probe on " + instance + " " + version + ": strategy " + strategy + ".";
}

let out;
if (!fresh || !sameTarget) {
  out = {
    strategy: "degraded_no_tree",
    attach: false,
    convert: false,
    disclosure: disclosureLine("degraded_no_tree") + " Probe is stale or from another target; no hierarchy used.",
    degraded: true,
    reason: "stale-or-foreign probe counts as no probe",
  };
} else if (useFail) {
  out = {
    strategy: "degraded_no_tree",
    attach: false,
    convert: false,
    disclosure: disclosureLine("degraded_no_tree") + " Hierarchy operation " + useFail + " failed at use time; fell back for this epic only.",
    degraded: true,
    reason: "use-time failure downgrades only the affected epic",
  };
} else if (caps.epic_type === true) {
  out = {
    strategy: "native_epic",
    attach: true,
    convert: false,
    disclosure: disclosureLine("native_epic") + " Native epic type carries the children; no conversion needed.",
    degraded: false,
    reason: "best available: native epic type",
  };
} else if (caps.issue_parent_task_children === true) {
  out = {
    strategy: "issue_parent_task_children",
    attach: true,
    convert: caps.work_item_convert === true,
    disclosure: disclosureLine("issue_parent_task_children") + " Issue parent holds Task children" + (caps.work_item_convert === true ? "; children convert from Issue to Task and the plan output names the trade-off." : ".") ,
    degraded: false,
    reason: "best available: issue parent with task children",
  };
} else {
  out = {
    strategy: "degraded_no_tree",
    attach: false,
    convert: false,
    disclosure: disclosureLine("degraded_no_tree") + " Tracker has no hierarchy support; label convention used.",
    degraded: true,
    reason: "no hierarchy capability; degraded mode, never silent",
  };
}
process.stdout.write(JSON.stringify(out) + "\n");
NODE_EOF
)"

printf '%s' "$payload" | node -e "$RESOLVER_JS"
