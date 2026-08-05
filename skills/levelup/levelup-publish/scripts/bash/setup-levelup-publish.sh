#!/usr/bin/env bash
# setup-levelup-publish.sh — Setup for levelup-publish (self-contained)
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

resolve_sdd_docs_location() {
  local project_root="$1"
  local loc="${SDD_DOCS_LOCATION:-}"
  [[ -n "$loc" ]] && { echo "$loc"; return; }
  if [[ -f "${project_root}/.adlc/init-options.json" ]]; then
    loc=$(python3 -c "
import json
try:
    with open('${project_root}/.adlc/init-options.json') as f:
        print(json.load(f).get('sdd_docs_location', ''))
except Exception:
    print('')
" 2>/dev/null || true)
  fi
  echo "$loc"
}

sdd_project_subfolder_name() {
  local project_root="$1"
  local common_dir
  common_dir=$(git -C "$project_root" rev-parse --git-common-dir 2>/dev/null)
  if [[ -n "$common_dir" ]]; then
    basename "$(cd "$(dirname "$common_dir")" && pwd)"
  else
    basename "$project_root"
  fi
}

resolve_branch() {
  git branch --show-current 2>/dev/null || echo "unknown"
}

###############################################################################
# Main
###############################################################################

PROJECT_ROOT=$(resolve_project_root)
TEAM_AI_DIRECTIVES=$(resolve_team_ai_directives "$PROJECT_ROOT")
SDD_DOCS_LOCATION=$(resolve_sdd_docs_location "$PROJECT_ROOT")
if [[ -n "$SDD_DOCS_LOCATION" ]]; then
  SDD_DOCS_LOCATION="${SDD_DOCS_LOCATION/#\~/$HOME}"
  SDD_ROOT="${SDD_DOCS_LOCATION%/}/$(sdd_project_subfolder_name "$PROJECT_ROOT")"
else
  SDD_ROOT="$PROJECT_ROOT"
fi
BRANCH=$(resolve_branch)
CDR_DRAFTS_DIR="${SDD_ROOT}/.adlc/drafts/cdr"
SKILLS_DRAFTS_DIR="${SDD_ROOT}/.adlc/drafts/skills"

mkdir -p "$CDR_DRAFTS_DIR" "$SKILLS_DRAFTS_DIR"

# Find accepted CDRs using single-line format: ### Status: **Accepted**
ACCEPTED_CDRS=()
if [[ -d "$CDR_DRAFTS_DIR" ]]; then
  while IFS= read -r f; do
    [[ -n "$f" ]] && ACCEPTED_CDRS+=("$(basename "$f" .md)")
  done < <(grep -l -E '^### Status: \*\*Accepted\*\*' "$CDR_DRAFTS_DIR"/CDR-*.md 2>/dev/null | sort)
fi

ACCEPTED_JSON=$(printf '%s\n' ${ACCEPTED_CDRS[@]+"${ACCEPTED_CDRS[@]}"} | python3 -c 'import json,sys; print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))')
TD_CONFIGURED=$([[ -d "$TEAM_AI_DIRECTIVES" ]] && echo "true" || echo "false")

# Check if team-ai-directives is a git repo with a clean working tree
TD_IS_GIT="false"
TD_CLEAN="false"
if [[ "$TD_CONFIGURED" == "true" ]]; then
  if git -C "$TEAM_AI_DIRECTIVES" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    TD_IS_GIT="true"
    TD_CLEAN=$([[ -z "$(git -C "$TEAM_AI_DIRECTIVES" status --porcelain 2>/dev/null)" ]] && echo "true" || echo "false")
  fi
fi

python3 - "$PROJECT_ROOT" "$SDD_ROOT" "$CDR_DRAFTS_DIR" "$SKILLS_DRAFTS_DIR" "$TEAM_AI_DIRECTIVES" "$BRANCH" "$ACCEPTED_JSON" "$TD_CONFIGURED" "$TD_IS_GIT" "$TD_CLEAN" << 'PY'
import json, sys
print(json.dumps({
  "REPO_ROOT": sys.argv[1],
  "SDD_ROOT": sys.argv[2],
  "CDR_DRAFTS_DIR": sys.argv[3],
  "SKILLS_DRAFTS_DIR": sys.argv[4],
  "TEAM_AI_DIRECTIVES": sys.argv[5],
  "BRANCH": sys.argv[6],
  "ACCEPTED_CDRS": json.loads(sys.argv[7]),
  "TD_CONFIGURED": sys.argv[8] == "true",
  "TD_IS_GIT": sys.argv[9] == "true",
  "TD_CLEAN": sys.argv[10] == "true"
}))
PY
