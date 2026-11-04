#!/bin/bash
# product-specify setup script
set -euo pipefail

JSON_MODE=false
for arg in "$@"; do
  case "$arg" in --json) JSON_MODE=true ;; esac
done

_get_project_root() {
  local dir
  dir="$(pwd)"
  while [ "$dir" != "/" ]; do
    if [ -d "$dir/.adlc" ] || [ -d "$dir/.git" ]; then
      echo "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  pwd
}

# Ledger slot allocation (vendored from product-clarify pdr-lib.sh):
# leading digits of the filename stem, max across drafts AND published memory.
next_record_number() {
  local prefix="$1"
  shift
  local max=0 f num
  local dir
  for dir in "$@"; do
    [ -d "$dir" ] || continue
    for f in "$dir"/"${prefix}"-*.md; do
      [ -f "$f" ] || continue
      num=$(basename "$f" .md | sed -n "s/^${prefix}-\([0-9]\{1,\}\).*/\1/p")
      [ -n "$num" ] || continue
      ((10#$num > max)) && max=$((10#$num))
    done
  done
  printf '%03d' "$((max + 1))"
}

# Layout roots (.adlc/ machine pipeline; docs/adlc/ human-facing deliverables)
ADLC_DIR="${ADLC_DIR:-.adlc}"
DOCS_ADLC_DIR="${DOCS_ADLC_DIR:-docs/adlc}"
DOCS_ADLC_MEMORY="${DOCS_ADLC_MEMORY:-docs/adlc/memory}"
DOCS_ADLC_PRODUCT="${DOCS_ADLC_PRODUCT:-docs/adlc/product}"
DOCS_ADLC_ARCHITECT="${DOCS_ADLC_ARCHITECT:-docs/adlc/architect}"
ADLC_DRAFTS="${ADLC_DRAFTS:-.adlc/drafts}"
REPO_ROOT="${REPO_ROOT:-$(_get_project_root)}"
PDR_DRAFTS_DIR="$REPO_ROOT/${ADLC_DRAFTS:-.adlc/drafts}/pdr"
PRD_FILE="$REPO_ROOT/${DOCS_ADLC_PRODUCT:-docs/adlc/product}/PRD.md"

mkdir -p "$PDR_DRAFTS_DIR"

# Ledger slot allocation (vendored): leading
# digits of the filename stem, max across drafts AND published memory. This
# script previously carried its own copy, which silently skipped stemmed
# records (PDR-002-amendment-2.md) and scanned drafts alone.
NEXT_PDR=$(next_record_number PDR "$PDR_DRAFTS_DIR" \
  "$REPO_ROOT/${DOCS_ADLC_MEMORY:-docs/adlc/memory}/pdr")
PDR_COUNT=$(find "$PDR_DRAFTS_DIR" -name 'PDR-*.md' 2>/dev/null | wc -l)

if $JSON_MODE; then
  python3 - "$REPO_ROOT" "$PDR_DRAFTS_DIR" "$PRD_FILE" "$NEXT_PDR" "$PDR_COUNT" <<'PY'
import json, sys
print(json.dumps({
  "REPO_ROOT": sys.argv[1],
  "PDR_DRAFTS_DIR": sys.argv[2],
  "PRD_FILE": sys.argv[3],
  "next_pdr": sys.argv[4],
  "pdr_count": int(sys.argv[5])
}))
PY
else
  echo "[INFO] product-specify setup"
  echo "  REPO_ROOT: $REPO_ROOT"
  echo "  PDR_DRAFTS_DIR: $PDR_DRAFTS_DIR"
  echo "  Next PDR: PDR-$NEXT_PDR"
  echo "  Existing PDRs: $PDR_COUNT"
fi
