#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
BRANCH="${BRANCH:-$(git branch --show-current 2>/dev/null || echo 'unknown')}"
TEAM_AI_DIRECTIVE=""

INIT_OPTIONS="${PROJECT_ROOT}/.adlc/init-options.json"
if [[ -f "$INIT_OPTIONS" ]]; then
  TEAM_AI_DIRECTIVE=$(python3 -c "
import json, sys
try:
    with open('$INIT_OPTIONS') as f:
        print(json.load(f).get('team_ai_directive', ''))
except Exception:
    print('')
" 2>/dev/null || true)
fi

if [[ -z "$TEAM_AI_DIRECTIVE" ]]; then
  TEAM_AI_DIRECTIVE="${PROJECT_ROOT}/team-ai-directives"
fi

if [[ "${1:-}" == "--json" || "${1:-}" == "-Json" ]]; then
  printf '{"REPO_ROOT": "%s", "TEAM_AI_DIRECTIVE": "%s", "BRANCH": "%s"}\n' \
    "$PROJECT_ROOT" "$TEAM_AI_DIRECTIVE" "$BRANCH"
else
  echo "REPO_ROOT=$PROJECT_ROOT"
  echo "TEAM_AI_DIRECTIVE=$TEAM_AI_DIRECTIVE"
  echo "BRANCH=$BRANCH"
fi
