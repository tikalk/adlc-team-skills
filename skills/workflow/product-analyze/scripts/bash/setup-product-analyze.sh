#!/bin/bash
# product-analyze setup script
set -euo pipefail
JSON_MODE=false
for arg in "$@"; do case "$arg" in --json) JSON_MODE=true ;; esac; done
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PDR_DRAFTS_DIR="$REPO_ROOT/.adlc/drafts/pdr"
PRD_FILE="$REPO_ROOT/PRD.md"
PDR_COUNT=$(find "$PDR_DRAFTS_DIR" -name 'PDR-*.md' 2>/dev/null | wc -l)
PRD_EXISTS=$([ -f "$PRD_FILE" ] && echo "true" || echo "false")
if $JSON_MODE; then
  cat <<EOF
{"REPO_ROOT":"$REPO_ROOT","PDR_DRAFTS_DIR":"$PDR_DRAFTS_DIR","PRD_FILE":"$PRD_FILE","pdr_count":$PDR_COUNT,"prd_exists":$PRD_EXISTS}
EOF
else
  echo "[INFO] product-analyze setup"
  echo "  PDRs: $PDR_COUNT"
  echo "  PRD exists: $PRD_EXISTS"
fi
