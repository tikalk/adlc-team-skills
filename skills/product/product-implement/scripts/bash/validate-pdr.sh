#!/bin/bash
# PDR Validation Script for individual PDR files
# Usage: validate-pdr.sh [PDR_FILE]
set -e

PDR_FILE="${1:-}"
if [[ -z "$PDR_FILE" || ! -f "$PDR_FILE" ]]; then
  echo "ERROR: PDR file not found: $PDR_FILE"
  echo "Usage: validate-pdr.sh <pdr-file.md>"
  exit 1
fi

ERRORS=0
WARNINGS=0
pass() { echo "  ✓ $1"; }
warn() { echo "  ⚠ $1"; ((WARNINGS++)); }
fail() { echo "  ✗ $1"; ((ERRORS++)); }

echo "🔍 Validating PDR: $PDR_FILE"

# Check required sections
for header in "Context" "Decision" "Consequences"; do
  if grep -qiE "^###?\s*$header" "$PDR_FILE"; then
    pass "Has '$header' section"
  else
    fail "Missing '$header' section"
  fi
done

# Check status
if grep -qiE '^\*\*Status\*\*' "$PDR_FILE" || grep -qiE '^\*\*(Proposed|Accepted|Discovered|Deprecated|Superseded)' "$PDR_FILE"; then
  pass "Has valid status"
else
  warn "No valid status marker found"
fi

# Check alternatives
if grep -qiE "Alternatives Considered" "$PDR_FILE"; then
  pass "Has 'Alternatives Considered' section"
else
  warn "Missing 'Alternatives Considered'"
fi

# Check for placeholders
if grep -qE '\[(Category|Problem|Decision Title|Owner)\]' "$PDR_FILE"; then
  warn "Contains template placeholders"
fi

# Summary
echo ""
if [[ $ERRORS -eq 0 && $WARNINGS -eq 0 ]]; then
  echo "✓ PDR validation passed"
  exit 0
elif [[ $ERRORS -eq 0 ]]; then
  echo "⚠ $WARNINGS warning(s)"
  exit 2
else
  echo "✗ $ERRORS error(s) and $WARNINGS warning(s)"
  exit 1
fi
