# Review Policy — REVIEW.md Format and Pass Definitions

## Overview

`REVIEW.md` is the policy-as-code file that defines what `factory-review` checks on every PR. It lives at the repository root. If absent, `factory-review` creates a default template on first run.

---

## REVIEW.md Format

```markdown
# Review Policy

## Review Passes

### pass: bugs
**Description:** Bugs and logical errors
**Severity:** Important
**Checks:**
- Null/undefined access paths
- Off-by-one errors
- Unhandled error paths
- Race conditions and concurrency bugs
- Resource leaks (memory, file handles, connections)

### pass: security
**Description:** Security vulnerabilities
**Severity:** Important
**Checks:**
- Injection vulnerabilities (SQL, XSS, command injection)
- Authentication/authorization bypass
- Secret exposure in code or logs
- Insecure deserialization
- Dependency vulnerabilities (CVEs)

### pass: spec-compliance
**Description:** Compliance against design documents
**Severity:** Important
**Checks:**
- PRD.md requirement coverage
- AD.md architecture compliance
- ADR deviation detection
- API contract conformance

### pass: quality
**Description:** Code quality and maintainability
**Severity:** Nit
**Checks:**
- Naming conventions
- Function/method length
- Cyclomatic complexity
- Dead code
- Missing documentation on public APIs

## Severity Weights

| Severity | Blocks merge? | Triggers fix in self-heal? | Posted as |
|----------|---------------|---------------------------|-----------|
| Important | Yes | Yes | 🔴 blocking finding |
| Nit | No | No (advisory) | 💬 advisory |

## Skip Lists

- `vendor/` — third-party dependencies
- `node_modules/` — installed packages
- `dist/` — build output
- `*.generated.*` — generated files
- `coverage/` — test coverage reports
- `.adlc/` — factory artifacts

## CI-Validated Paths

Paths validated by CI and not re-checked by review:
- `package-lock.json` — lockfile integrity
- `go.sum` — Go module checksums
- `.github/workflows/` — CI workflow syntax
```

---

## Pass Execution

Each pass is executed by the Review Agent (in `--self-heal` mode) or by factory-review directly (in single-review mode). For each pass:

1. **Read the PR diff** — changed files and their surrounding context.
2. **Read the governing ticket** — linked issues, acceptance criteria, constraints.
3. **Read design documents** — `PRD.md`, `AD.md`, relevant ADRs.
4. **Run the pass's checks** — evaluate the diff against each check item.
5. **Record findings** — each finding states:
   - The reproducible scenario or violated criterion.
   - Actual behavior.
   - Impact.
   - Required correction.
   - Precise file and line when available.
6. **Classify** — assign severity (Important or Nit) per the policy's severity weights.
7. **Deduplicate** — read existing discussions first; reply in an existing thread if the evidence concerns the same issue.

---

## Finding Classification

### Important (blocks merge, triggers fix in self-heal)
- Bugs and logical errors
- Security vulnerabilities
- Spec deviations (PRD/AD non-compliance)
- Memory leaks, resource leaks
- Authentication/authorization bypass
- Breaking API changes not in the spec
- Missing error handling on critical paths

### Nit (advisory, does not block, does not trigger fix)
- Formatting and style preferences
- Naming convention suggestions
- Documentation improvements
- Minor refactoring suggestions
- Code organization preferences

**Rule:** Nits are posted as advisory comments. They never trigger the Fix Agent in self-heal mode. They never block merge-readiness. The PR is marked merge-ready with nits noted.

---

## Outside-Scope Findings

Pre-existing issues unrelated to the PR's changes:

- Label them `Outside ticket scope — human opt-in required`.
- Explain evidence and impact.
- Keep them advisory and non-blocking.
- Move them into scope only after explicit authorization from the PR author or a repository maintainer.

---

## Default Template

If `REVIEW.md` is absent from the repository root, `factory-review` creates the following default:

```markdown
# Review Policy

## Review Passes

### pass: bugs
Description: Bugs and logical errors
Severity: Important
Checks:
- Null/undefined access paths
- Unhandled error paths
- Resource leaks

### pass: security
Description: Security vulnerabilities
Severity: Important
Checks:
- Injection vulnerabilities
- Secret exposure
- Authentication bypass

### pass: spec-compliance
Description: Compliance against design documents
Severity: Important
Checks:
- PRD.md requirement coverage
- AD.md architecture compliance

### pass: quality
Description: Code quality
Severity: Nit
Checks:
- Naming conventions
- Dead code
- Missing documentation

## Severity Weights
| Severity | Blocks merge? | Triggers fix? |
|----------|---------------|---------------|
| Important | Yes | Yes |
| Nit | No | No |

## Skip Lists
- vendor/
- node_modules/
- dist/
- *.generated.*
- .adlc/
```

---

## Twice-Mistake Threshold

If the review detects the same policy violation (same pass + same check item) on a second PR:

1. Automatically trigger a local `levelup-specify` call to extract a preventive rule.
2. Package the rule as a CDR draft targeting the `team-ai-directives` repository.
3. Flag any changes that make current directives outdated.

This implements Principle VIII (The Ratchet Effect): "Treat agent mistakes as permanent signals by implementing a continuous integration loop for agent behavior."
