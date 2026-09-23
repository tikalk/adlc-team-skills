# Mission Brief Template (Canonical Factory Contract)

> **Canonical source of truth** for the mission-brief format across the factory.
> Consumed by `factory-queue` (plan mode — generated issues) and `mission-brief`
> (execution — run intake). Milestones themselves are NOT briefs: milestone
> descriptions carry the demo sentence + done-means; gate/task issues carry briefs.

## Format

```markdown
## Mission Brief

**Goal**: <what to build — one sentence>

**Constraints**: <tech stack, limitations, dependencies, requirements>

**Non-Goals**: <what is explicitly out of scope>

**Success Criteria**:
- <measurable outcome 1> — *measurement method*
- <measurable outcome 2> — *measurement method*
```

## Rules

1. **Every criterion is measurable** — each Success Criteria bullet names its
   verification method (logs, artifacts, reports, drills).
2. **Non-Goals are mandatory** — especially the adjacent gates (what the
   *next* issue owns) and deferred scope.
3. **Gate/phase/depends line** — queue-generated issues append a metadata line:
   `**Gate**: <id> · **Phase**: <phase> · **Depends on**: <ids>`.
4. **References section** — link (never paste) the governing records:
   PDR file, PRD section, AD section, ADRs. Links point at `main` so they
   track current content; the owning milestone stays frozen as the decision record.
5. **Neutral component language** — issues describe the system, not the org:
   no organization names, no internal-infrastructure names. The execution
   environment is "the reference deployment"; the end state is "any" cluster/customer.
6. **Outcomes live in Success Criteria, not titles** — issue titles are short
   work-item names; prefixes (`[G1]`, `M5:`) are redundant with milestone
   assignment and MUST NOT be used.
