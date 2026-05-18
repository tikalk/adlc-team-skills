---
description: "Validate plan alignment with architecture (READ-ONLY)"
---

# adlc.architect.validate

Validate that the plan aligns with the architecture and identify any blocking issues.

## Usage

```text
/architect.validate --for-plan
/architect.validate --json
/architect.validate --system-only
/architect.validate --check-only PILLAR_3
```

## Flags

| Flag | Description |
|------|-------------|
| `--for-plan` | Validate against the generated plan (default behavior) |
| `--json` | Output findings in JSON format for easier parsing |
| `--system-only` | Check only system-level ADRs, ignore feature-level |
| `--check-only [check]` | Run only specific checks: PILLAR_1, PILLAR_2, PILLAR_3, or DIAGRAMS |

## Behavior

This is a **READ-ONLY** validation command. It does not modify any files.

### When Architecture Exists

If ADRs exist in any location (check all three):

1. Load ADRs from all locations (priority order):
   - `{REPO_ROOT}/.specify/memory/adr.md` (canonical - Accepted ADRs)
   - `{REPO_ROOT}/.specify/drafts/adr.md` (working copy - Proposed/Discovered)
2. Load architecture description from `AD.md` (if present)
3. Load the generated plan from `{REPO_ROOT}/.specify/memory/plan.md`
4. Execute 7 PILLAR 3 checks:
   - **PILLAR_1**: Component-level ADR alignment with plan
   - **PILLAR_2**: Interface contracts match between plan and ADRs
   - **PILLAR_3**: Data model consistency between plan and architecture
   - **PILLAR_4**: Consistency between plan's Q1 user flows and architecture's System Context
   - **PILLAR_5**: Consistency between plan's interactions and architecture's Functional View
   - **PILLAR_6**: Consistency between plan's data model and architecture's Information View
   - **PILLAR_7**: Consistency between plan's dependencies and architecture's Development View
5. Check diagram consistency (system boundary matches, data flows valid)
6. Return findings with severity:
   - **blocking**: Must be fixed before proceeding
   - **high-severity**: Should be fixed before proceeding
   - **warnings**: Recommendations

### When Architecture Doesn't Exist

If no ADRs exist in any location:

- Skip validation gracefully
- Return `{"status":"skipped","reason":"architecture_not_found"}` if `--json` flag used

### Escalation Detection

This command also detects when architectural decisions in the plan **require new ADRs** that don't exist:

1. Analyze plan for architectural keywords:
   - "new database", "new service", "new API", "new infrastructure"
   - "change authentication", "change storage", "change deployment"
2. Compare against existing ADRs
3. If new patterns detected without ADR backing → signal escalation

**Escalation Output:**

```text
⚠️  Escalation Required
   New architectural decisions detected without ADR backing:
   - "Caching layer (Redis)" - No ADR covers caching decisions
   - "Message queue (RabbitMQ)" - No ADR covers async communication

   Run /architect.clarify to document these decisions before proceeding.
```

```json
{
  "escalation": {
    "needed": true,
    "reason": "new_architectural_decision",
    "decisions": [
      {
        "topic": "Caching layer",
        "evidence": "Plan references Redis but no ADR covers caching",
        "suggested_action": "Run /architect.clarify to create ADR"
      },
      {
        "topic": "Async communication", 
        "evidence": "Plan references RabbitMQ but no ADR covers message queuing",
        "suggested_action": "Run /architect.clarify to create ADR"
      }
    ]
  }
}
```

**This enables the `before_plan` hook to signal when new architectural decisions are needed.**

Example output:

```text
⏭️  Architecture not found (no ADRs in drafts/memory)
     Skipping validation gracefully
```

## Output Format

### Console Output (default)

```text
🔍 Architecture Validation Mode (READ-ONLY)

📋 ADR files found: N
   - memory: X ADR(s)
   - drafts: Z ADR(s)

Executing validation checks...
   ✓ PILLAR_1: Component alignment (0 issues)
   ✗ PILLAR_2: Interface contracts (2 high-severity)
   ✓ PILLAR_3: Data model consistency (0 issues)
   ✓ PILLAR_4: System context (0 issues)
   ⚠️  PILLAR_5: Functional consistency (3 warnings)
   ✓ PILLAR_6: Information view (0 issues)
   ✓ PILLAR_7: Development view (0 issues)
   ⚠️  Diagram consistency (2 warnings)

Blockers: 0
High-severity: 2
Warnings: 5
```

### JSON Output (`--json`)

```json
{
  "status": "success",
  "action": "validate",
  "adr_locations": {
    "memory": "{REPO_ROOT}/.specify/memory/adr.md",
    "drafts": "{REPO_ROOT}/.specify/drafts/adr.md"
  },
  "adr_count": 12,
  "findings": {
    "blocking": [],
    "high_severity": [
      {
        "check": "PILLAR_2",
        "component": "UserAuthService",
        "issue": "Interface contract missing from plan",
        "description": "Plan references UserAuthService.login() but ADR doesn't define this method"
      },
      {
        "check": "PILLAR_2",
        "component": "OrderService",
        "issue": "Parameters don't match ADR specification",
        "description": "ADR expects createOrder(userId, items) but plan uses createOrder(items) without userId"
      }
    ],
    "warnings": [
      {
        "check": "PILLAR_5",
        "component": "Functional view",
        "issue": "Missing interaction in AD.md",
        "description": "Plan describes user registration flow but AD.md Functional View doesn't include AuthService.register()"
      }
    ],
    "diagrams": {
      "consistency": "warning",
      "issues": [
        {
          "diagram": "Context View",
          "issue": "External system not shown",
          "description": "Plan references PaymentGateway but Context View doesn't include this external system"
        }
      ]
    }
  },
  "summary": {
    "total_checks": 8,
    "passed": 5,
    "warnings": 3
  }
}
```

## Integration

This command is automatically called by the `after_plan` hook:

- Validates plan alignment with architecture
- The command itself checks for architecture existence and skips gracefully
- Returns `{"status":"skipped","reason":"architecture_not_found"}` if no architecture exists

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success or skipped gracefully |
| 1 | Validation failed with blocking issues |
