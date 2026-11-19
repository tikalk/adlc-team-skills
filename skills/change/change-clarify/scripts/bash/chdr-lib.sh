#!/usr/bin/env bash
#
# chdr-lib.sh — Shared ChDR lifecycle library for adlc-team-skills change-* skills.
#
# Canonical home of the change family's shared bash helpers, modeled on
# product-clarify's pdr-lib.sh: change-clarify sources this file directly;
# the sibling change-* setup scripts vendor the helpers they use (scope rule:
# skills never source each other's scripts — the source tree is
# skills/<group>/<skill>/ while the installed mirror is flat
# .agents/skills/<skill>/, so no single relative source path resolves in
# both). Vendored copies are byte-identical; tests/unit/test_resolve_memory_root.py
# pins them against this file.
#
# Usage:
#   source chdr-lib.sh                       # load functions
#   resolve_memory_root                      # store root for the CWD (ADR-514)
#   ensure_memory_store "$MEMORY_ROOT" chdr  # loud create on promotion write
#   next_chdr_number DIR [DIR...]            # next free ChDR slot (multi-root)

set -euo pipefail

# Layout roots (.adlc/ machine pipeline; docs/adlc/ human-facing deliverables)
ADLC_DIR="${ADLC_DIR:-.adlc}"
DOCS_ADLC_DIR="${DOCS_ADLC_DIR:-docs/adlc}"
DOCS_ADLC_MEMORY="${DOCS_ADLC_MEMORY:-docs/adlc/memory}"
DOCS_ADLC_PRODUCT="${DOCS_ADLC_PRODUCT:-docs/adlc/product}"
DOCS_ADLC_ARCHITECT="${DOCS_ADLC_ARCHITECT:-docs/adlc/architect}"
ADLC_DRAFTS="${ADLC_DRAFTS:-.adlc/drafts}"

###############################################################################
# Path resolution
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

###############################################################################
# Decision-record store resolution (ADR-514)
#
# Vendored byte-identical into the change sibling setup scripts and mirrored
# per family (architect setup-architect.sh, product pdr-lib.sh) — scope rule:
# scripts stay skill-local. tests/unit/test_resolve_memory_root.py pins the
# copies against this canonical text.
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

# ensure_memory_store ROOT FAMILY — write-path guard for record promotion.
# Creates ROOT/docs/adlc/memory/FAMILY when missing and says so LOUDLY: the
# created store is the opt-in marker and travels with clones. Silent when the
# store already exists; reads never call this.
ensure_memory_store() {
    local root="$1" family="$2"
    local store="$root/${DOCS_ADLC_MEMORY:-docs/adlc/memory}/$family"
    if [[ ! -d "$store" ]]; then
        mkdir -p "$store"
        echo "No decision-record store found — initialized $store; commit it to opt $(basename "$root") into repo-scoped memory." >&2
    fi
}

###############################################################################
# Ledger slot allocation
###############################################################################

# next_chdr_number DIR [DIR...] — the next free ChDR ledger slot.
#
# A record's number is the LEADING DIGITS of its filename stem
# (ChDR-006-skill-side-remote-lane-abandoned.md is record 006); suffixes are
# preserved and never arithmetically parsed. The maximum spans EVERY
# directory given — ADR-514: the drafts root plus both store roots
# (docs/adlc/memory/chdr and legacy .adlc/memory/chdr) — so a published
# record's slot is never reissued. Reads never create anything.
next_chdr_number() {
  local max=0 f num dir
  for dir in "$@"; do
    [[ -d "$dir" ]] || continue
    for f in "$dir"/ChDR-*.md; do
      [[ -f "$f" ]] || continue
      num=$(basename "$f" .md | sed -n 's/^ChDR-\([0-9]\{1,\}\).*/\1/p')
      [[ -n "$num" ]] || continue
      ((10#$num > max)) && max=$((10#$num))
    done
  done
  printf '%03d' "$((max + 1))"
}
