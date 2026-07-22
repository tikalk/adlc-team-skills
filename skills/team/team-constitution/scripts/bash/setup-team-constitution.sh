#!/usr/bin/env bash
# setup-team-constitution.sh — Setup for team-constitution (self-contained)
set -euo pipefail

###############################################################################
# Inline path resolution (no external helper dependency)
###############################################################################

resolve_project_root() {
  local dir
  dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  while [[ "$dir" != "/" ]]; do
    if [[ -d "${dir}/.adlc" ]]; then
      echo "$dir"
      return
    fi
    dir="$(dirname "$dir")"
  done
  git rev-parse --show-toplevel 2>/dev/null || pwd
}

resolve_team_ai_directive() {
  local project_root="$1"
  local td="${TEAM_AI_DIRECTIVE:-}"
  [[ -n "$td" ]] && { echo "$td"; return; }
  if [[ -f "${project_root}/.adlc/init-options.json" ]]; then
    td=$(python3 -c "
import json
try:
    with open('${project_root}/.adlc/init-options.json') as f:
        print(json.load(f).get('team_ai_directive', ''))
except Exception:
    print('')
" 2>/dev/null || true)
    [[ -n "$td" ]] && { echo "$td"; return; }
  fi
  echo "${project_root}/team-ai-directives"
}

###############################################################################
# Main
###############################################################################

PROJECT_ROOT=$(resolve_project_root)
TEAM_AI_DIRECTIVE=$(resolve_team_ai_directive "$PROJECT_ROOT")
CONSTITUTION_FILE="${TEAM_AI_DIRECTIVE}/context_modules/constitution.md"

# Detect constitution state: missing | placeholder | populated
CONSTITUTION_STATE="missing"
if [[ -f "$CONSTITUTION_FILE" ]]; then
  if grep -q "No team-wide principles defined yet" "$CONSTITUTION_FILE" 2>/dev/null; then
    CONSTITUTION_STATE="placeholder"
  else
    CONSTITUTION_STATE="populated"
  fi
fi

# Check if team-ai-directives is a git repo with a clean working tree
TD_IS_GIT="false"
TD_CLEAN="false"
if [[ -d "$TEAM_AI_DIRECTIVE" ]]; then
  if git -C "$TEAM_AI_DIRECTIVE" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    TD_IS_GIT="true"
    TD_CLEAN=$([[ -z "$(git -C "$TEAM_AI_DIRECTIVE" status --porcelain 2>/dev/null)" ]] && echo "true" || echo "false")
  fi
fi

python3 - "$PROJECT_ROOT" "$TEAM_AI_DIRECTIVE" "$CONSTITUTION_FILE" "$CONSTITUTION_STATE" "$TD_IS_GIT" "$TD_CLEAN" << 'PY'
import json, sys
print(json.dumps({
  "REPO_ROOT": sys.argv[1],
  "TEAM_AI_DIRECTIVE": sys.argv[2],
  "CONSTITUTION_FILE": sys.argv[3],
  "CONSTITUTION_STATE": sys.argv[4],
  "TD_IS_GIT": sys.argv[5] == "true",
  "TD_CLEAN": sys.argv[6] == "true"
}))
PY
