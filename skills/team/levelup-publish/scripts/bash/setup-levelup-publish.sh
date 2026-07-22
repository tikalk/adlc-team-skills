#!/usr/bin/env bash
# setup-levelup-publish.sh — Setup for levelup-publish (self-contained)
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
SKILLS_DRAFTS_DIR="${PROJECT_ROOT}/.adlc/drafts/skills"
TRACE_FILE="${PROJECT_ROOT}/.adlc/drafts/trace.md"

mkdir -p "$CDR_DRAFTS_DIR" "$SKILLS_DRAFTS_DIR"
TRACE_EXISTS=$([[ -f "$TRACE_FILE" ]] && echo "true" || echo "false")

# Find accepted CDRs using single-line format: ### Status: **Accepted**
ACCEPTED_CDRS=()
if [[ -d "$CDR_DRAFTS_DIR" ]]; then
  while IFS= read -r f; do
    [[ -n "$f" ]] && ACCEPTED_CDRS+=("$(basename "$f" .md)")
  done < <(grep -l -E '^### Status: \*\*Accepted\*\*' "$CDR_DRAFTS_DIR"/CDR-*.md 2>/dev/null | sort)
fi

ACCEPTED_JSON=$(printf '%s\n' "${ACCEPTED_CDRS[@]}" | python3 -c 'import json,sys; print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))')
TD_CONFIGURED=$([[ -d "$TEAM_AI_DIRECTIVE" ]] && echo "true" || echo "false")

# Check if team-ai-directives is a git repo with a clean working tree
TD_IS_GIT="false"
TD_CLEAN="false"
if [[ "$TD_CONFIGURED" == "true" ]]; then
  if git -C "$TEAM_AI_DIRECTIVE" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    TD_IS_GIT="true"
    TD_CLEAN=$([[ -z "$(git -C "$TEAM_AI_DIRECTIVE" status --porcelain 2>/dev/null)" ]] && echo "true" || echo "false")
  fi
fi

python3 - "$PROJECT_ROOT" "$CDR_DRAFTS_DIR" "$SKILLS_DRAFTS_DIR" "$TEAM_AI_DIRECTIVE" "$BRANCH" "$ACCEPTED_JSON" "$TD_CONFIGURED" "$TD_IS_GIT" "$TD_CLEAN" "$TRACE_FILE" "$TRACE_EXISTS" << 'PY'
import json, sys
print(json.dumps({
  "REPO_ROOT": sys.argv[1],
  "CDR_DRAFTS_DIR": sys.argv[2],
  "SKILLS_DRAFTS_DIR": sys.argv[3],
  "TEAM_AI_DIRECTIVE": sys.argv[4],
  "BRANCH": sys.argv[5],
  "ACCEPTED_CDRS": json.loads(sys.argv[6]),
  "TD_CONFIGURED": sys.argv[7] == "true",
  "TD_IS_GIT": sys.argv[8] == "true",
  "TD_CLEAN": sys.argv[9] == "true",
  "TRACE_FILE": sys.argv[10],
  "TRACE_EXISTS": sys.argv[11] == "true"
}))
PY
