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

# ============================================================================
# Frontmatter + heading status parsers (vendored from product-clarify
# pdr-lib.sh per the scope rule: scripts stay skill-local, helpers are
# vendored, never sourced across skills; keep these copies in sync with
# product-clarify, plus next_record_number and the three PRD.md slot
# scanners below).
# ============================================================================

# Parse a YAML frontmatter field from a markdown file.
# Usage: parse_fm_field "file" "fieldname"
# Returns the field value with quotes, inline comments, and surrounding whitespace stripped.
parse_fm_field() {
    local file="$1"
    local field="$2"
    [ -f "$file" ] || return 0
    awk -v fld="^[[:space:]]*${field}:[[:space:]]*" '
        /^---[[:space:]]*$/ { fm++; next }
        fm == 1 && $0 ~ fld {
            sub(fld, "")
            sub(/[[:space:]]+#.*$/, "")
            gsub(/^["'\'']|["'\'']$/, "")
            gsub(/^\[|\]$/, "")
            sub(/^[[:space:]]+/, ""); sub(/[[:space:]]+$/, "")
            print
            exit
        }
    ' "$file"
}

# Parse a metadata field from Markdown headings (## or ###).
# Looks for a heading line matching "^###+ <field>$", returns the next non-empty
# non-heading line with ** bold markers stripped.
# Usage: parse_pdr_heading_field "file" "Status"  (case-sensitive field name)
parse_pdr_heading_field() {
    local file="$1"
    local field="$2"
    [ -f "$file" ] || return 0
    awk -v fld="$field" '
        $0 ~ "^#+[[:space:]]*" fld "[[:space:]]*$" { found=1; next }
        found && /^#+/ { exit }
        found && NF > 0 {
            gsub(/\*\*/, "")
            sub(/^[[:space:]]+/, ""); sub(/[[:space:]]+$/, "")
            print
            exit
        }
    ' "$file"
}

# Parse a PDR metadata field: tries YAML frontmatter first, falls back to headings.
# Usage: parse_pdr_field "file" "status"  (frontmatter field name, lowercase hyphenated)
#        parse_pdr_field "file" "Status"  (heading field name, Title Case)
# Note: frontmatter uses lowercase hyphenated keys (status, feature-area);
#       headings use Title Case (Status, Feature-Area). This function tries both.
parse_pdr_field() {
    local file="$1"
    local field="$2"
    local value=""

    # Try frontmatter (lowercase the field name for YAML key matching)
    local fm_field
    fm_field=$(echo "$field" | tr '[:upper:]' '[:lower:]')
    value=$(parse_fm_field "$file" "$fm_field")
    if [ -n "$value" ]; then
        echo "$value"
        return
    fi

    # Fallback: heading-based (Title Case the field name for heading matching)
    # Accept both "Feature-Area" and "feature-area" heading styles
    local title_field
    title_field=$(echo "$field" | awk -F'-' '{for (i=1; i<=NF; i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2))}1' OFS='-')
    value=$(parse_pdr_heading_field "$file" "$title_field")
    if [ -n "$value" ]; then
        echo "$value"
        return
    fi
    # Try the raw field name (handles "Feature-Area" where only first letter caps)
    value=$(parse_pdr_heading_field "$file" "$field")
    if [ -n "$value" ]; then
        echo "$value"
        return
    fi

    # Empty string — caller should apply defaults
    echo ""
}

# Accepted-PDR counter.
# Both legacy H2 (## Status) and current H3 (### Status) shapes count;
# frontmatter `status: accepted` counts, inline-bold and next-line values count.
count_pdr_accepted() {
  local dir="$1"
  [ -d "$dir" ] || return 0
  local count=0 f status
  for f in "$dir"/PDR-*.md; do
    [ -f "$f" ] || continue
    status=$(parse_pdr_field "$f" "status")
    # Normalize: strip ** bold, lowercase, trim
    status=$(printf '%s' "$status" | sed 's/\*\*//g' | tr '[:upper:]' '[:lower:]' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
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
  jq -n -c --arg rr "$REPO_ROOT" --arg pdd "$PDR_DRAFTS_DIR" --arg pmd "$PDR_MEMORY_DIR" \
    --arg pf "$PRD_FILE" --arg sd "$SECTIONS_DIR" --arg sf "$STATE_FILE" \
    --argjson a "$ACCEPTED_COUNT" \
    --arg np "$NEXT_PDR" --arg nps "$NEXT_PRD_SECTION" --arg nr "$NEXT_REQ_ID" --arg nfn "$NEXT_FEATURE_NUMBER" \
    '{REPO_ROOT:$rr,PDR_DRAFTS_DIR:$pdd,PDR_MEMORY_DIR:$pmd,PRD_FILE:$pf,SECTIONS_DIR:$sd,STATE_FILE:$sf,accepted_count:$a,next_pdr:$np,next_prd_section:$nps,next_req_id:$nr,next_feature_number:$nfn}'
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
