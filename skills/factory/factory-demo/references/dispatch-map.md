# factory-demo dispatch map

The anchor-to-owner dispatch contract.

Each runbook `### demo/*` anchor family dispatches to exactly one owning
skill. The walker invokes the skill (via the Skill tool) and reports; it
never performs the segment's work itself.

| Anchor family | Owning skill | Walker role |
|---|---|---|
| pre-flight, triage | `factory-queue` | invoke, report |
| intent-records, gates | `factory-intent` | invoke, wait for human verdict |
| follow-through, runs | `factory-mission` | invoke, wait for `validation` |
| review | `factory-review` | invoke per head/push |
| merge-close | `factory-release` / `factory-learn` / `factory-clean` | narrate; humans merge |
| runbook | — (walker meta: fill Evidence links, second person dry-runs) | no dispatch; the dry-run report IS the artifact |

Human gates the walker MUST pause at (never auto-answer, never skip):

1. **Intent Gate** — no brief is approved or rejected without a human.
2. **PDR/ADR gates** — scoped record approvals (M19: PDR-DEMO-001, ADR-DEMO-001).
3. **Spec approval** — implementation does not start until the user approves.
4. **PR hand-off** — findings only; never an approval or denial.
5. **Merge** — merge is human only.

`--customer` threading: the customer name (default `Tikal`) is threaded into
mission briefs and verifications (M19: the `/factory-demo?customer=<name>`
welcome page). Slug derivation for branch names follows the runbook's
convention; when the runbook names no sanitizer, lowercase the customer
verbatim and fail closed on an empty result.
