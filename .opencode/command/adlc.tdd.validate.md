---
description: Validate test quality and provide recommendations with scoring
scripts:
  sh: .specify/extensions/tdd/scripts/bash/validate-test-quality.sh
tools:
- bash
- jq
---


<!-- Extension: tdd -->
<!-- Config: .specify/extensions/tdd/ -->
# TDD Validate: Test Quality Analysis

This command analyzes test files for quality and provides:
1. Quality score (0-100)
2. Good practices findings (+points)
3. Anti-patterns findings (-points)
4. Recommendations for improvement

## Load Test Files

Find all test files in the project:

```bash
# Find test files
TEST_FILES=$(find . -type f \( -name "test_*.py" -o -name "*_test.py" -o -name "*.test.ts" -o -name "*.spec.ts" -o -name "*_test.go" \) 2>/dev/null | grep -v node_modules | grep -v .venv | grep -v __pycache__)

if [ -z "$TEST_FILES" ]; then
  echo "No test files found in project."
  exit 0
fi

echo "Found test files:"
echo "$TEST_FILES"
```

## Analyze Each Test File

For each test file, analyze for quality indicators:

```bash
echo ""
echo "=========================================="
echo "Test Quality Analysis"
echo "=========================================="
echo ""

TOTAL_SCORE=0
FILE_COUNT=0

echo "$TEST_FILES" | while read -r test_file; do
  FILE_COUNT=$((FILE_COUNT + 1))
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Analyzing: $test_file"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  FILE_SCORE=0
  
  # Check for GOOD PRACTICES
  echo ""
  echo "Checking for good practices..."
  
  # +10: Tests through public interfaces
  PUBLIC_INTERFACE=$(grep -c "def test_\|it(\|test(" "$test_file" 2>/dev/null || echo "0")
  if [ "$PUBLIC_INTERFACE" -gt 0 ]; then
    echo "  ✓ Uses public interface tests: +10 points"
    FILE_SCORE=$((FILE_SCORE + 10))
  fi
  
  # +10: Describes behavior (not implementation)
  BEHAVIOR_DESC=$(grep -c "should\|expect\|assert.*==" "$test_file" 2>/dev/null || echo "0")
  if [ "$BEHAVIOR_DESC" -gt 0 ]; then
    echo "  ✓ Describes behavior: +10 points"
    FILE_SCORE=$((FILE_SCORE + 10))
  fi
  
  # +5: Follows AAA pattern (Arrange-Act-Assert)
  AAA_PATTERN=$(grep -c "def setup\|def before\|def arrange\|# Arrange\|# Act\|# Assert" "$test_file" 2>/dev/null || echo "0")
  if [ "$AAA_PATTERN" -gt 0 ]; then
    echo "  ✓ Follows AAA pattern: +5 points"
    FILE_SCORE=$((FILE_SCORE + 5))
  fi
  
  # +5: Descriptive test names
  DESCRIPTIVE_NAMES=$(grep -c "def test_[a-z_]*_[a-z_]*" "$test_file" 2>/dev/null || echo "0")
  if [ "$DESCRIPTIVE_NAMES" -gt 3 ]; then
    echo "  ✓ Descriptive test names: +5 points"
    FILE_SCORE=$((FILE_SCORE + 5))
  fi
  
  # Check for ANTI-PATTERNS
  echo ""
  echo "Checking for anti-patterns..."
  
  # -10: Mocks internal collaborators
  INTERNAL_MOCKS=$(grep -c "Mock\|mock\|stub" "$test_file" 2>/dev/null || echo "0")
  if [ "$INTERNAL_MOCKS" -gt 5 ]; then
    echo "  ✗ Excessive mocking of internals: -10 points"
    FILE_SCORE=$((FILE_SCORE - 10))
  fi
  
  # -15: Tests implementation details
  IMPL_DETAILS=$(grep -c "private\|_internal\|__private\|\.private" "$test_file" 2>/dev/null || echo "0")
  if [ "$IMPL_DETAILS" -gt 0 ]; then
    echo "  ✗ Tests implementation details: -15 points"
    FILE_SCORE=$((FILE_SCORE - 15))
  fi
  
  # -10: Brittle tests (hardcoded values, exact matches)
  BRITTLE=$(grep -c "assert.*==.*[0-9]\{4\}\|assertEqual(\s*[0-9]" "$test_file" 2>/dev/null || echo "0")
  if [ "$BRITTLE" -gt 3 ]; then
    echo "  ✗ Brittle tests with hardcoded values: -10 points"
    FILE_SCORE=$((FILE_SCORE - 10))
  fi
  
  # Ensure score doesn't go below 0
  if [ "$FILE_SCORE" -lt 0 ]; then
    FILE_SCORE=0
  fi
  
  echo ""
  echo "File score: $FILE_SCORE/100"
  
  TOTAL_SCORE=$((TOTAL_SCORE + FILE_SCORE))
done
```

## Calculate Overall Score

```bash
if [ "$FILE_COUNT" -gt 0 ]; then
  OVERALL_SCORE=$((TOTAL_SCORE / FILE_COUNT))
else
  OVERALL_SCORE=0
fi

echo ""
echo "=========================================="
echo "Overall Test Quality Score"
echo "=========================================="
echo ""
echo "Score: $OVERALL_SCORE/100"
```

## Interpret Score

```bash
echo ""
if [ "$OVERALL_SCORE" -ge 90 ]; then
  echo "🎉 Excellent test quality!"
  echo ""
  echo "Your tests are well-written with good practices."
elif [ "$OVERALL_SCORE" -ge 70 ]; then
  echo "✅ Good test quality with some refinements"
  echo ""
  echo "Most tests follow best practices. Consider addressing"
  echo "the specific findings below for improvement."
elif [ "$OVERALL_SCORE" -ge 50 ]; then
  echo "⚠️  Several improvements needed"
  echo ""
  echo "Tests have some issues that should be addressed."
  echo "Review recommendations below."
else
  echo "❌ Major redesign required"
  echo ""
  echo "Tests have significant anti-patterns that need"
  echo "to be addressed before further development."
fi
```

## Generate Recommendations

```bash
echo ""
echo "=========================================="
echo "Recommendations"
echo "=========================================="
echo ""

echo "Priority fixes:"
echo ""
echo "1. If tests mock internal collaborators, refactor to"
echo "   test through public interfaces instead."
echo ""
echo "2. If tests check implementation details, update to"
echo "   verify behavior instead."
echo ""
echo "3. If tests are brittle, add data-driven tests or"
echo "   use parameterization."
echo ""
echo "4. Add descriptive docstrings explaining WHAT each"
echo "   test validates, not HOW it's implemented."
echo ""
echo "5. Follow AAA pattern: Arrange → Act → Assert"
```

## Check Config Threshold

Load extension config and check against threshold:

```bash
CONFIG_FILE=".specify/extensions/tdd/tdd-config.yml"
THRESHOLD=70

if [ -f "$CONFIG_FILE" ]; then
  THRESHOLD=$(yq eval '.test_analysis.threshold // 70' "$CONFIG_FILE")
fi

echo ""
echo "Quality threshold: $THRESHOLD"

if [ "$OVERALL_SCORE" -lt "$THRESHOLD" ]; then
  echo ""
  echo "⚠️  WARNING: Test quality below threshold ($THRESHOLD)"
  echo ""
  echo "Consider addressing the recommendations above"
  echo "before continuing with more features."
else
  echo ""
  echo "✅ Test quality meets threshold"
fi
```

## Generate Report

Save quality report to file:

```bash
REPORT_FILE="tdd-quality-report.md"

cat > "$REPORT_FILE" << EOF
# TDD Test Quality Report

**Generated**: $(date)

## Summary

| Metric | Value |
|--------|-------|
| Files Analyzed | $FILE_COUNT |
| Overall Score | $OVERALL_SCORE/100 |
| Threshold | $THRESHOLD |
| Status | $([ "$OVERALL_SCORE" -ge "$THRESHOLD" ] && echo "✅ PASS" || echo "⚠️  WARNING") |

## Score Interpretation

- **90-100**: Excellent test quality
- **70-89**: Good with refinements needed
- **50-69**: Several improvements needed
- **0-49**: Major redesign required

## Findings

### Good Practices Found
- Tests through public interfaces
- Behavior-focused assertions
- AAA pattern usage
- Descriptive test names

### Anti-Patterns Detected
- Excessive internal mocking
- Implementation detail testing
- Brittle hardcoded assertions

## Recommendations

1. Refactor tests to use public interfaces
2. Update to verify behavior, not implementation
3. Add data-driven tests for flexibility
4. Add descriptive docstrings
5. Follow AAA pattern consistently

## Next Steps

- Address priority recommendations
- Re-run tdd.validate after improvements
- Continue with feature development
EOF

echo ""
echo "📄 Report saved to: $REPORT_FILE"
```

## Summary Output

```bash
echo ""
echo "=========================================="
echo "Test Quality Validation Complete"
echo "=========================================="
echo ""
echo "Files analyzed: $FILE_COUNT"
echo "Overall score: $OVERALL_SCORE/100"
echo "Threshold: $THRESHOLD"
echo "Report: $REPORT_FILE"
echo ""
echo "Address recommendations and re-run as needed."
```