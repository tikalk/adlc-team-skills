---
description: Link feature to existing PDR (silent if no PDRs exist)
---

## Goal

Lightweight PDR check for the `before_specify` hook.
- If no PDRs exist → exit silently (NO OUTPUT)
- If PDRs exist → present selection, return reference for spec header

## User Input

```text
$ARGUMENTS
```

The arguments may contain feature description context, but this command focuses on PDR linkage, not feature specification.

## Role & Context

You are acting as a **Product Linker** - your job is to find and link an existing Feature PDR to the feature being specified.

## PDR Locations (Priority Order)

Check for PDR file in this order:

1. **`{REPO_ROOT}/.specify/memory/pdr.md`** - Project canonical (Accepted PDRs)
2. **`{REPO_ROOT}/.specify/drafts/pdr.md`** - Working copy (Proposed/Discovered PDRs)

## Execution Steps

### Step 1: Check for PDR File

Attempt to read PDR file from locations in priority order above.

- If **no PDR file exists** in any location → **SILENT EXIT** (no output at all)
- If PDR file exists → proceed to Step 2

### Step 2: Parse Feature PDRs

From the PDR file:

1. Find all PDRs with `Category: Feature`
2. For each Feature PDR, find the Milestone reference:
   - Look in "Related PDRs" field
   - Or "Belongs to Milestone" field
   - Or "Milestone" field
3. Build a list of Feature PDRs with their Milestone reference

### Step 3: Present Selection to User

If Feature PDRs exist:

```markdown
## PDR Reference Selection

Which Feature PDR does this feature belong to?

| Option | Feature PDR | Milestone |
|--------|--------------|-----------|
| 1 | PDR-003: OAuth2 Login | M01: Q2 User Auth |
| 2 | PDR-004: SSO Integration | M01: Q2 User Auth |
| 3 | PDR-005: Password Reset | M02: Q3 Enhancements |
| 4 | Skip - No PDR linkage |

**Your choice**: _[Wait for user response]_
```

### Step 4: Output Result

After user selects (or skips):

**If user selects a PDR**:
```markdown
## PDR Link Result

**Milestone Reference**: M01: Q2 User Auth
**Feature PDR Reference**: PDR-003
```

**If user skips or no Feature PDRs exist**:
```markdown
## PDR Link Result

(No PDR selected)
```

## Key Behavior Rules

1. **Silent if no PDRs** - If no PDR file exists in any location, output NOTHING and exit
2. **Read-only** - Do not modify any PDR files
3. **Optional** - User can always skip PDR linkage
4. **Feature PDRs only** - Only show PDRs with Category: Feature (not Problem, Scope, etc.)

## Usage in Hook Context

This command is designed for the `before_specify` hook. The output can be used by `spec.specify` to populate:

- Spec header's Milestone Reference field
- Spec header's Feature PDR Reference field

If this command outputs nothing (silent exit), `spec.specify` should continue without PDR references.

---

## Context

{ARGS}