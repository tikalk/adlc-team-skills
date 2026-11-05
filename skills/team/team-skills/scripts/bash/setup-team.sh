#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
BRANCH="${BRANCH:-$(git branch --show-current 2>/dev/null || echo 'unknown')}"
TEAM_AI_DIRECTIVES=""

INIT_OPTIONS="${PROJECT_ROOT}/.adlc/init-options.json"
if [[ -f "$INIT_OPTIONS" ]]; then
  TEAM_AI_DIRECTIVES=$(python3 -c '
import json, sys
try:
    with open(sys.argv[1]) as f:
        value = json.load(f).get("team_ai_directives", "")
    print(value if isinstance(value, str) else "")
except Exception:
    print("")
' "$INIT_OPTIONS" 2>/dev/null || true)
fi

if [[ -z "$TEAM_AI_DIRECTIVES" ]]; then
  TEAM_AI_DIRECTIVES="${PROJECT_ROOT}/team-ai-directives"
fi

if [[ "${1:-}" == "--json" || "${1:-}" == "-Json" ]]; then
  python3 - "$PROJECT_ROOT" "$TEAM_AI_DIRECTIVES" "$BRANCH" <<'PY'
import json, sys
print(json.dumps({
  "REPO_ROOT": sys.argv[1],
  "TEAM_AI_DIRECTIVES": sys.argv[2],
  "BRANCH": sys.argv[3]
}))
PY
else
  echo "REPO_ROOT=$PROJECT_ROOT"
  echo "TEAM_AI_DIRECTIVES=$TEAM_AI_DIRECTIVES"
  echo "BRANCH=$BRANCH"
fi
