#!/usr/bin/env bash
# setup-levelup-init.sh — Setup for levelup-init (self-contained)
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

resolve_team_ai_directives() {
  local project_root="$1"
  local td="${TEAM_AI_DIRECTIVES:-}"
  [[ -n "$td" ]] && { echo "$td"; return; }
  if [[ -f "${project_root}/.adlc/init-options.json" ]]; then
    td=$(python3 -c "
import json
try:
    with open('${project_root}/.adlc/init-options.json') as f:
        print(json.load(f).get('team_ai_directives', ''))
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

next_cdr_number() {
  local dir="$1"
  mkdir -p "$dir" 2>/dev/null || true
  local max=0
  for f in "$dir"/CDR-*.md; do
    [[ -f "$f" ]] || continue
    local num
    num=$(basename "$f" | sed -E 's/CDR-([0-9]+).*/\1/')
    [[ "$num" =~ ^[0-9]+$ ]] || continue
    ((10#$num > max)) && max=$((10#$num))
  done
  printf '%03d' $((max + 1))
}

###############################################################################
# Main
###############################################################################

PROJECT_ROOT=$(resolve_project_root)
TEAM_AI_DIRECTIVES=$(resolve_team_ai_directives "$PROJECT_ROOT")
BRANCH=$(resolve_branch)
CDR_DRAFTS_DIR="${PROJECT_ROOT}/.adlc/drafts/cdr"
SKILLS_DRAFTS_DIR="${PROJECT_ROOT}/.adlc/drafts/skills"
LEVELUP_STATE_FILE="${PROJECT_ROOT}/.adlc/levelup/state.json"

mkdir -p "$CDR_DRAFTS_DIR" "$SKILLS_DRAFTS_DIR" "$(dirname "$LEVELUP_STATE_FILE")"

NEXT_CDR=$(next_cdr_number "$CDR_DRAFTS_DIR")
EXISTING_CDRS=$( { ls -1 "$CDR_DRAFTS_DIR"/CDR-*.md 2>/dev/null || true; } | wc -l | tr -d ' ')
TD_CONFIGURED=$([[ -d "$TEAM_AI_DIRECTIVES" ]] && echo "true" || echo "false")

python3 - "$PROJECT_ROOT" "$CDR_DRAFTS_DIR" "$SKILLS_DRAFTS_DIR" "$LEVELUP_STATE_FILE" "$TEAM_AI_DIRECTIVES" "$BRANCH" "$NEXT_CDR" "$EXISTING_CDRS" "$TD_CONFIGURED" << 'PY'
import json, sys
print(json.dumps({
  "REPO_ROOT": sys.argv[1],
  "CDR_DRAFTS_DIR": sys.argv[2],
  "SKILLS_DRAFTS_DIR": sys.argv[3],
  "LEVELUP_STATE_FILE": sys.argv[4],
  "TEAM_AI_DIRECTIVES": sys.argv[5],
  "BRANCH": sys.argv[6],
  "NEXT_CDR": sys.argv[7],
  "EXISTING_CDRS": int(sys.argv[8]),
  "TD_CONFIGURED": sys.argv[9] == "true"
}))
PY
