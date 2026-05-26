#!/bin/bash
# PDR Validation Script v1.5.2
# Validates Product Decision Records for completeness
# Usage: validate-pdr.sh [PDR_FILE]

set -e

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

PDR_FILE="${1:-.specify/drafts/pdr.md}"
WARNINGS=0
ERRORS=0

if [[ ! -f "$PDR_FILE" ]]; then
    echo -e "${RED}ERROR: PDR file not found: $PDR_FILE${NC}"
    exit 1
fi

echo -e "${BLUE}🔍 Validating PDR: $PDR_FILE${NC}"
echo -e "${BLUE}Extension Version: 1.5.2${NC}"
echo "================================================"

pass() { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; ((WARNINGS++)); }
fail() { echo -e "${RED}✗${NC} $1"; ((ERRORS++)); }

# Check constitution
echo ""
echo -e "${BLUE}Checking constitution...${NC}"
CONST_FILE=".specify/memory/constitution.md"
if [[ -f "$CONST_FILE" ]]; then
    if grep -qE '\[PRINCIPLE_[0-9]+_NAME\]|\[PROJECT_NAME\]' "$CONST_FILE"; then
        warn "Constitution file contains template placeholders - populate before claiming alignment"
    else
        pass "Constitution file appears to be populated"
    fi
else
    warn "No constitution file found"
fi

# Check PDR structure
echo ""
echo -e "${BLUE}Checking PDR structure...${NC}"

REQUIRED_HEADERS=(
    "Context"
    "Decision"
    "Consequences"
)

for header in "${REQUIRED_HEADERS[@]}"; do
    if grep -qiE "^###?\s*$header" "$PDR_FILE"; then
        pass "Has '$header' section"
    else
        fail "Missing '$header' section"
    fi
done

# Check for status
echo ""
echo -e "${BLUE}Checking PDR status...${NC}"

if grep -qiE '^\*\*Status\*\*:\s*(Accepted|Proposed|Discovered|Deprecated)' "$PDR_FILE"; then
    pass "PDR has valid status"
    
    # Count statuses
    ACCEPTED_COUNT=$(grep -cE '^\*\*Status\*\*:\s*Accepted' "$PDR_FILE" || true)
    TOTAL_COUNT=$(grep -cE '^\*\*Status\*\*:' "$PDR_FILE" || true)
    
    echo "   Found $ACCEPTED_COUNT Accepted out of $TOTAL_COUNT total PDRs"
else
    warn "No valid status markers found (Accepted/Proposed/Discovered/Deprecated)"
fi

# Check for inconsistency flags
echo ""
echo -e "${BLUE}Checking for inconsistency flags...${NC}"

FLAG_COUNT=$(grep -cE '⚠️\s*Inconsistency|FLG-[0-9]+' "$PDR_FILE" || true)

if [[ $FLAG_COUNT -gt 0 ]]; then
    warn "Found $FLAG_COUNT inconsistency flag(s) - resolve via /product.clarify"
else
    pass "No inconsistency flags found"
fi

# Check for alternatives
echo ""
echo -e "${BLUE}Checking for alternatives...${NC}"

if grep -qiE "Alternatives Considered|## Alternatives" "$PDR_FILE"; then
    pass "Has 'Alternatives Considered' section"
else
    warn "Missing 'Alternatives Considered' section (recommended for quality PDRs)"
fi

# Summary
echo ""
echo "================================================"
echo -e "${BLUE}Validation Summary${NC}"
echo "================================================"

if [[ $ERRORS -eq 0 && $WARNINGS -eq 0 ]]; then
    echo -e "${GREEN}✓ PDR validation passed!${NC}"
    exit 0
elif [[ $ERRORS -eq 0 ]]; then
    echo -e "${YELLOW}⚠ $WARNINGS warning(s)${NC}"
    exit 2
else
    echo -e "${RED}✗ $ERRORS error(s) and $WARNINGS warning(s)${NC}"
    exit 1
fi
