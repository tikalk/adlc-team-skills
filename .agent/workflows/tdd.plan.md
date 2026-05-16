---
description: TDD planning phase - plan tests before writing code
---


<!-- Extension: tdd -->
<!-- Config: .specify/extensions/tdd/ -->
# TDD Plan: Planning Phase Before Tests

This command helps you think through your design **before** writing any tests or implementation code. Based on TDD principles.

## Planning Questions

Answer these questions before writing your first test:

### 1. What interface changes are needed?

Identify the public functions, methods, or APIs being added or modified:

- **What new functions/methods are needed?**
  ```
  Examples:
  - add(a, b) → returns sum
  - divide(a, b) → returns quotient or raises error
  - createUser(data) → returns User object
  ```

- **Can we verify through returned results (not side effects)?**
  ✅ **GOOD**: Function returns calculated value
  ❌ **AVOID**: Directly querying database, writing to file

- **Avoid**: 
  - Bypassing interface (db.query(), fs.writeFile())
  - Testing side effects instead of results
  - Verifying HOW instead of WHAT

### 2. Which behaviors matter most?

You can't test everything. Prioritize:

```
HIGH PRIORITY:
- Critical business logic
- Complex algorithms
- User-facing features
- Security concerns
- Error handling paths

MEDIUM PRIORITY:
- Configuration options
- Edge cases
- Performance scenarios

LOW PRIORITY:
- Trivial getters/setters
- Mechanical operations
```

**Start with order**: Degenerate cases → Happy paths → Edge cases → Error cases

### 3. Can we design for deep modules?

Deep module = small interface, complex internals

```
SHALLOW MODULE (hard to test):
- Large interface with many options
- Behavior scattered across many methods
- Many dependencies

DEEP MODULE (easy to test):
- Small, focused interface
- Complex behavior hidden inside
- Minimal dependencies
```

**Goal**: Design APIs that are simple to use, easy to test

### 4. Design for testability?

Make your code testable from the start:

**✅ Test-friendly designs:**
```python
# Accept dependencies as parameters
def calculate(data, validator=None):
    # Pure function - no side effects
    # Returns result - easy to test
    return validator(data)
```

**❌ Test-hostile designs:**
```python
# Creates dependencies internally
def calculate(data):
    validator = DatabaseValidator()  # Hard to mock
    db = DatabaseConnect()           # Side effects
    validator.save(data)             # Hard to verify
```

**Principles:**
- Accept dependencies as parameters (don't create them)
- Return results (don't produce side effects)
- Pure functions (no global state, no I/O)

### 5. Vertical slicing constraint

**ONE test → ONE implementation → repeat**

This constraint prevents:
- ❌ Bulk tests that verify imagined behavior
- ❌ Tests written before code exists (hallucinated)
- ❌ Tests that are too broad/wide

**Red phase constraint:**
- Test MUST fail first
- If it passes immediately → either:
  - Behavior already implemented, OR
  - Test isn't asserting right thing
- **STOP** and fix before proceeding

## Planning Checklist

Before writing tests, review:

```markdown
- [ ] Public interfaces identified (not internals)
- [ ] Can verify through returned values (not side effects)
- [ ] Behaviors prioritized (critical > happy path > edge cases)
- [ ] Design allows deep modules (small interface)
- [ ] Dependencies accepted as parameters (not created)
- [ ] Tests will fail FIRST (red phase constraint)
```

## Output Planning Notes

Document your answers:

```bash
echo "## TDD Plan: $FEATURE"
echo ""
echo "### 1. Interface Changes Needed"
echo "- List public functions, methods, APIs"
echo ""
echo "### 2. Behaviors to Test (priority order)"
echo "- Degenerate cases"
echo "- Happy paths"
echo "- Edge cases"
echo "- Error cases"
echo ""
echo "### 3. Design Considerations"
echo "- Deep module design"
echo "- Testability notes"
echo "- Dependencies and side effects"
```

## Example Planning Session

```
Feature: Calculator - division operation

### 1. Interface Changes Needed
- Public function: divide(a, b) -> returns quotient
- Returns: number OR string error message

### 2. Behaviors to Test
- Degenerate: divide(0, 5) -> 0
- Happy: divide(10, 2) -> 5
- Happy: divide(7, 3) -> 2.333...
- Edge: divide(-5, 2) -> -2.5
- Error: divide(5, 0) -> "Division by zero"

### 3. Design Considerations
- Pure function (no I/O)
- Accepts parameters, returns result
- No database/file dependencies
- Easy to test in isolation
```

## After Planning

Once planning complete:

```bash
echo "Planning complete. Starting TDD cycles..."
echo ""
echo "Ready for RED→GREEN→REFACTOR workflow:"
echo "EXECUTE_COMMAND: tdd.implement"
```

## References

Inspired by best practices from:
- AIHero TDD: https://www.aihero.dev/skill-test-driven-development-claude-code
- mfranzon/tdd: https://github.com/mfranzon/tdd