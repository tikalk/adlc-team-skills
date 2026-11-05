#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
BRANCH="${BRANCH:-$(git branch --show-current 2>/dev/null || echo 'unknown')}"
TEAM_AI_DIRECTIVES=""

# JSON output always goes through jq -n (no manual string building).

INIT_OPTIONS="${PROJECT_ROOT}/.adlc/init-options.json"
if [[ -f "$INIT_OPTIONS" ]]; then
  TEAM_AI_DIRECTIVES=$(jq -r '.team_ai_directives // empty' "$INIT_OPTIONS" 2>/dev/null || true)
fi

if [[ -z "$TEAM_AI_DIRECTIVES" ]]; then
  TEAM_AI_DIRECTIVES="${PROJECT_ROOT}/team-ai-directives"
fi

if [[ "${1:-}" == "--json" || "${1:-}" == "-Json" ]]; then
  jq -n \
    --arg repo_root "$PROJECT_ROOT" \
    --arg team_ai_directives "$TEAM_AI_DIRECTIVES" \
    --arg branch "$BRANCH" \
    '{"REPO_ROOT":$repo_root,"TEAM_AI_DIRECTIVES":$team_ai_directives,"BRANCH":$branch}'
else
  echo "REPO_ROOT=$PROJECT_ROOT"
  echo "TEAM_AI_DIRECTIVES=$TEAM_AI_DIRECTIVES"
  echo "BRANCH=$BRANCH"
fi
