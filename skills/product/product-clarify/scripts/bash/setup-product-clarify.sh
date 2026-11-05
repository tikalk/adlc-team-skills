#!/bin/bash
# product-clarify setup script
set -euo pipefail
JSON_MODE=false
for arg in "$@"; do case "$arg" in --json) JSON_MODE=true ;; esac; done

# Source pdr-lib.sh for _get_project_root (walks up to find .adlc, not just .git)
source "$(dirname "${BASH_SOURCE[0]}")/pdr-lib.sh" 2>/dev/null || true

# shared layout constants (single definition in paths.sh; pdr-lib.sh
# sources it too — this block keeps the script correct standalone).
_pd_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Layout roots (.adlc/ machine pipeline; docs/adlc/ human-facing deliverables)
ADLC_DIR="${ADLC_DIR:-.adlc}"
DOCS_ADLC_DIR="${DOCS_ADLC_DIR:-docs/adlc}"
DOCS_ADLC_MEMORY="${DOCS_ADLC_MEMORY:-docs/adlc/memory}"
DOCS_ADLC_PRODUCT="${DOCS_ADLC_PRODUCT:-docs/adlc/product}"
DOCS_ADLC_ARCHITECT="${DOCS_ADLC_ARCHITECT:-docs/adlc/architect}"
ADLC_DRAFTS="${ADLC_DRAFTS:-.adlc/drafts}"
REPO_ROOT="${REPO_ROOT:-$(_get_project_root)}"
PDR_DRAFTS_DIR="$REPO_ROOT/${ADLC_DRAFTS:-.adlc/drafts}/pdr"
#  canonical PDR memory root (legacy .adlc/memory stays read-compatible).
PDR_MEMORY_DIR="$REPO_ROOT/docs/adlc/memory/pdr"
PRD_FILE="$REPO_ROOT/${DOCS_ADLC_PRODUCT:-docs/adlc/product}/PRD.md"
mkdir -p "$PDR_DRAFTS_DIR"
PDR_COUNT=$(find "$PDR_DRAFTS_DIR" -name 'PDR-*.md' 2>/dev/null | wc -l)
ACCEPTED_COUNT=0
if [[ "$PDR_COUNT" -gt 0 ]]; then
  ACCEPTED_COUNT=$(count_pdr_accepted "$PDR_DRAFTS_DIR" 2>/dev/null || grep -lE '^#+\s*Status' "$PDR_DRAFTS_DIR"/PDR-*.md 2>/dev/null | xargs -I{} grep -l '^\*\*Accepted\*\*' {} 2>/dev/null | wc -l)
fi
if $JSON_MODE; then
  python3 - "$REPO_ROOT" "$PDR_DRAFTS_DIR" "$PDR_MEMORY_DIR" "$PRD_FILE" "$PDR_COUNT" "$ACCEPTED_COUNT" <<'PY'
import json, sys
print(json.dumps({
  "REPO_ROOT": sys.argv[1],
  "PDR_DRAFTS_DIR": sys.argv[2],
  "PDR_MEMORY_DIR": sys.argv[3],
  "PRD_FILE": sys.argv[4],
  "pdr_count": int(sys.argv[5]),
  "accepted_count": int(sys.argv[6])
}))
PY
else
  echo "[INFO] product-clarify setup"
  echo "  PDRs found: $PDR_COUNT"
  echo "  Accepted: $ACCEPTED_COUNT"
fi
