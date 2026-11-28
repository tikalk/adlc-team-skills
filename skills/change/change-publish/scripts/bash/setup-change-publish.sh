#!/usr/bin/env bash
# setup-change-publish.sh — Setup for change-publish (self-contained)
set -euo pipefail

# Layout roots (.adlc/ machine pipeline; docs/adlc/ human-facing deliverables)
ADLC_DIR="${ADLC_DIR:-.adlc}"
DOCS_ADLC_DIR="${DOCS_ADLC_DIR:-docs/adlc}"
DOCS_ADLC_MEMORY="${DOCS_ADLC_MEMORY:-docs/adlc/memory}"
DOCS_ADLC_PRODUCT="${DOCS_ADLC_PRODUCT:-docs/adlc/product}"
DOCS_ADLC_ARCHITECT="${DOCS_ADLC_ARCHITECT:-docs/adlc/architect}"
ADLC_DRAFTS="${ADLC_DRAFTS:-.adlc/drafts}"

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
# Main
###############################################################################

PROJECT_ROOT=$(resolve_project_root)
CHDR_DRAFTS_DIR="${PROJECT_ROOT}/${ADLC_DRAFTS:-.adlc/drafts}/chdr"
# published ChDRs live under docs/adlc/memory at the resolved store root
# (ADR-514); legacy .adlc/memory/chdr stays read-compatible — dual-read).
MEMORY_ROOT=$(resolve_memory_root)
MEMORY_DIR="${MEMORY_ROOT}/docs/adlc/memory/chdr"
MEMORY_INDEX="${MEMORY_ROOT}/docs/adlc/memory/chdr/chdr.md"
LEGACY_MEMORY_DIR="${MEMORY_ROOT}/.adlc/memory/chdr"

# ID allocation: slugify(title) + collision check.
ID_ALLOCATION="slug"

# publish is a record-promotion write path: the store is created loudly when
# the resolved root has none (the store dir is the opt-in marker).
ensure_memory_store "$MEMORY_ROOT" chdr

# Accepted ChDR ids (filenames) in drafts
ACCEPTED_CHDRS=$( { grep -l '^### Status: \*\*Accepted\*\*' "$CHDR_DRAFTS_DIR"/ChDR-*.md 2>/dev/null || true; } | xargs -r -n1 basename 2>/dev/null | sed 's/\.md$//' | tr '\n' ' ' | sed 's/ *$//')
ACCEPTED_COUNT=$( { grep -l '^### Status: \*\*Accepted\*\*' "$CHDR_DRAFTS_DIR"/ChDR-*.md 2>/dev/null || true; } | wc -l | tr -d ' ')
PUBLISHED_COUNT=$( { grep -l '^### Status: \*\*Published\*\*' "$CHDR_DRAFTS_DIR"/ChDR-*.md 2>/dev/null || true; } | wc -l | tr -d ' ')
# Dual-read: count records in both new and legacy root.
MEMORY_COUNT=$(( $( { ls -1 "$MEMORY_DIR"/ChDR-*.md 2>/dev/null || true; } | wc -l | tr -d ' ') + $( { ls -1 "$LEGACY_MEMORY_DIR"/ChDR-*.md 2>/dev/null || true; } | wc -l | tr -d ' ') ))
MEMORY_INDEX_EXISTS=$([[ -f "$MEMORY_INDEX" ]] && echo "true" || echo "false")

if [ -n "$ACCEPTED_CHDRS" ]; then
  accepted_json=$(printf '%s\n' $ACCEPTED_CHDRS | jq -R . | jq -s -c .)
else
  accepted_json="[]"
fi
if [[ "$MEMORY_INDEX_EXISTS" == "true" ]]; then mem_json=true; else mem_json=false; fi

jq -n --arg rr "$PROJECT_ROOT" --arg dd "$CHDR_DRAFTS_DIR" --arg md "$MEMORY_DIR" --arg mi "$MEMORY_INDEX" \
  --arg ia "$ID_ALLOCATION" --argjson accepted "$accepted_json" --argjson ac "$ACCEPTED_COUNT" --argjson pc "$PUBLISHED_COUNT" \
  --argjson mc "$MEMORY_COUNT" --argjson mie "$mem_json" \
  '{REPO_ROOT:$rr,CHDR_DRAFTS_DIR:$dd,MEMORY_DIR:$md,MEMORY_INDEX:$mi,id_allocation:$ia,ACCEPTED_CHDRS:$accepted,ACCEPTED_COUNT:$ac,PUBLISHED_COUNT:$pc,MEMORY_COUNT:$mc,MEMORY_INDEX_EXISTS:$mie}'
