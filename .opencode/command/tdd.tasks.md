---
description: Detect language/framework and generate hybrid TDD tests (increment-based
  + risk-based)
scripts:
  sh: .specify/extensions/tdd/scripts/bash/detect-language.sh
  ps: .specify/extensions/tdd/scripts/powershell/Detect-Language.ps1
tools:
- bash
- jq
- yq
---


<!-- Extension: tdd -->
<!-- Config: .specify/extensions/tdd/ -->
# TDD Tasks: Language Detection + Hybrid Test Generation

This command:
1. Detects language and test framework from the project
2. Parses spec.md for user stories and Risk Register
3. Applies TDD planning before generating tests
4. Generates hybrid tests: risk-based + increment-based

## TDD Planning Phase (TDD Principles)

Before generating tests, answer these planning questions:

### 1. What interface changes are needed?
- Which public functions APIs are being added or modified?
- Can we verify results directly through return values (not side effects)?
- Avoid: Database queries, file system checks, external service calls

### 2. Which behaviors matter most?
- Focus on: Critical paths, complex logic, user-facing features
- Skip over: Trivial getters/setters, mechanical operations
- Start with: Degenerate cases → Happy paths → Edge cases

### 3. Design for deep modules?
- Deep module = small interface, complex internals
- Makes testing simpler because interface is well-defined

### 4. Design for testability?
- Functions accept dependencies (don't create them)
- Return results (don't produce side effects)
- Pure functions → easier testing

### 5. Vertical slicing constraint
- Write ONE test → implement ONE behavior → repeat
- Prevents: Bulk tests that verify imagined behavior
- Ensures: Tests observe real code paths

## Detect Language and Framework

Run language detection script:

```bash
{./scripts/bash/detect-language.sh}
```

This will output language configuration to `.specify/extensions/tdd/language-detected.json`.

## Load Configuration

Load the detected language configuration:

```bash
LANG_CONFIG=$(cat .specify/extensions/tdd/language-detected.json 2>/dev/null || echo '{}')
LANGUAGE=$(echo "$LANG_CONFIG" | jq -r '.language // "unknown"')
FRAMEWORK=$(echo "$LANG_CONFIG" | jq -r '.framework // "pytest"')
TEST_DIR=$(echo "$LANG_CONFIG" | jq -r '.test_directory // "tests/"')
BINARY=$(echo "$LANG_CONFIG" | jq -r '.binary // "pytest"')
FLAGS=$(echo "$LANG_CONFIG" | jq -r '.flags // "-xvs"')

echo "Detected: $LANGUAGE / $FRAMEWORK"
echo "Test directory: $TEST_DIR"
echo "Test command: $BINARY $FLAGS"
```

## Parse Spec for User Stories

Extract user stories from spec.md:

```bash
# Find user story sections
USER_STORIES=$(grep -n "^##.*User Story" spec.md | cut -d: -f1)

if [ -z "$USER_STORIES" ]; then
  echo "No user stories found in spec.md"
  exit 0
fi

echo "Found user stories:"
echo "$USER_STORIES"
```

## Parse Risk Register

Check for Risk Register in spec.md:

```bash
RISK_REGISTER=$(grep -A 50 "^## Risk Register" spec.md 2>/dev/null || echo "")

if [ -n "$RISK_REGISTER" ]; then
  echo "Risk Register found - will generate risk-based tests"
else
  echo "No Risk Register found - increment tests only"
fi
```

## Generate Risk-Based Tests

If Risk Register present, generate risk-based test tasks:

```bash
# Parse risk entries: RISK: [name] | Severity: [High/Medium/Low] | Impact: [what] | Test: [specific test]
RISKS=$(grep "^-\s*RISK:" spec.md || true)

if [ -n "$RISKS" ]; then
  echo ""
  echo "### Risk-Based Tests (HIGH PRIORITY)"
  echo ""
  
  COUNTER=1
  echo "$RISKS" | while read -r risk_line; do
    # Extract test description from RISK entry
    TEST_DESC=$(echo "$risk_line" | sed -n 's/.*| Test: \([^|]*\).*/\1/p' | xargs)
    
    if [ -n "$TEST_DESC" ]; then
      echo "- [ ] TDD-R$(printf "%02d" $COUNTER) [RISK] $TEST_DESC"
      COUNTER=$((COUNTER + 1))
    fi
  done
fi
```

## Generate Increment-Based Tests

Generate structural test tasks based on feature type:

```bash
# Determine feature type from plan.md
FEATURE_TYPE=$(grep -i "feature.*type\|operation.*type" plan.md | head -1 | awk '{print tolower($NF)}' || echo "crud")

echo ""
echo "### Increment-Based Tests (Structural Coverage)"
echo ""

case "$FEATURE_TYPE" in
  "crud"|"create"|"read"|"update"|"delete")
    # CRUD pattern
    echo "**Degenerate Cases**"
    echo "- [ ] TDD-001 [P] [ASYNC] Create with empty input"
    echo "- [ ] TDD-002 [ASYNC] Create with missing required fields"
    echo ""
    echo "**Happy Path**"
    echo "- [ ] TDD-003 [P] [ASYNC] Create valid entity"
    echo "- [ ] TDD-004 [ASYNC] Read existing entity"
    echo "- [ ] TDD-005 [ASYNC] Update with valid changes"
    echo "- [ ] TDD-006 [ASYNC] Delete existing entity"
    echo ""
    echo "**Edge Cases**"
    echo "- [ ] TDD-007 [ASYNC] Read non-existent entity"
    echo "- [ ] TDD-008 [ASYNC] Update non-existent entity"
    echo "- [ ] TDD-009 [ASYNC] Delete non-existent entity"
    ;;
  "state"|"statemachine")
    # State machine pattern
    echo "**Degenerate Cases**"
    echo "- [ ] TDD-001 [ASYNC] Initialize with invalid state"
    echo ""
    echo "**Happy Path**"
    echo "- [ ] TDD-002 [P] [ASYNC] Valid state transition"
    echo "- [ ] TDD-003 [P] [ASYNC] Complete valid transition sequence"
    echo ""
    echo "**Edge Cases**"
    echo "- [ ] TDD-004 [ASYNC] Invalid transition attempt"
    echo "- [ ] TDD-005 [ASYNC] Transition from terminal state"
    ;;
  "transform"|"convert"|"parse")
    # Data transform pattern
    echo "**Degenerate Cases**"
    echo "- [ ] TDD-001 [ASYNC] Transform empty input"
    echo "- [ ] TDD-002 [ASYNC] Transform null input"
    echo ""
    echo "**Happy Path**"
    echo "- [ ] TDD-003 [P] [ASYNC] Transform valid single item"
    echo "- [ ] TDD-004 [P] [ASYNC] Transform valid multiple items"
    echo ""
    echo "**Edge Cases**"
    echo "- [ ] TDD-005 [ASYNC] Transform with boundary values"
    echo "- [ ] TDD-006 [ASYNC] Transform malformed input"
    ;;
  "api"|"integration"|"service")
    # Integration pattern
    echo "**Degenerate Cases**"
    echo "- [ ] TDD-001 [ASYNC] Handle connection error"
    echo "- [ ] TDD-002 [ASYNC] Handle timeout"
    echo ""
    echo "**Happy Path**"
    echo "- [ ] TDD-003 [P] [ASYNC] Success response (200)"
    echo "- [ ] TDD-004 [P] [ASYNC] Handle 400 client error"
    echo ""
    echo "**Edge Cases**"
    echo "- [ ] TDD-005 [ASYNC] Handle 500 server error"
    echo "- [ ] TDD-006 [ASYNC] Handle malformed response"
    ;;
  *)
    # Default: generic pattern
    echo "**Degenerate Cases**"
    echo "- [ ] TDD-001 [ASYNC] Handle empty input"
    echo ""
    echo "**Happy Path**"
    echo "- [ ] TDD-002 [P] [ASYNC] Valid input processing"
    echo ""
    echo "**Edge Cases**"
    echo "- [ ] TDD-003 [ASYNC] Handle invalid input"
    ;;
esac
```

## Summary

Output summary of generated tests:

```bash
echo ""
echo "## TDD Test Generation Summary"
echo ""
echo "Language: $LANGUAGE"
echo "Framework: $FRAMEWORK"
echo "Test Directory: $TEST_DIR"
echo ""
echo "Risk-based tests: $(echo "$RISKS" | wc -l)"
echo "Increment-based tests: Generated based on feature type"
echo ""
echo "Tests will be appended to tasks.md in each user story section."
echo "Execute /spec.implement to start RED→GREEN→REFACTOR workflow."
```

## Extension Hooks

This command is triggered by the `after_tasks` hook from `/spec.tasks`.

After execution, it outputs the `EXECUTE_COMMAND` marker for any follow-up hooks:

```bash
# Check if tdd.validate should run (optional hook)
echo ""
echo "📦 Post-implementation hooks available:"
echo "EXECUTE_COMMAND: tdd.validate"
```