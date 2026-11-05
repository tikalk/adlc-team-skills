#!/bin/bash
# product-analyze setup script
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
PRD_FILE="$REPO_ROOT/${DOCS_ADLC_PRODUCT:-docs/adlc/product}/PRD.md"
PDR_COUNT=$(find "$PDR_DRAFTS_DIR" -name 'PDR-*.md' 2>/dev/null | wc -l)
# dual-read: compiled PRD at docs/adlc/product/PRD.md, legacy repo-root
# PRD.md fallback (either counts as present).
PRD_EXISTS=false
if [ -f "$PRD_FILE" ] || [ -f "$REPO_ROOT/PRD.md" ]; then PRD_EXISTS=true; fi
if $JSON_MODE; then
  jq -n --arg rr "$REPO_ROOT" --arg pdd "$PDR_DRAFTS_DIR" --arg pf "$PRD_FILE" \
    --argjson n "$PDR_COUNT" --argjson pe "$PRD_EXISTS" \
    '{REPO_ROOT:$rr,PDR_DRAFTS_DIR:$pdd,PRD_FILE:$pf,pdr_count:$n,prd_exists:$pe}' 
else
  echo "[INFO] product-analyze setup"
  echo "  PDRs: $PDR_COUNT"
  echo "  PRD exists: $PRD_EXISTS"
fi
