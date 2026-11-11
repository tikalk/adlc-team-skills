#!/usr/bin/env bash
# setup-evals-implement.sh — Setup for evals-init (self-contained)
set -euo pipefail

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

resolve_branch() {
  git branch --show-current 2>/dev/null || echo "unknown"
}

PROJECT_ROOT=$(resolve_project_root)
TEAM_AI_DIRECTIVES=$(resolve_team_ai_directives "$PROJECT_ROOT")
BRANCH=$(resolve_branch)

jq -n --arg rr "$PROJECT_ROOT" --arg td "$TEAM_AI_DIRECTIVES" --arg br "$BRANCH" \
  '{REPO_ROOT:$rr,TEAM_AI_DIRECTIVES:$td,BRANCH:$br}'