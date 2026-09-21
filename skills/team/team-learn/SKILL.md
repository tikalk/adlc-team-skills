---
name: team-learn
description: Use when a session ends to extract CDRs, score confidence, batch review, and publish accepted CDRs to team-ai-directives. Auto-triggers on session_end event.
disable-model-invocation: true
scripts:
  sh: scripts/team-learn.sh
  ps: scripts/team-learn.ps1
---

# team-learn

## What this skill does

Session-end CDR lifecycle — extracts reusable patterns from the completed
session, scores them by confidence, presents for batch review, and publishes
accepted CDRs as a draft PR to `team-ai-directives`.

Replaces the former `levelup-specify`, `levelup-clarify`, and `levelup-publish`
skills with a single streamlined workflow.

## When to use

- **Session end (automatic)**: `.events.json` maps `session_end` → this skill
- **Manual invocation**: `/team-learn` after completing work
- **Before closing a branch**: Extract team-wide learnings

### When NOT to use

- **Brownfield discovery**: Use `/team-init` to scan existing code
- **ADR/PDR/ChDR capture**: Use the respective clarify skills (architect-clarify, product-clarify, change-clarify)

## Storage

CDR drafts live in the `adlc` orphan branch of `team-ai-directives`:

```
team-ai-directives (adlc branch, orphan)
├── drafts/cdr/
│   ├── CDR-001.md        # Pending CDR
│   └── cdr.md            # Draft index
└── reports/
    ├── sessions/<user>/<YYYY-MM>.md
    ├── projects/<project>.json
    └── confidence-scores.json
```

Main branch has NO drafts directory — only accepted CDRs in `context_modules/`.

## Process

### Phase 0: Environment Setup

Run the setup script:

```bash
scripts/team-learn.sh --setup
```

Parse JSON for `REPO_ROOT`, `TEAM_AI_DIRECTIVES`, `NEXT_CDR`, `ADLC_BRANCH_EXISTS`.

If `TEAM_AI_DIRECTIVES` is not configured, exit with message to run `/team-setup`.

### Phase 1: Extract CDRs from Session

Review the current session to identify reusable patterns:

1. What did the user ask for?
2. What did the agent do? (file changes, key decisions, approach)
3. What reusable patterns emerged?
4. What files were created/modified? (`git diff --stat`, `git log --oneline -10`)

For each pattern, create a CDR draft using the lightweight template.

Write session trace to `adlc` branch: `reports/sessions/<user>/<YYYY-MM>.md`.

### Phase 2: Score Confidence

For each extracted CDR, calculate confidence:

**Base scores by type:**
- Rule: 0.60
- Persona: 0.50
- Example: 0.50
- Constitution: 0.70

**Bonuses:**
- +0.20 if paired eval exists
- +0.10 if evidence includes file paths/commits
- +0.10 if multiple projects reference same pattern

**Usage multiplier** (from `reports/confidence-scores.json`):
- success_rate > 0.8: ×1.2
- success_rate 0.5-0.8: ×1.0
- success_rate < 0.5: ×0.8

**Thresholds:**
- ≥ 0.8: HIGH — batch review, auto-accept after review
- 0.5-0.79: MEDIUM — batch review required
- < 0.5: LOW — keep as draft

### Phase 3: Batch Review

Present CDRs one at a time (same as former levelup-clarify logic):

```markdown
## CDR-{ID}: {Title}

**Context Type**: {type}
**Confidence**: {score} ({HIGH/MEDIUM/LOW})
**Current Status**: {status}

### Current Content
...

### Choose Action

| Option | Action |
|---|---|
| A | Accept — Approve for implementation |
| B | Reject — Decline with reason |
| C | Defer — Skip for now, keep pending |
| D | Accept all remaining — Accept this and all pending CDRs |
| P | Promote to check (mechanical rules only) |

Reply with your choice (A/B/C/D/P).
```

Wait for user input before proceeding. Update CDR file after each decision.

### Phase 4: Publish

For accepted CDRs, create a draft PR to `team-ai-directives` main branch:

1. Switch to `adlc` branch worktree
2. Read accepted CDRs from `drafts/cdr/`
3. Transform to OKF v0.2 format with confidence frontmatter
4. Write to `context_modules/` in main branch
5. Create branch, commit, push, open draft PR

### Phase 5: Write Usage Data

Write to `adlc` branch:

- `reports/sessions/<user>/<YYYY-MM>.md` — privacy-scrubbed session summary
- `reports/projects/<project>.json` — CDR match/apply counts
- Update `reports/confidence-scores.json`

### Phase 6: Notify

Write report to `.adlc/team-learn-report.md` (local, not committed):

```markdown
## Team-Learn Report

**Date**: {date}
**CDRs Extracted**: N
**CDRs Accepted**: N
**CDRs Rejected**: N
**CDRs Deferred**: N
**PR**: {URL or "none — no accepted CDRs"}

### Next Steps
1. Review PR (if created)
2. Run `/team-repair --update-confidence` after merge
```

## Conflict Resolution

When two projects draft the same pattern:
1. First draft creates CDR-001 with `project: project-a`
2. Second draft detects existing CDR with matching descriptor → merges:
   - Adds project-b to `project:` field
   - Appends evidence section
   - Increments confidence (multi-project validation)

## Verification

- [ ] CDRs written to `adlc` branch `drafts/cdr/`
- [ ] Session summary written to `adlc` branch `reports/sessions/`
- [ ] Usage counts written to `adlc` branch `reports/projects/`
- [ ] Accepted CDRs published as draft PR to main branch
- [ ] team-learn-report.md written locally
- [ ] No drafts in main branch
