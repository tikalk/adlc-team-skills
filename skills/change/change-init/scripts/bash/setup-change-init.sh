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

###############################################################################
# Decision-record store resolution (ADR-514)
#
# Vendored byte-identical from the canonical block in change-clarify's
# chdr-lib.sh — scope rule: scripts stay skill-local.
# tests/unit/test_resolve_memory_root.py pins the copies against each other.
###############################################################################

# _memory_root_has_marker DIR — does DIR carry a decision-record store marker?
# A marker is a decision-record family subdir (adr/, pdr/, chdr/) or a family
# index file (adr.md/pdr.md/chdr.md) under docs/adlc/memory/ or the legacy
# .adlc/memory/. A bare .adlc/ is NOT a marker; a memory dir holding only
# non-decision content (evals/, constitution.md) is NOT a marker.
_memory_root_has_marker() {
    local root="$1" mem fam
    for mem in "docs/adlc/memory" ".adlc/memory"; do
        [[ -d "$root/$mem" ]] || continue
        for fam in adr pdr chdr; do
            if [[ -d "$root/$mem/$fam" || -f "$root/$mem/$fam.md" || -f "$root/$mem/$fam/$fam.md" ]]; then
                return 0
            fi
        done
    done
    return 1
}

# _workspace_root_above DIR — is any strict ancestor of DIR a workspace root
# (a directory holding .gitmodules or .adlc/workspace.yml)? Lets a submodule
# child climb past its own git toplevel toward the workspace store.
_workspace_root_above() {
    local up
    up="$(dirname "$1")"
    while [[ "$up" != "/" ]]; do
        if [[ -f "$up/.gitmodules" || -f "$up/.adlc/workspace.yml" ]]; then
            return 0
        fi
        up="$(dirname "$up")"
    done
    return 1
}

# resolve_memory_root — the decision-record store root for the current working
# directory. ONE bounded walk-up from pwd:
#   1. the nearest ancestor with a decision-record family marker wins;
#   2. else the nearest workspace root (.gitmodules or .adlc/workspace.yml)
#      — the workspace-centralized default;
#   3. else the git toplevel (standalone repo).
# The walk never climbs past the git toplevel unless a workspace root sits
# above it (a submodule child inside a workspace). Side-effect-free: reads
# never create anything.
resolve_memory_root() {
    local dir toplevel
    dir="$(pwd -P)"
    toplevel="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null || true)"
    while [[ "$dir" != "/" ]]; do
        if _memory_root_has_marker "$dir"; then
            printf '%s\n' "$dir"
            return 0
        fi
        if [[ -f "$dir/.gitmodules" || -f "$dir/.adlc/workspace.yml" ]]; then
            printf '%s\n' "$dir"
            return 0
        fi
        if [[ -n "$toplevel" && "$dir" == "$toplevel" ]] && ! _workspace_root_above "$dir"; then
            printf '%s\n' "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    if [[ -n "$toplevel" ]]; then
        printf '%s\n' "$toplevel"
    else
        pwd -P
    fi
}

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
