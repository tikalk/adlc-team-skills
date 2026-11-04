#!/bin/bash
# product-implement setup script
set -euo pipefail
JSON_MODE=false
for arg in "$@"; do case "$arg" in --json) JSON_MODE=true ;; esac; done
# Layout roots (.adlc/ machine pipeline; docs/adlc/ human-facing deliverables)
ADLC_DIR="${ADLC_DIR:-.adlc}"
DOCS_ADLC_DIR="${DOCS_ADLC_DIR:-docs/adlc}"
DOCS_ADLC_MEMORY="${DOCS_ADLC_MEMORY:-docs/adlc/memory}"
DOCS_ADLC_PRODUCT="${DOCS_ADLC_PRODUCT:-docs/adlc/product}"
DOCS_ADLC_ARCHITECT="${DOCS_ADLC_ARCHITECT:-docs/adlc/architect}"
ADLC_DRAFTS="${ADLC_DRAFTS:-.adlc/drafts}"

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
REPO_ROOT="${REPO_ROOT:-$(_get_project_root)}"

count_pdr_accepted() {
  local dir="$1"
  [ -d "$dir" ] || return 0
  local count=0 f status
  for f in "$dir"/PDR-*.md; do
    [ -f "$f" ] || continue
    # status in frontmatter (status: accepted) or heading (### Status: **Accepted**)
    status=$(grep -E '^[[:space:]]*status:[[:space:]]*[A-Za-z]+' "$f" 2>/dev/null | head -1 | sed -E 's/^[[:space:]]*status:[[:space:]]*([A-Za-z]+).*/\1/' | tr '[:upper:]' '[:lower:]' || true)
    if [ -z "$status" ]; then
      status=$(grep -E '^###[[:space:]]+Status:[[:space:]]*\*\*[A-Za-z]+\*\*' "$f" 2>/dev/null | head -1 | sed -n 's/.*Status:[[:space:]]*\*\*\([A-Za-z]*\)\*\*.*/\1/p' | tr '[:upper:]' '[:lower:]' || true)
    fi
    if [ "$status" = "accepted" ] || [ "$status" = "completed" ]; then
      count=$((count + 1))
    fi
  done
  echo "$count"
}

# Ledger slot allocation (vendored from product-clarify pdr-lib.sh per the
# scope rule: scripts stay skill-local, helpers are vendored, never sourced
# across skills). A record's number is the LEADING DIGITS of its filename
# stem; the maximum spans drafts AND published memory.
next_record_number() {
  local prefix="$1"
  shift
  local max=0 f num dir
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

# The three document-internal PRD.md slots. Each scan is deliberately
# over-inclusive: an unused number is harmless, a reissued one collides.
next_prd_section() {
  local f="${1:-}"
  local max=0
  if [ -f "$f" ]; then
    max=$(awk '/^## [0-9]+\. / { n=$2; sub(/\.$/, "", n); if (n+0 > m) m=n+0 }
               END { print m+0 }' "$f")
  fi
  printf '%s' "$((max + 1))"
}

next_req_id() {
  local f="${1:-}"
  local max=0
  if [ -f "$f" ]; then
    max=$(grep -oE 'REQ-[0-9]+' "$f" | sed 's/^REQ-//' | sort -n | tail -1)
  fi
  printf '%s' "$((${max:-0} + 1))"
}

next_feature_number() {
  local f="${1:-}"
  local max=0
  if [ -f "$f" ]; then
    max=$(awk -F'|' '/^\| [0-9]+ \| / { gsub(/ /, "", $2); if ($2+0 > m) m=$2+0 }
                   END { print m+0 }' "$f")
  fi
  printf '%s' "$((max + 1))"
}

PDR_DRAFTS_DIR="$REPO_ROOT/${ADLC_DRAFTS:-.adlc/drafts}/pdr"
#  canonical PDR memory root (legacy .adlc/memory stays read-compatible).
PDR_MEMORY_DIR="$REPO_ROOT/docs/adlc/memory/pdr"
PRD_FILE="$REPO_ROOT/docs/adlc/product/PRD.md"
SECTIONS_DIR="$REPO_ROOT/.adlc/product/sections"
STATE_FILE="$REPO_ROOT/.adlc/product/state.json"

mkdir -p "$PDR_DRAFTS_DIR"
mkdir -p "$PDR_MEMORY_DIR"
mkdir -p "$SECTIONS_DIR"
mkdir -p "$REPO_ROOT/.adlc/product"
#  compiled PRD lives under docs/adlc/product/ — ensure the parent exists.
mkdir -p "$REPO_ROOT/${DOCS_ADLC_PRODUCT:-docs/adlc/product}"

ACCEPTED_COUNT=$(count_pdr_accepted "$PDR_DRAFTS_DIR" 2>/dev/null || echo 0)

# Ledger slots handed to the implement run: record id (drafts + published) and
# the three PRD.md document-internal slots.
NEXT_PDR=$(next_record_number PDR "$PDR_DRAFTS_DIR" "$PDR_MEMORY_DIR")
NEXT_PRD_SECTION=$(next_prd_section "$PRD_FILE")
NEXT_REQ_ID=$(next_req_id "$PRD_FILE")
NEXT_FEATURE_NUMBER=$(next_feature_number "$PRD_FILE")

if $JSON_MODE; then
  python3 - "$REPO_ROOT" "$PDR_DRAFTS_DIR" "$PDR_MEMORY_DIR" "$PRD_FILE" "$SECTIONS_DIR" "$STATE_FILE" "$ACCEPTED_COUNT" "$NEXT_PDR" "$NEXT_PRD_SECTION" "$NEXT_REQ_ID" "$NEXT_FEATURE_NUMBER" <<'PY'
import json, sys
print(json.dumps({
  "REPO_ROOT": sys.argv[1],
  "PDR_DRAFTS_DIR": sys.argv[2],
  "PDR_MEMORY_DIR": sys.argv[3],
  "PRD_FILE": sys.argv[4],
  "SECTIONS_DIR": sys.argv[5],
  "STATE_FILE": sys.argv[6],
  "accepted_count": int(sys.argv[7]),
  "next_pdr": sys.argv[8],
  "next_prd_section": sys.argv[9],
  "next_req_id": sys.argv[10],
  "next_feature_number": sys.argv[11]
}))
PY
else
  echo "[INFO] product-implement setup"
  echo "  Accepted PDRs: $ACCEPTED_COUNT"
  echo "  PRD_FILE: $PRD_FILE"
  echo "  SECTIONS_DIR: $SECTIONS_DIR"
  echo "  Next PDR slot: PDR-$NEXT_PDR"
  echo "  Next PRD section: $NEXT_PRD_SECTION"
  echo "  Next REQ id: REQ-$NEXT_REQ_ID"
  echo "  Next feature row: $NEXT_FEATURE_NUMBER"
fi
