#!/usr/bin/env bash
# remote-coder-env-sync.sh — env sync for the remote:coder lane.
# Order (deterministic): clone → skills → events → env → brief.
# Secrets travel env-only; never interpolated into remote commands.
# Usage: remote-coder-env-sync.sh <workspace> <repo_url> <branch> <brief_path> [--dirty-ok]
set -euo pipefail

WORKSPACE="${1:?usage: $0 <workspace> <repo_url> <branch> <brief_path> [--dirty-ok]}"
REPO_URL="${2:?missing repo_url}"
BRANCH="${3:?missing branch}"
BRIEF="${4:?missing brief_path}"
DIRTY_OK="${5:-}"

REPO_DIR="$(basename "$REPO_URL" .git)"

if [ -z "$DIRTY_OK" ] && [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  echo "WARN: local tree dirty — uncommitted changes will NOT be in workspace." >&2
  echo "      commit/stash first, or re-run with --dirty-ok." >&2
  exit 2
fi

ssh() { coder ssh "$WORKSPACE" -- "$@"; }

echo "==> [1/5] clone $REPO_URL@$BRANCH"
ssh "if [ -d $REPO_DIR/.git ]; then git -C $REPO_DIR fetch origin; else git clone --branch $BRANCH $REPO_URL $REPO_DIR; fi"

echo "==> [2/5] skills install"
ssh "cd $REPO_DIR && (command -v adlc-cli >/dev/null && adlc-cli skills add tikalk/adlc-team-skills || npm i -g adlc-cli@2.3.0 --silent) 2>&1 | tail -1"

echo "==> [3/5] events wiring"
ssh "cd $REPO_DIR && test -f .events.json && echo 'events present' || echo 'WARN: no .events.json (hooks inactive)'"

echo "==> [4/5] env config (env-driven, never baked)"
ssh "cd $REPO_DIR && printenv | grep -E '^(CODER_|GITLAB_|AGENT_|TASK_)' | sed 's/=.*/=<set>/' || echo 'no lane env set (expected pre-launch)'"

echo "==> [5/5] brief on disk"
REMOTE_BRIEF="runs/$(basename "$(dirname "$BRIEF")")/brief.md"
ssh "mkdir -p $REPO_DIR/$(dirname "$REMOTE_BRIEF")"
coder scp "$BRIEF" "$WORKSPACE:$REPO_DIR/$REMOTE_BRIEF"
ssh "test -s $REPO_DIR/$REMOTE_BRIEF && echo 'brief present'"

echo "env-sync complete: $WORKSPACE / $REPO_DIR@$BRANCH"
