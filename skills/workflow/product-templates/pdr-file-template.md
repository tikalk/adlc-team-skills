## PDR-[NNN]: [Decision Title]

### Status

**Proposed** | Accepted | Deprecated | Superseded by PDR-XXX | **Discovered** (Inferred from existing product)

### Date

YYYY-MM-DD

### Owner

[Product Manager / Team / Stakeholder]

### Category

[Problem | Persona | Scope | Metric | Prioritization | Business Model | Feature | NFR | Milestone]

### Feature-Area

[core | business | growth | operations | platform | auth | ...]

### Cross-Feature-Area Metadata
- **Appears in**: [List of feature-area IDs]
- **Cross-area count**: [Number]
- **Is cross-area pattern**: [✓ | ]

### ⚠️ Inconsistency Flags
*None* (or flag details)

### Context
**Problem/Opportunity:**
[Clear description]

**Market Forces:**
- [Market factor 1]
- [Customer feedback]

### Decision
**Decision Statement:**
[Clear statement]

**Rationale:**
[Why this option]

### Consequences
#### Positive
- [Benefit 1]

#### Negative
- [Trade-off 1]

#### Risks
- [Risk with mitigation]

### Success Metrics
| Metric | Target | Measurement Method |
|--------|--------|-------------------|
| [Metric] | [Target] | [Method] |

### Alternatives Considered
#### Option A: [Alternative Name]
**Description:** [Brief description]
**Trade-offs:** [Neutral comparison]

### Constitution/Vision Alignment
| Principle | Alignment | Notes |
|-----------|-----------|-------|
| [Vision Principle] | ✅ Compliant / ⚠️ Deviation | [Explanation] |

### Related PDRs
- [PDR-XXX: Related decision]
- [PDR-XXX: Dependency]

### Issues
> Optional. Full URLs to tracker issues that implement or track this decision.
> Host determines tracker: github.com → GitHub, gitlab.com → GitLab, *.atlassian.net → Jira, linear.app → Linear

- [https://github.com/org/repo/issues/NNN](https://github.com/org/repo/issues/NNN)
- [https://gitlab.com/org/repo/-/issues/NNN](https://gitlab.com/org/repo/-/issues/NNN)

### Evidence
> Optional. Code paths/symbols that prove this feature exists in the codebase.
> Used by product-roadmap for code-vs-PDR verification (Mode A: explicit).
> Missing evidence on a "Completed" PDR triggers a done-means warning.

- `src/auth/oauth/` — OAuth2 login module
- `src/auth/oauth/handlers.ts:42` — token exchange handler
- `test/auth/oauth.test.ts` — OAuth2 integration tests

---

## Milestone PDR Fields *(use when Category = Milestone)*

### Release Goal

[What this milestone/release achieves — one sentence]

### Demo Sentence

**After this milestone, the user can:** [observable capability]

### Done Means

[Explicit definition of what "live/complete" means for this milestone — not "code ready" but the actual go-live condition. Example: "production traffic on new auth flow, legacy login retired" — not "auth code merged to main"]

### Target Date

[Target release date — e.g., "Q1 2026" or "2026-03-31"]

### Tracker Milestone
> Optional. Full URL to a native tracker milestone/epic/project.
> When present, product-roadmap pulls native progress directly from the tracker.

- [https://github.com/org/repo/milestone/NNN](https://github.com/org/repo/milestone/NNN)

### Features Included

| Work Item | PDR Ref | Priority | Demo Sentence | Boundary Dependencies |
|-----------|---------|----------|---------------|----------------------|
| [Feature name] | PDR-003 | Must | "user can ___" | None (leaf) |
| [Feature name] | PDR-004 | Must | "user can ___" | Depends on PDR-003 |
| [Feature name] | PDR-005 | Should | "user can ___" | Depends on PDR-003, PDR-004 |

### Features Deferred

- [Feature deferred to next milestone]
- [Feature deferred to next milestone]

### Gates
> Gates are the bar a milestone must clear before it's "live" — not just tasks done.
> Types: `engineering` (testable condition), `sign-off` (human approval), `time` (elapsed period).

| Gate | Type | Owner | Acceptance Criterion | Status | Evidence |
|------|------|-------|---------------------|--------|----------|
| [Gate name] | engineering | [Team] | [Testable condition] | pending | — |
| [Gate name] | sign-off | [Approver] | [Written approval recorded] | pending | — |
| [Gate name] | time | [Owner] | [N days elapsed since cutover] | pending | — |

### Milestone Success Criteria

| Metric | Target | Measurement Method |
|--------|--------|-------------------|
| [Metric] | [Target] | [How to measure] |

### References

- [Link to documentation, market research, or stakeholder input]
- [Link to competitive analysis]
