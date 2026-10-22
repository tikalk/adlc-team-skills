#!/usr/bin/env bash
# remote-coder-teardown.sh — teardown gate for the remote:coder lane.
# Never auto-deletes: requires the developer's "done" (--yes is that
# confirmation).
# Naming enforced here: <repo>-mission-<issue> (lowercase, digits, dashes —
# the same shape the provider transport normalizes a workspace name to).
# Usage: remote-coder-teardown.sh <workspace> [--yes]
set -euo pipefail

WORKSPACE="${1:?usage: $0 <workspace> [--yes]}"
CONFIRM="${2:-}"

command -v coder >/dev/null || { echo "ERROR: coder CLI not found." >&2; exit 127; }

if [[ ! "$WORKSPACE" =~ ^[a-z0-9][a-z0-9-]*-mission-[a-z0-9][a-z0-9-]*$ ]]; then
  echo "REFUSE: '$WORKSPACE' does not match <repo>-mission-<issue>." >&2
  echo "Teardown only touches lane-managed workspaces." >&2
  exit 3
fi

# The lane's own handle is the workspace's identity — a handle that outlives
# its workspace makes the next lane run reuse a machine that no longer exists.
HANDLE=".adlc/workspaces/${WORKSPACE}.json"

# Two lookup paths, because the caller's credentials decide which works:
#
# 1. `coder show <ws>` — works with the AGENT credentials a workspace
#    session already has. The developer runs this gate from inside the
#    workspace, where only its own workspace is visible to that token.
# 2. `coder list --all` — the broad path, needed when the workspace is
#    owned by another identity (`coder list` defaults to owner:me, so an
#    owned-elsewhere workspace would look "not found" while it keeps running).
#
# "not found" and "the API call failed" must not look alike: a failed lookup
# (expired token, wrong org, outage) would otherwise report "nothing to
# delete" while the workspace keeps running and billing.
LIST_ERR="$(mktemp)"
if SHOW_OUT="$(coder show "$WORKSPACE" 2>&1)"; then
  FOUND=yes
else
  if ! LIST_OUT="$(coder list --all --output json 2>"$LIST_ERR")"; then
    echo "ERROR: could not look up the workspace (the lookup failed, not an empty result):" >&2
    echo "$SHOW_OUT" >&2
    [ -s "$LIST_ERR" ] && cat "$LIST_ERR" >&2
    rm -f "$LIST_ERR"
    echo "Workspace '$WORKSPACE' NOT deleted — resolve the Coder API error and retry." >&2
    exit 4
  fi
  [ -s "$LIST_ERR" ] && { echo "Warning: the workspace lookup reported:" >&2; cat "$LIST_ERR" >&2; }
  rm -f "$LIST_ERR"
  # Parse the payload — a raw grep would treat a malformed/HTML response as
  # an empty list (and an unparseable payload as "nothing to delete").
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
print("FOUND" if any(isinstance(i, dict) and i.get("name") == target for i in data) else "ABSENT")
' "$WORKSPACE")"
  case "$FOUND" in
    PARSE_ERROR)
      echo "ERROR: could not parse the workspace list (the lookup failed, not an empty result)." >&2
      echo "Workspace '$WORKSPACE' NOT deleted — resolve the Coder API error and retry." >&2
      exit 4
      ;;
    ABSENT)
      rm -f "$HANDLE"
      echo "Workspace '$WORKSPACE' not found — nothing to delete."
      exit 0
      ;;
  esac
fi

if [ "$CONFIRM" != "--yes" ]; then
  echo "Teardown gate: the developer says 'done', then re-run with --yes."
  echo "Workspace '$WORKSPACE' left running."
  exit 6
fi

if coder delete "$WORKSPACE" --yes; then
  rm -f "$HANDLE"
  echo "deleted: $WORKSPACE"
  exit 0
fi
echo "ERROR: coder delete failed — workspace '$WORKSPACE' may still be running." >&2
exit 5
