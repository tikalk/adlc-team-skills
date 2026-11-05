#!/usr/bin/env bash
# setup-change-specify.sh — Setup for change-specify (self-contained)
set -euo pipefail

# shared layout constants (single definition in paths.sh).
_ch_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$_ch_dir/../../../../team/workspace/scripts/bash/paths.sh" ]; then
  # shellcheck disable=SC1091
  . "$_ch_dir/../../../../team/workspace/scripts/bash/paths.sh"
elif [ -f "$_ch_dir/../../../workspace/scripts/bash/paths.sh" ]; then
  # shellcheck disable=SC1091
  . "$_ch_dir/../../../workspace/scripts/bash/paths.sh"
fi

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
CHDR_DRAFTS_DIR="${PROJECT_ROOT}/${ADLC_DRAFTS:-.adlc/drafts}/chdr"

mkdir -p "$CHDR_DRAFTS_DIR" 2>/dev/null || true

NEXT_CHDR=$(next_chdr_number "$CHDR_DRAFTS_DIR")
EXISTING_CHDRS=$( { ls -1 "$CHDR_DRAFTS_DIR"/ChDR-*.md 2>/dev/null || true; } | wc -l | tr -d ' ')
TD_CONFIGURED=$([[ -d "$TEAM_AI_DIRECTIVES" ]] && echo "true" || echo "false")

if [[ "$TD_CONFIGURED" == "true" ]]; then td_json=true; else td_json=false; fi
if [[ "$GIT_AVAILABLE" == "true" ]]; then git_json=true; else git_json=false; fi
jq -n --arg rr "$PROJECT_ROOT" --arg dd "$CHDR_DRAFTS_DIR" --arg td "$TEAM_AI_DIRECTIVES" \
  --arg br "$BRANCH" --arg next "$NEXT_CHDR" --argjson existing "$EXISTING_CHDRS" \
  --argjson tdc "$td_json" --argjson ga "$git_json" --arg db "$DEFAULT_BRANCH" \
  '{REPO_ROOT:$rr,CHDR_DRAFTS_DIR:$dd,TEAM_AI_DIRECTIVES:$td,BRANCH:$br,NEXT_CHDR:$next,EXISTING_CHDRS:$existing,TD_CONFIGURED:$tdc,GIT_AVAILABLE:$ga,DEFAULT_BRANCH:$db}'
