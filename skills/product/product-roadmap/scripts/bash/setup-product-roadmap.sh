#!/bin/bash
# product-roadmap setup script
set -euo pipefail
JSON_MODE=false
for arg in "$@"; do case "$arg" in --json) JSON_MODE=true ;; esac; done

# JSON output is built with jq -n (jq is required; no fallbacks).

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

# shared layout constants (single definition in paths.sh).
_pd_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$_pd_dir/../../../../team/workspace/scripts/bash/paths.sh" ]; then
  # shellcheck disable=SC1091
  . "$_pd_dir/../../../../team/workspace/scripts/bash/paths.sh"
elif [ -f "$_pd_dir/../../../workspace/scripts/bash/paths.sh" ]; then
  # shellcheck disable=SC1091
  . "$_pd_dir/../../../workspace/scripts/bash/paths.sh"
fi
PDR_DRAFTS_DIR="$REPO_ROOT/${ADLC_DRAFTS:-.adlc/drafts}/pdr"
#  canonical memory root is docs/adlc/memory; legacy .adlc/memory
# stays read-compatible — memory counts sum both roots (dual-read R8).
PDR_MEMORY_DIR="$REPO_ROOT/docs/adlc/memory/pdr"
LEGACY_PDR_MEMORY_DIR="$REPO_ROOT/.adlc/memory/pdr"
PRD_FILE="$REPO_ROOT/${DOCS_ADLC_PRODUCT:-docs/adlc/product}/PRD.md"
mkdir -p "$PDR_DRAFTS_DIR"
DRAFT_COUNT=$(find "$PDR_DRAFTS_DIR" -name 'PDR-*.md' 2>/dev/null | wc -l)
MEM_COUNT=$(( $(find "$PDR_MEMORY_DIR" -name 'PDR-*.md' 2>/dev/null | wc -l) + $(find "$LEGACY_PDR_MEMORY_DIR" -name 'PDR-*.md' 2>/dev/null | wc -l) ))
if $JSON_MODE; then
  jq -n --arg rr "$REPO_ROOT" --arg pdd "$PDR_DRAFTS_DIR" --arg pmd "$PDR_MEMORY_DIR" \
    --arg pf "$PRD_FILE" --argjson d "$DRAFT_COUNT" --argjson m "$MEM_COUNT" \
    '{REPO_ROOT:$rr,PDR_DRAFTS_DIR:$pdd,PDR_MEMORY_DIR:$pmd,PRD_FILE:$pf,draft_count:$d,memory_count:$m}' 
else
  echo "[INFO] product-roadmap setup"
  echo "  Draft PDRs: $DRAFT_COUNT"
  echo "  Memory PDRs: $MEM_COUNT"
fi
