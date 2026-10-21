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
if ! LIST_OUT="$(coder list --output json 2>&1)"; then
  echo "ERROR: could not list workspaces (the lookup failed, not an empty result):" >&2
  echo "$LIST_OUT" >&2
  echo "Workspace '$WORKSPACE' NOT deleted — resolve the Coder API error and retry." >&2
  exit 4
fi

if ! grep -q "\"name\": *\"$WORKSPACE\"" <<<"$LIST_OUT" && ! grep -q "\"name\":\"$WORKSPACE\"" <<<"$LIST_OUT"; then
  echo "Workspace '$WORKSPACE' not found — nothing to delete."
  exit 0
fi

if [ "$CONFIRM" != "--yes" ]; then
  echo "Teardown gate: type 'done' in the shared shell, then re-run with --yes."
  echo "Workspace '$WORKSPACE' left running."
  exit 0
fi

read -r -p "Delete workspace '$WORKSPACE'? [y/N] " answer || { echo "aborted — workspace left running."; exit 1; }
case "$answer" in
  [yY]*) coder delete "$WORKSPACE" --yes && echo "deleted: $WORKSPACE" ;;
  *) echo "aborted — workspace left running." ;;
esac
