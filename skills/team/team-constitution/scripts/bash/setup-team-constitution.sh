#!/usr/bin/env bash
# setup-team-constitution.sh — Setup for team-constitution (self-contained)
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
    td=$(jq -r '.team_ai_directives // empty' "${project_root}/.adlc/init-options.json" 2>/dev/null || true)
    [[ -n "$td" ]] && { echo "$td"; return; }
  fi
  echo "${project_root}/team-ai-directives"
}

# JSON output always goes through jq -n (no manual string building).
###############################################################################
# Main
###############################################################################

PROJECT_ROOT=$(resolve_project_root)
TEAM_AI_DIRECTIVES=$(resolve_team_ai_directives "$PROJECT_ROOT")
CONSTITUTION_FILE="${TEAM_AI_DIRECTIVES}/context_modules/constitution.md"

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
if [[ -d "$TEAM_AI_DIRECTIVES" ]]; then
  if git -C "$TEAM_AI_DIRECTIVES" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    TD_IS_GIT="true"
    TD_CLEAN=$([[ -z "$(git -C "$TEAM_AI_DIRECTIVES" status --porcelain 2>/dev/null)" ]] && echo "true" || echo "false")
  fi
fi

jq -n \
  --arg repo_root "$PROJECT_ROOT" \
  --arg team_ai_directives "$TEAM_AI_DIRECTIVES" \
  --arg constitution_file "$CONSTITUTION_FILE" \
  --arg constitution_state "$CONSTITUTION_STATE" \
  --argjson td_is_git "$TD_IS_GIT" \
  --argjson td_clean "$TD_CLEAN" \
  '{"REPO_ROOT":$repo_root,"TEAM_AI_DIRECTIVES":$team_ai_directives,"CONSTITUTION_FILE":$constitution_file,"CONSTITUTION_STATE":$constitution_state,"TD_IS_GIT":$td_is_git,"TD_CLEAN":$td_clean}'
