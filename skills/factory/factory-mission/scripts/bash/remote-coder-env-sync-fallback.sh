#!/usr/bin/env bash
# remote-coder-env-sync-fallback.sh — FROZEN fallback (60de0b5 semantics).
# Used only when `adlc-cli workspace setup` exits non-zero (ADR-006).
# Do not extend — retirement after 3 consecutive clean-setup pilots.
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

if [ -z "$DIRTY_OK" ]; then
  if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    echo "WARN: local tree dirty — uncommitted changes will NOT be in workspace." >&2
    echo "      commit/stash first, or re-run with --dirty-ok." >&2
    exit 2
  fi
  if [ -n "$(git rev-list '@{u}..HEAD' 2>/dev/null)" ]; then
    echo "WARN: local branch has unpushed commits — they will NOT be in workspace." >&2
    echo "      push first, or re-run with --dirty-ok." >&2
    exit 2
  fi
fi

if [ ! -s "$BRIEF" ]; then
  echo "ERROR: brief '$BRIEF' missing or empty — nothing to sync." >&2
  exit 2
fi

command -v coder >/dev/null || { echo "ERROR: coder CLI not found." >&2; exit 127; }

coder_exec() { coder ssh "$WORKSPACE" -- "$@"; }

echo "==> [1/5] clone $REPO_URL@$BRANCH"
coder_exec "if [ -d '$REPO_DIR'/.git ]; then git -C '$REPO_DIR' fetch origin && git -C '$REPO_DIR' checkout '$BRANCH'; else git clone --branch '$BRANCH' '$REPO_URL' '$REPO_DIR'; fi"

echo "==> [2/5] skills install"
coder_exec "cd '$REPO_DIR' && (command -v adlc-cli >/dev/null || npm i -g adlc-cli@2.3.0 --silent) && adlc-cli skills add tikalk/adlc-team-skills -a opencode -y"

echo "==> [3/5] events check"
coder_exec "cd '$REPO_DIR' && test -f .events.json && echo 'events present' || echo 'WARN: no .events.json (hooks inactive)'"

echo "==> [4/5] env check (env-driven, never baked)"
coder_exec "cd '$REPO_DIR' && printenv | grep -E '^(CODER_|GITLAB_|AGENT_|TASK_)' | sed 's/=.*/=<set>/' || echo 'no lane env set (expected pre-launch)'"

echo "==> [5/5] brief on disk"
REMOTE_BRIEF=".adlc/workflows/runs/$(basename "$(dirname "$BRIEF")")/brief.md"
coder_exec "mkdir -p '$REPO_DIR/$(dirname "$REMOTE_BRIEF")'"
coder_exec "cat > '$REPO_DIR/$REMOTE_BRIEF'" < "$BRIEF"
coder_exec "test -s '$REPO_DIR/$REMOTE_BRIEF' && echo 'brief present'"

echo "env-sync complete: $WORKSPACE / $REPO_DIR@$BRANCH"
