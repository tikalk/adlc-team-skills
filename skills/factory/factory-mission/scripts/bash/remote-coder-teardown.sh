#!/usr/bin/env bash
# remote-coder-teardown.sh — teardown gate for the remote:coder lane.
# Never auto-deletes: requires developer `done` + explicit confirm.
# Naming enforced here: <repo>-mission-<issue> (lowercase, digits, dashes —
# the same shape the provider transport normalizes a workspace name to).
# Usage: remote-coder-teardown.sh <workspace> [--yes]
set -euo pipefail

WORKSPACE="${1:?usage: $0 <workspace> [--yes]}"
CONFIRM="${2:-}"

command -v coder >/dev/null || { echo "ERROR: coder CLI not found." >&2; exit 127; }

# The lane names workspaces <repo>-mission-<issue>. The transport normalizes
# names to [a-z0-9-], so the repo and issue segments may carry dashes too.
if [[ ! "$WORKSPACE" =~ ^[a-z0-9][a-z0-9-]*-mission-[a-z0-9][a-z0-9-]*$ ]]; then
  echo "REFUSE: '$WORKSPACE' does not match <repo>-mission-<issue>." >&2
  echo "Teardown only touches lane-managed workspaces." >&2
  exit 3
fi

# "not found" and "the API call failed" must not look alike: a failed lookup
# (expired token, wrong org, outage) would otherwise report "nothing to
# delete" while the workspace keeps running and billing.
#
# --all matters: `coder list` defaults to owner:me, so a workspace owned by
# another identity would be absent from the list and look "not found" while
# it keeps running.
# stdout and stderr are captured separately: a warning on stderr must not
# turn a good JSON payload into a "lookup failed".
LIST_ERR="$(mktemp)"
if ! LIST_OUT="$(coder list --all --output json 2>"$LIST_ERR")"; then
  echo "ERROR: could not list workspaces (the lookup failed, not an empty result):" >&2
  cat "$LIST_ERR" >&2
  rm -f "$LIST_ERR"
  echo "Workspace '$WORKSPACE' NOT deleted — resolve the Coder API error and retry." >&2
  exit 4
fi
if [ -s "$LIST_ERR" ]; then
  echo "Warning: the workspace lookup reported:" >&2
  cat "$LIST_ERR" >&2
fi
rm -f "$LIST_ERR"

# Parse the payload — a raw grep would treat a malformed/HTML response as an
# empty list (and an unparseable payload as "nothing to delete").
FOUND="$(printf '%s' "$LIST_OUT" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    print("PARSE_ERROR")
    raise SystemExit(0)
if not isinstance(data, list):
    print("PARSE_ERROR")
    raise SystemExit(0)
target = sys.argv[1]
for item in data:
    if isinstance(item, dict) and item.get("name") == target:
        print("FOUND")
        raise SystemExit(0)
print("ABSENT")
' "$WORKSPACE" 2>/dev/null)"

case "$FOUND" in
  PARSE_ERROR)
    echo "ERROR: could not parse the workspace list (the lookup failed, not an empty result)." >&2
    echo "Workspace '$WORKSPACE' NOT deleted — resolve the Coder API error and retry." >&2
    exit 4
    ;;
  ABSENT)
    echo "Workspace '$WORKSPACE' not found — nothing to delete."
    exit 0
    ;;
esac

# Exit codes: 0 deleted, or nothing to delete | 3 refused (not a lane
# workspace) | 4 lookup failed (not deleted) | 5 delete failed | 6 gate
# waiting (not confirmed). Only "deleted" or "nothing to delete" exits 0 —
# a waiting or failed teardown never does.
if [ "$CONFIRM" != "--yes" ]; then
  echo "Teardown gate: type 'done' in the shared shell, then re-run with --yes."
  echo "Workspace '$WORKSPACE' left running."
  exit 6
fi

if coder delete "$WORKSPACE" --yes; then
  echo "deleted: $WORKSPACE"
  exit 0
fi
echo "ERROR: coder delete failed — workspace '$WORKSPACE' may still be running." >&2
exit 5
