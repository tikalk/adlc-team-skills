#!/usr/bin/env bash
# setup-change-init.sh — Setup for change-init (self-contained)
set -euo pipefail

###############################################################################
# Inline path resolution (no external helper dependency)
###############################################################################

resolve_project_root() {
  local dir
  dir="$(pwd)"
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

git_available() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 && echo "true" || echo "false"
}

default_branch() {
  # Try common primary branches, fall back to current branch name.
  local b
  for b in main master; do
    if git show-ref --verify --quiet "refs/heads/${b}" 2>/dev/null; then
      echo "$b"
      return
    fi
  done
  git branch --show-current 2>/dev/null || echo "unknown"
}

next_chdr_number() {
  local dir="$1"
  mkdir -p "$dir" 2>/dev/null || true
  local max=0
  for f in "$dir"/ChDR-*.md; do
    [[ -f "$f" ]] || continue
    local num
    num=$(basename "$f" | sed -E 's/ChDR-([0-9]+).*/\1/')
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
GIT_AVAILABLE=$(git_available)
DEFAULT_BRANCH=$(default_branch)
CHDR_DRAFTS_DIR="${PROJECT_ROOT}/.adlc/drafts/chdr"
CHANGE_STATE_FILE="${PROJECT_ROOT}/.adlc/change/state.json"

mkdir -p "$CHDR_DRAFTS_DIR" "$(dirname "$CHANGE_STATE_FILE")" 2>/dev/null || true

NEXT_CHDR=$(next_chdr_number "$CHDR_DRAFTS_DIR")
EXISTING_CHDRS=$( { ls -1 "$CHDR_DRAFTS_DIR"/ChDR-*.md 2>/dev/null || true; } | wc -l | tr -d ' ')
TD_CONFIGURED=$([[ -d "$TEAM_AI_DIRECTIVES" ]] && echo "true" || echo "false")

python3 - "$PROJECT_ROOT" "$CHDR_DRAFTS_DIR" "$CHANGE_STATE_FILE" "$TEAM_AI_DIRECTIVES" "$BRANCH" "$NEXT_CHDR" "$EXISTING_CHDRS" "$TD_CONFIGURED" "$GIT_AVAILABLE" "$DEFAULT_BRANCH" << 'PY'
import json, sys
print(json.dumps({
  "REPO_ROOT": sys.argv[1],
  "CHDR_DRAFTS_DIR": sys.argv[2],
  "CHANGE_STATE_FILE": sys.argv[3],
  "TEAM_AI_DIRECTIVES": sys.argv[4],
  "BRANCH": sys.argv[5],
  "NEXT_CHDR": sys.argv[6],
  "EXISTING_CHDRS": int(sys.argv[7]),
  "TD_CONFIGURED": sys.argv[8] == "true",
  "GIT_AVAILABLE": sys.argv[9] == "true",
  "DEFAULT_BRANCH": sys.argv[10]
}))
PY
