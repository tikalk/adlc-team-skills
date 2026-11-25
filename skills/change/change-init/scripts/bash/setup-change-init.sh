#!/usr/bin/env bash
# setup-change-init.sh — Setup change-init (self-contained)
set -euo pipefail

# Layout roots (.adlc/ machine pipeline; docs/adlc/ human-facing deliverables)
ADLC_DIR="${ADLC_DIR:-.adlc}"
DOCS_ADLC_DIR="${DOCS_ADLC_DIR:-docs/adlc}"
DOCS_ADLC_MEMORY="${DOCS_ADLC_MEMORY:-docs/adlc/memory}"
DOCS_ADLC_PRODUCT="${DOCS_ADLC_PRODUCT:-docs/adlc/product}"
DOCS_ADLC_ARCHITECT="${DOCS_ADLC_ARCHITECT:-docs/adlc/architect}"
ADLC_DRAFTS="${ADLC_DRAFTS:-.adlc/drafts}"

# Sibling library — chdr-lib.sh sits next to change-clarify's setup script,
# but init's setup script is in a different directory. We use the one in
# change-clarify as the source of truth, but each skill vendors its own copy.
# (Note: for Task 4, they are all in the same repo but different skill dirs).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/chdr-lib.sh"

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
    git branch --show-current 2>/dev/null || echo "main"
}

git_available() {
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "true"
    else
        echo "false"
    fi
}

default_branch() {
    local b
    b=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's/origin\///')
    if [[ -n "$b" ]]; then
        echo "$b"
        return
    fi
    if git show-ref --verify --quiet "refs/heads/main" 2>/dev/null; then
        echo "main"
        return
    fi
    git branch --show-current 2>/dev/null || echo "main"
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
CHANGE_STATE_FILE="${PROJECT_ROOT}/.adlc/change/state.json"

mkdir -p "$CHDR_DRAFTS_DIR" "$(dirname "$CHANGE_STATE_FILE")" 2>/dev/null || true

# ID allocation: slugify(title) + collision check.
ID_ALLOCATION="slug"
EXISTING_CHDRS=$( { ls -1 "$CHDR_DRAFTS_DIR"/ChDR-*.md 2>/dev/null || true; } | wc -l | tr -d ' ')
TD_CONFIGURED=$([[ -d "$TEAM_AI_DIRECTIVES" ]] && echo "true" || echo "false")

jq -n --arg rr "$PROJECT_ROOT" --arg dd "$CHDR_DRAFTS_DIR" --arg csf "$CHANGE_STATE_FILE" \
  --arg td "$TEAM_AI_DIRECTIVES" --arg br "$BRANCH" --arg ia "$ID_ALLOCATION" \
  --argjson existing "$EXISTING_CHDRS" --argjson tdc "$TD_CONFIGURED" --argjson ga "$GIT_AVAILABLE" \
  --arg db "$DEFAULT_BRANCH" \
  '{REPO_ROOT:$rr,CHDR_DRAFTS_DIR:$dd,CHANGE_STATE_FILE:$csf,TEAM_AI_DIRECTIVES:$td,BRANCH:$br,id_allocation:$ia,EXISTING_CHDRS:$existing,TD_CONFIGURED:$tdc,GIT_AVAILABLE:$ga,DEFAULT_BRANCH:$db}'
