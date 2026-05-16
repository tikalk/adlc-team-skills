---
description: Execute RED→GREEN→REFACTOR cycle for each TDD increment
scripts:
  sh: .specify/extensions/tdd/scripts/bash/decompose-feature.sh
tools:
- bash
- jq
---


<!-- Extension: tdd -->
<!-- Config: .specify/extensions/tdd/ -->
# TDD Implement: RED→GREEN→REFACTOR Workflow

This command executes the TDD workflow for each test increment:
1. **RED Phase**: Write failing test, confirm it fails
2. **GREEN Phase**: Write minimal implementation, confirm tests pass
3. **REFACTOR Phase**: Apply improvements, confirm tests still pass

## Core Principles (TDD + TDD best practices)

### Vertical Slicing
- **ONE test → ONE implementation → repeat**
- Write a single failing test
- Implement just enough to pass that test
- This prevents bulk tests that verify imagined behavior
- Tests observe real code paths, not hallucinated ones

### Public Interface Testing
- Test **WHAT** (behavior) through **public interfaces**
- NOT **HOW** (implementation details)
- Tests should survive internal refactors unchanged

### Anti-Patterns to Avoid
- ❌ Mocking internal collaborators
- ❌ Verifying call counts (`assertCalled`, `toHaveBeenCalled`)
- ❌ Testing private methods or implementation details  
- ❌ DB queries that bypass the interface
- ❌ File system checks that bypass the interface
- ❌brittle tests with hardcoded magic numbers

### Good Tests
- ✅ Exercise real code through public interface
- ✅ Describe behavior (user can checkout with valid cart)
- ✅ Test edge cases (nil, zero, empty, boundaries)
- ✅ Test isolated (no dependencies between tests)
- ✅ Read like specifications

## The RED Phase Constraint

**CRITICAL**: The test **must fail first** before writing ANY implementation code.

If the test passes immediately:
- Either the behavior is already implemented
- Or the test isn't asserting the right thing
- **STOP** and fix before proceeding

This constraint prevents:
- Writing tests that are too loose
- Faking test passes instead of real implementation

## Load State

Load or initialize increment state:

```bash
FEATURE_DIR=$(pwd)
STATE_FILE="$FEATURE_DIR/increment-state.json"

# Load existing state or create new
if [ -f "$STATE_FILE" ]; then
  echo "Loading existing TDD state..."
  STATE=$(cat "$STATE_FILE")
else
  echo "Initializing new TDD state..."
  STATE='{"current_increment": 0, "increments": []}'
fi

CURRENT=$(echo "$STATE" | jq -r '.current_increment')
echo "Current increment: $CURRENT"
```

## Load Language Config

```bash
LANG_CONFIG=$(cat .specify/extensions/tdd/language-detected.json 2>/dev/null || echo '{}')
LANGUAGE=$(echo "$LANG_CONFIG" | jq -r '.language // "python"')
FRAMEWORK=$(echo "$LANG_CONFIG" | jq -r '.framework // "pytest"')
TEST_DIR=$(echo "$LANG_CONFIG" | jq -r '.test_directory // "tests/"')
BINARY=$(echo "$LANG_CONFIG" | jq -r '.binary // "pytest"')
FLAGS=$(echo "$LANG_CONFIG" | jq -r '.flags // "-xvs"')

echo "Using: $LANGUAGE / $FRAMEWORK"
echo "Test command: $BINARY $FLAGS"
```

## Get Pending Increments

Find pending test increments:

```bash
# Get pending increments (status = "pending")
PENDING=$(echo "$STATE" | jq -c '.increments[] | select(.status == "pending")' || echo "")

if [ -z "$PENDING" ]; then
  echo "No pending increments found."
  echo "All TDD tests may already be complete."
  echo ""
  echo "To review test quality, run: tdd.validate"
  exit 0
fi

echo "Found pending increments:"
echo "$PENDING" | jq -r '.id + ": " + .description'
```

## Process Each Increment

For each pending increment, execute RED→GREEN→REFACTOR:

```bash
echo "$PENDING" | while read -r increment; do
  INC_ID=$(echo "$increment" | jq -r '.id')
  INC_DESC=$(echo "$increment" | jq -r '.description')
  INC_TYPE=$(echo "$increment" | jq -r '.type // "increment"')
  TEST_FILE=$(echo "$increment" | jq -r '.test_file // ""')
  
  echo ""
  echo "=========================================="
  echo "Processing: $INC_ID ($INC_TYPE)"
  echo "Description: $INC_DESC"
  echo "=========================================="
  
  # PRIORITY: Risk tests first
  if [ "$INC_TYPE" == "risk" ]; then
    echo "⚠️  HIGH PRIORITY: Risk-based test"
  fi
```

### RED Phase

Write the failing test:

```bash
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🔴 RED PHASE: Write failing test"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "Task: Write a test that $INC_DESC"
  echo "The test should FAIL initially (red)."
  echo ""
  echo "⚠️  IMPORTANT: Follow TDD principles"
  echo "1. Test PUBLIC interface (not internal methods)"
  echo "2. Test OBSERVABLE behavior (not mock internals)"
  echo "3. Return values preferred over side effects"
  echo "4. Avoid: DB queries, file checks, call verification"
  echo ""
  
  # Prompt for test content
  echo "Enter test file path (default: $TEST_DIR/test_feature.py): "
  read -r TEST_FILE_PATH
  TEST_FILE_PATH=${TEST_FILE_PATH:-$TEST_DIR/test_feature.py}
  
  echo "Enter test function name: "
  read -r TEST_FUNC
  
  echo ""
  echo "Write your failing test now..."
  echo "File: $TEST_FILE_PATH"
  echo "Function: $TEST_FUNC"
  echo ""
  echo "After writing the test, run: $BINARY $FLAGS $TEST_FILE_PATH::$TEST_FUNC"
  echo ""
  echo "Did the test FAIL as expected? (yes/no): "
  read -r RED_RESULT
  
  if [[ ! "$RED_RESULT" =~ ^[Yy] ]]; then
    echo "❌ Test did not fail. Please write a test that fails first."
    echo "Skipping to next increment."
    continue
  fi
  
  echo "✅ RED phase complete - test fails as expected"
```

### GREEN Phase

Write minimal implementation:

```bash
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🟢 GREEN PHASE: Write minimal implementation"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "Task: Write minimal code to make the test pass."
  echo "Focus on the simplest solution that works."
  echo ""
  echo "⚠️  IMPORTANT: Write ONLY what the test requires"
  echo "1. No speculative code"
  echo "2. No extra features"
  echo "3. Test behavior, not implementation"
  echo ""
  
  echo "Enter implementation file path: "
  read -r IMPL_FILE
  
  echo "Enter implementation function/class: "
  read -r IMPL_FUNC
  
  echo ""
  echo "Write your implementation now..."
  echo "File: $IMPL_FILE"
  echo "Function: $IMPL_FUNC"
  echo ""
  echo "After writing, run: $BINARY $FLAGS"
  echo ""
  echo "Did ALL tests PASS? (yes/no): "
  read -r GREEN_RESULT
  
  if [[ ! "$GREEN_RESULT" =~ ^[Yy] ]]; then
    echo "❌ Tests did not pass. Fix implementation and try again."
    continue
  fi
  
  echo "✅ GREEN phase complete - tests pass"
  
  # Update state
  STATE=$(echo "$STATE" | jq ".increments[] | select(.id == \"$INC_ID\") | .status = \"green_complete\"")
```

### REFACTOR Phase (Optional)

Offer refactoring:

```bash
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🔵 REFACTOR PHASE (optional)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "Are there improvements to make? (yes/no): "
  read -r REFACTOR_CHOICE
  
  if [[ "$REFACTOR_CHOICE" =~ ^[Yy] ]]; then
    echo ""
    echo "Make your refactoring improvements..."
    echo "After refactoring, run: $BINARY $FLAGS"
    echo ""
    echo "Did tests still PASS after refactoring? (yes/no): "
    read -r REFACTOR_RESULT
    
    if [[ "$REFACTOR_RESULT" =~ ^[Yy] ]]; then
      echo "✅ REFACTOR complete - tests still pass"
      STATE=$(echo "$STATE" | jq ".increments[] | select(.id == \"$INC_ID\") | .status = \"complete\"")
    else
      echo "⚠️  Refactoring broke tests - reverting"
      echo "Status: green_complete (ready to try refactor again)"
    fi
  else
    echo "Skipping refactor phase"
    STATE=$(echo "$STATE" | jq ".increments[] | select(.id == \"$INC_ID\") | .status = \"complete\"")
  fi
```

## Save State

Save updated increment state:

```bash
echo "$STATE" > "$STATE_FILE"
echo "State saved to: $STATE_FILE"
```

## Continue or Complete

Check for more pending increments:

```bash
REMAINING=$(echo "$STATE" | jq '[.increments[] | select(.status == "pending")] | length')

if [ "$REMAINING" -gt 0 ]; then
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📊 Progress: $REMAINING increments remaining"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "Continue with next increment? (yes/no): "
  read -r CONTINUE
  
  if [[ "$CONTINUE" =~ ^[Yy] ]]; then
    echo "Restarting TDD workflow for next increment..."
    # Loop continues to process next increment
  else
    echo "TDD workflow paused. Resume anytime with: tdd.implement"
  fi
else
  echo ""
  echo "🎉 All TDD increments complete!"
  echo ""
  echo "Run tdd.validate to check test quality:"
  echo "EXECUTE_COMMAND: tdd.validate"
fi
```

## Summary Output

```bash
echo ""
echo "=========================================="
echo "TDD Workflow Summary"
echo "=========================================="
echo ""
echo "Language: $LANGUAGE"
echo "Framework: $FRAMEWORK"
echo "State file: $STATE_FILE"
echo ""
echo "Completed increments:"
echo "$STATE" | jq -r '.increments[] | select(.status == "complete") | "✅ " + .id + ": " + .description'
echo ""
echo "Green complete (ready for refactor):"
echo "$STATE" | jq -r '.increments[] | select(.status == "green_complete") | "🟢 " + .id + ": " + .description'
echo ""
echo "Pending increments:"
echo "$STATE" | jq -r '.increments[] | select(.status == "pending") | "⏳ " + .id + ": " + .description'
```

## Extension Hooks

This command is triggered by the `after_implement` hook from `/spec.implement`.

After execution, it can trigger follow-up hooks:

```bash
echo ""
echo "📦 Post-implementation hooks available:"
echo "EXECUTE_COMMAND: tdd.validate"
```