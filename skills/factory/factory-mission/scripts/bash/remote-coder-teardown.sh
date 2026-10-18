#!/usr/bin/env bash
# remote-coder-teardown.sh — teardown gate for the remote:coder lane.
# Never auto-deletes: requires developer `done` + explicit confirm.
# Naming enforced at create: <repo>-mission-<issue>.
# Usage: remote-coder-teardown.sh <workspace> [--yes]
set -euo pipefail

WORKSPACE="${1:?usage: $0 <workspace> [--yes]}"
CONFIRM="${2:-}"

command -v coder >/dev/null || { echo "ERROR: coder CLI not found." >&2; exit 127; }

if [[ ! "$WORKSPACE" =~ ^[a-z0-9][a-z0-9-]{0,17}-mission-[0-9]+$ ]]; then
  echo "REFUSE: '$WORKSPACE' does not match <repo>-mission-<issue>." >&2
  echo "Teardown only touches lane-managed workspaces." >&2
  exit 3
fi

if ! coder show "$WORKSPACE" >/dev/null 2>&1; then
  echo "Workspace '$WORKSPACE' not found — nothing to delete."
  exit 0
fi

if [ "$CONFIRM" != "--yes" ]; then
  echo "Teardown gate: type 'done' in the shared shell, then re-run with --yes."
  echo "Workspace '$WORKSPACE' left running."
  exit 0
fi

read -r -p "Delete workspace '$WORKSPACE'? [y/N] " answer
case "$answer" in
  [yY]*) coder delete "$WORKSPACE" --yes && echo "deleted: $WORKSPACE" ;;
  *) echo "aborted — workspace left running." ;;
esac
