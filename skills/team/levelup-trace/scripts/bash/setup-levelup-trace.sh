#!/usr/bin/env bash
# setup-levelup-trace.sh — Setup for levelup-trace (self-contained)
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

resolve_branch() {
  git branch --show-current 2>/dev/null || echo "unknown"
}

###############################################################################
# Main
###############################################################################

PROJECT_ROOT=$(resolve_project_root)
TEAM_AI_DIRECTIVE=$(resolve_team_ai_directive "$PROJECT_ROOT")
BRANCH=$(resolve_branch)
CDR_DRAFTS_DIR="${PROJECT_ROOT}/.adlc/drafts/cdr"
TRACE_FILE="${PROJECT_ROOT}/.adlc/drafts/trace.md"

mkdir -p "$CDR_DRAFTS_DIR" "$(dirname "$TRACE_FILE")"

python3 - "$PROJECT_ROOT" "$TEAM_AI_DIRECTIVE" "$BRANCH" "$CDR_DRAFTS_DIR" "$TRACE_FILE" << 'PY'
import json, sys
print(json.dumps({
  "REPO_ROOT": sys.argv[1],
  "TEAM_AI_DIRECTIVE": sys.argv[2],
  "BRANCH": sys.argv[3],
  "CDR_DRAFTS_DIR": sys.argv[4],
  "TRACE_FILE": sys.argv[5]
}))
PY
