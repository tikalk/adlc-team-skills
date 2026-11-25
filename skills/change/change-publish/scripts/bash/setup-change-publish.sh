#!/usr/bin/env bash
# setup-change-publish.sh — Setup change-publish (self-contained)
set -euo pipefail

# Layout roots (.adlc/ machine pipeline; docs/adlc/ human-facing deliverables)
ADLC_DIR="${ADLC_DIR:-.adlc}"
DOCS_ADLC_DIR="${DOCS_ADLC_DIR:-docs/adlc}"
DOCS_ADLC_MEMORY="${DOCS_ADLC_MEMORY:-docs/adlc/memory}"
DOCS_ADLC_PRODUCT="${DOCS_ADLC_PRODUCT:-docs/adlc/product}"
DOCS_ADLC_ARCHITECT="${DOCS_ADLC_ARCHITECT:-docs/adlc/architect}"
ADLC_DRAFTS="${ADLC_DRAFTS:-.adlc/drafts}"

# Sibling library — chdr-lib.sh sits next to this script (each skill vendors
# its own copy).
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

###############################################################################
# Main
###############################################################################

PROJECT_ROOT=$(resolve_project_root)
CHDR_DRAFTS_DIR="${PROJECT_ROOT}/${ADLC_DRAFTS:-.adlc/drafts}/chdr"
# published ChDRs live under docs/adlc/memory at the resolved store root
# (ADR-514); legacy .adlc/memory/chdr stays read-compatible — dual-read).
MEMORY_ROOT=$(resolve_memory_root)
MEMORY_DIR="${MEMORY_ROOT}/${DOCS_ADLC_MEMORY}/chdr"
MEMORY_INDEX="${MEMORY_ROOT}/${DOCS_ADLC_MEMORY}/chdr/chdr.md"
LEGACY_MEMORY_DIR="${MEMORY_ROOT}/.adlc/memory/chdr"

# ID allocation: slugify(title) + collision check.
ID_ALLOCATION="slug"

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
