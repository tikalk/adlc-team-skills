# Mission Brief Template (Canonical Factory Contract)

> **Canonical source of truth** for the mission-brief format across the factory.
> Consumed by `factory-queue` (plan mode — generated issues), `factory-mission`
> (execution — run intake), and `factory-orchestrator` (research that feeds a
> future brief). Milestones themselves are NOT briefs: milestone
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

**Evidence base** (as of <ISO timestamp>):
- Read: <source> → <claim it supports>
- Counter: <source> → <claim it contradicts or qualifies> | none found in <scope>
- Unread: <source> (<received-at>) — <after cutoff | unavailable | out of scope>
- Self-notes (claims, not evidence): <source> → <claim to verify>

**Framework lane**: <lane> (<evidence>) — the session model inspects the
well-known install paths and discloses what it found; usage hints with no
installed framework disclose and fall back to Default.
```

## Rules

1. **Every criterion is measurable** — each Success Criteria bullet names its
   verification method (logs, artifacts, reports, drills).
2. **Non-Goals are mandatory** — especially the adjacent gates (what the
   *next* issue owns) and deferred scope.
3. **Gate/phase/depends line** — queue-generated issues append a metadata line:
   `**Gate**: <id> · **Phase**: <phase> · **Depends on**: <ids>`.
4. **References section** — link (never paste) the governing records that
   apply to the work. Links point at `main` so they track current content;
   the owning milestone stays frozen as the decision record.
5. **Neutral component language** — issues describe the system, not the org:
   no organization names, no internal-infrastructure names. The execution
   environment is "the reference deployment"; the end state is "any" cluster/customer.
6. **Outcomes live in Success Criteria, not titles** — issue titles are short
   work-item names; prefixes (`[G1]`, `M5:`) are redundant with milestone
   assignment and MUST NOT be used.

### Evidence base rules (R1–R4)

1. **R1 — Read means summarized.** Every `Read` entry names the claim the
   source supports. A bare citation belongs under `Unread`, not `Read`.
2. **R2 — Counter-evidence is required.** The `Counter` bucket is never
   omitted; `none found in <scope>` is a valid, explicit entry. Silence is a
   defect, not a clean bill.
3. **R3 — Self-notes are claims, not evidence.** A source authored by the
   requester appears only under `Self-notes`. It needs an independent `Read`
   source or a recorded decision before it becomes a Constraint or Success
   Criterion.
4. **R4 — The cutoff is declared.** `as of <ISO timestamp>` is mandatory;
   sources arriving later are listed under `Unread` with their timestamp and
   reason, never silently dropped.

The block is never absent by omission: a brief with no external sources states
`Evidence base: direct request — no external sources.`
