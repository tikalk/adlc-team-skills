#!/usr/bin/env bash
# remote-coder-env-sync.sh — env sync for the remote:coder lane (ADR-006).
# Primary: generated workspace.yml + `adlc-cli workspace setup` remotely.
# Fallback: remote-coder-env-sync-fallback.sh (frozen) on non-zero exit.
# Secrets travel env-only; never interpolated into remote commands.
# Usage: remote-coder-env-sync.sh <workspace> <repo_url> <branch> <brief_path> [--dirty-ok]
set -euo pipefail

WORKSPACE="${1:?usage: $0 <workspace> <repo_url> <branch> <brief_path> [--dirty-ok]}"
REPO_URL="${2:?missing repo_url}"
BRANCH="${3:?missing branch}"
BRIEF="${4:?missing brief_path}"
DIRTY_OK="${5:-}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE="$SCRIPT_DIR/../../references/remote-workspace.yml.template"
FALLBACK="$SCRIPT_DIR/remote-coder-env-sync-fallback.sh"

REPO_DIR="$(basename "$REPO_URL" .git)"
RUN_ID="$(basename "$(dirname "$BRIEF")")"

if [ -z "$DIRTY_OK" ]; then
  if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    echo "WARN: local tree dirty — uncommitted changes will NOT be in workspace." >&2
    exit 2
  fi
  if [ -n "$(git rev-list '@{u}..HEAD' 2>/dev/null)" ]; then
    echo "WARN: local branch has unpushed commits — they will NOT be in workspace." >&2
    exit 2
  fi
fi

for f in "$BRIEF" "$TEMPLATE"; do
  if [ ! -s "$f" ]; then
    echo "ERROR: '$f' missing or empty." >&2
    exit 2
  fi
done

command -v coder >/dev/null || { echo "ERROR: coder CLI not found." >&2; exit 127; }
trap 'rm -f "$WORKSPACE_YML"' EXIT
sed -e "s|{{run_id}}|$RUN_ID|g" -e "s|{{repo_url}}|$REPO_URL|g" \
    -e "s|{{repo_dir}}|$REPO_DIR|g" -e "s|{{branch}}|$BRANCH|g" \
    "$TEMPLATE" > "$WORKSPACE_YML"

REMOTE_WS_YML=".adlc/workflows/runs/$RUN_ID/workspace.yml"
REMOTE_BRIEF=".adlc/workflows/runs/$RUN_ID/brief.md"

coder ssh "$WORKSPACE" -- "mkdir -p '$REPO_DIR/$(dirname "$REMOTE_WS_YML")'" < /dev/null
coder ssh "$WORKSPACE" -- "cat > '$REPO_DIR/$REMOTE_WS_YML'" < "$WORKSPACE_YML"
coder ssh "$WORKSPACE" -- "cat > '$REPO_DIR/$REMOTE_BRIEF'" < "$BRIEF"

if coder ssh "$WORKSPACE" -- "cd ~ && adlc-cli workspace setup 'coder/.adlc/workflows/runs/$RUN_ID/workspace.yml' -a opencode -y"; then
  echo "env-sync complete (workspace-setup): $WORKSPACE / $REPO_DIR@$BRANCH"
else
  echo "WARN: workspace setup failed — falling back to legacy script." >&2
  exec bash "$FALLBACK" "$WORKSPACE" "$REPO_URL" "$BRANCH" "$BRIEF" --dirty-ok
fi
