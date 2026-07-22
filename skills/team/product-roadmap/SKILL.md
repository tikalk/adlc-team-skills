---
name: product-roadmap
description: Track milestone progress across four layers of truth — decision state (PDR status), execution state (live issue tracker via MCP), evidence state (code-vs-PDR verification), and gate state (milestone gates). Shows honest completion, done-means warnings, and updates status only when all layers are green. Use for weekly progress checks and milestone validation.
disable-model-invocation: true
---

# product-roadmap

## What this skill does

Tracks product milestone progress across **four layers of truth** — because "done" is a stronger claim than "tasks complete":

| Layer | Question | Source |
|---|---|---|
| **Decision** | Was the decision made/approved? | PDR status (Proposed → Accepted → Completed) |
| **Execution** | Was the work done? | Live issue states via MCP (GitHub / GitLab / Jira / Linear) |
| **Evidence** | Does the code actually show it? | Code-vs-PDR verification (init concept) |
| **Gates** | Was the bar cleared? | Milestone PDR gate table |

A milestone is **live** only when all four layers are green. Anything less gets a done-means warning.

## When to use

- Weekly progress check
- Before release to verify milestone completion
- Quarterly roadmap review
- After closing issues to check if milestone can be promoted

## When NOT to use

- No PDRs exist (use `/product.specify` or `/product.init` first)
- You want to create PDRs (use `/product.specify`)

## Execution Steps

### Phase A: Load PDRs

```bash
sh: scripts/bash/setup-product-roadmap.sh [--json]
ps: scripts/powershell/setup-product-roadmap.ps1
```

**Read PDR files** (memory first, drafts fallback):
1. `{REPO_ROOT}/.adlc/memory/pdr/PDR-*.md` (Accepted/Completed)
2. `{REPO_ROOT}/.adlc/drafts/pdr/PDR-*.md` (Proposed/Discovered)

**Identify milestones**: PDRs with `Category: Milestone`. These define the roadmap structure and contain the `### Gates` table, `### Features Included` table, `### Done Means` definition, and optional `### Tracker Milestone` URL.

### Phase B: Issue State via MCP

**Extract issue URLs** from all PDRs — look for `### Issues` sections containing full URLs.

**Detect tracker from URL host**:

| URL host | Tracker | MCP tool pattern |
|---|---|---|
| `github.com` | GitHub | `github_*` MCP tools |
| `gitlab.com` | GitLab | `gitlab_*` MCP tools |
| `*.atlassian.net` | Jira | `jira_*` MCP tools |
| `linear.app` | Linear | `linear_*` MCP tools |

**Query issue states** — for each issue URL, use the matching MCP tool to get state (open/closed/in-progress):

```
GitHub:   gh issue view NNN --json state,title,labels  (CLI fallback if MCP unavailable)
GitLab:   glab issue view NNN                            (CLI fallback)
Jira:     jira issue view ISSUE-KEY                      (CLI fallback)
Linear:   linear issue view ISSUE-ID                     (CLI fallback)
```

**Native milestone link** — if a milestone PDR has a `### Tracker Milestone` URL:
- Pull native progress directly from the tracker (closed/total + due date)
- Use as the authoritative execution rollup; skip per-issue queries for that milestone

**Degradation ladder** (when MCP or CLI unavailable):
1. Try MCP tool for that tracker
2. Fall back to CLI (`gh`/`glab`/`jira`/`linear`)
3. If neither available → report issue refs as "state unknown" + one warning per tracker

**Execution status per issue**:

| State | Meaning |
|---|---|
| `closed` / `done` | ✅ Work complete |
| `open` + in-progress label/assignee | 🔄 In progress |
| `open` + unassigned | ⏳ Not started |

### Phase C: Code-vs-PDR Verification (Init Concept)

> Code is ground truth; PDRs are claims. A feature marked complete where the code shows nothing is drift.

For each feature PDR in a milestone, verify code evidence:

**Mode A — Explicit Evidence** (preferred):
- Read the PDR's `### Evidence` section (list of code paths/symbols)
- Verify each path exists: `test -f "{path}"` or `test -d "{path}"`
- Status: `verified` (all paths exist) | `stale` (some paths missing) | `missing` (no Evidence section)

**Mode B — Heuristic** (fallback, init-style):
- No Evidence section → reuse product-init's directory-detection logic
- Check if the PDR's `Feature-Area` directory exists: `test -d "src/{feature-area}/"`
- Optionally grep for title keywords in the codebase
- Lower confidence — reported as "heuristic evidence"

**Hand-off rule**: deep re-discovery is NOT roadmap's job. When evidence is missing/stale on a "Completed" item, the report says: *"⚠️ Code evidence missing — run /product.init to re-discover"*. Roadmap does lightweight checks; full discovery stays in init.

### Phase D: Gate Rollup

Read each milestone PDR's `### Gates` table. For each gate:

| Gate type | How to check |
|---|---|
| `engineering` | Check linked issue states or Evidence verification |
| `sign-off` | Check for approval evidence (date recorded, approver named) |
| `time` | Calculate elapsed days since cutover date vs. required period |

**Gate status**: `green` (criterion met + evidence recorded) | `pending` (not yet met) | `unknown` (no gates section — legacy PDR)

### Phase E: Report

Generate the combined four-layer progress report:

```markdown
## Product Roadmap Progress

### M01: Q2 User Auth — *Done means: production traffic on new auth, legacy login retired*
Tracker: github.com/org/repo/milestone/3 (native: 67% closed, due Sep 5)

| Item | Decision | Execution | Evidence | Status |
|------|----------|-----------|----------|--------|
| PDR-003: OAuth2 login | ✅ Completed | ✅ 3/3 closed (#142–#144) | ✅ src/auth/oauth/ verified | Live |
| PDR-004: SSO | ✅ Accepted | 🔄 2/4 closed (#186–#189) | ⚠️ no evidence section | In progress |
| PDR-005: Password reset | 🔄 Proposed | ⏳ 0/2 (#190, #191) | ❌ src/auth/reset/ missing | Not started |

| Gate | Type | Owner | Status |
|------|------|-------|--------|
| Security review passed | engineering | Sec team | ✅ green |
| Clinician sign-off | sign-off | Maya | ⏳ pending |
| 7-day cooling period | time | Lead | ⏳ pending (day 3/7) |

**Features**: 1/3 · **Issues**: 5/9 closed · **Gates**: 1/3 green · **Live**: No

⚠️ Done-means check: "production traffic on new auth" cannot be true while
2 items lack execution and 2 gates are pending.
```

**Done-means warnings** — when a milestone claims "live" or "complete" but layers aren't green:

| Condition | Warning |
|---|---|
| All features Completed but issues still open | "⚠️ Features claim complete but N issues still open — execution not finished" |
| All issues closed but code evidence missing | "⚠️ Issues closed but code evidence missing — verify with /product.init" |
| All features done but gates pending | "⚠️ Features done, milestone NOT live — N gates pending: [list]" |
| Milestone marked Completed but no gates section | "⚠️ Milestone has no gates — consider adding acceptance criteria" |

**Summary across milestones**:

```markdown
## Overall Roadmap

| Milestone | Target | Features | Issues | Gates | Live |
|-----------|--------|----------|--------|-------|------|
| M01: Q2 User Auth | Sep 5 | 1/3 | 5/9 | 1/3 | No |
| M02: Q3 Enhancements | Oct 15 | 0/2 | 0/5 | 0/2 | No |
```

### Phase F: Update Status (Optional)

**Only if user explicitly requests update** (e.g., "update" in arguments):

For each feature PDR:
- **All linked issues closed** AND **evidence verified** → update status to `Completed`
- Issues still open OR evidence missing → **block update**, report: "Cannot mark PDR-XXX as Completed: N issues open / evidence missing"
- **Override**: user explicitly says "force" → update with a warning annotation

For each milestone PDR:
- **All features Completed** AND **all gates green** → update status to `Completed`
- Otherwise → **block update**, report pending items/gates
- **Override**: user explicitly says "force" → update with warning

**Write updated PDR files** with new status, preserving all other content.

**Regenerate `pdr.md` index** after any updates.

## Tracker Detection Order

When querying issue states, detect available tools in this order:

1. **MCP tools** (preferred) — check which MCP servers are connected:
   - GitHub: `github_*` tools available
   - GitLab: `gitlab_*` tools available
   - Jira: `jira_*` tools available
   - Linear: `linear_*` tools available

2. **CLI fallback** — if MCP for that tracker is unavailable:
   - GitHub: `gh` CLI
   - GitLab: `glab` CLI
   - Jira: `jira` CLI
   - Linear: `linear` CLI

3. **No access** — if neither MCP nor CLI is available for a tracker:
   - Report issue URLs as "state unknown"
   - Emit one warning per unresolvable tracker
   - Continue with decision/evidence/gate layers

## Key Rules

### Four-Layer Honesty
- A milestone is **live** only when ALL four layers are green (decision + execution + evidence + gates)
- Never report "complete" based on one layer alone
- Done-means warnings are mandatory when layers disagree

### Issue References
- Issue URLs in PDRs must be **full URLs** (host determines tracker)
- Native tracker milestone links are optional but preferred (pull native progress)
- Missing issue refs → execution layer reported as "no tracker linkage"

### Code Verification
- Mode A (explicit Evidence) is preferred — PDRs should carry `### Evidence` with code paths
- Mode B (heuristic) is a fallback — lower confidence, reported as such
- Deep re-discovery is init's job, not roadmap's — hand off with a suggestion

### Status Updates
- `--update` blocks on pending issues/gates/evidence unless explicit override
- Only update PDR status, not PRD directly — `/product.implement` regenerates PRD
- Preserve all other PDR fields when updating status

### Backward Compatibility
- PDRs without `### Gates` → gates layer = "no gates declared" + hint to add them
- PDRs without `### Issues` → execution layer = "no tracker linkage"
- PDRs without `### Evidence` → evidence layer = heuristic (Mode B)
- Legacy milestones still work — completion = features only, with a suggestion to adopt gates

## Configuration

- `PDR_DRAFTS_DIR` — `{REPO_ROOT}/.adlc/drafts/pdr`
- `PDR_MEMORY_DIR` — `{REPO_ROOT}/.adlc/memory/pdr`
- `PRD_FILE` — `{REPO_ROOT}/PRD.md`
- MCP servers — GitHub, GitLab, Jira, Linear (auto-detected)
- CLI tools — `gh`, `glab`, `jira`, `linear` (fallback)

## 12-Factor Alignment

- **Factor III (Mission Definition)**: Tracks mission progress with honest done-means semantics
- **Factor IX (Verification-First)**: Verifies claims against code evidence and live tracker state
- **Factor XI (Directives as Code)**: Gate state is version-controlled inside PDR files

## Common Rationalizations

| Rationalization | Reality |
|-----------------|---------|
| "The issues are all closed, so it's done." | Closed issues don't prove the code works. Evidence layer catches drift. |
| "I'll just mark the PDR as Completed manually." | Without gates green, "Completed" is a claim, not a verified state. --update blocks this. |
| "We don't need issue tracking — PDR status is enough." | Self-reported status drifts. Live tracker state is ground truth for execution. |
| "The roadmap can't reach the tracker, so let's skip it." | Degradation is built in — report "state unknown" and continue with other layers. |

## Red Flags

- **Marking a milestone live with pending gates** — gates are the bar, not a suggestion.
- **Trusting issue state without code evidence** — closed issues can close prematurely; code is ground truth.
- **Skipping the done-means check** — "code ready" ≠ "production traffic moved". The Done Means field exists precisely to prevent this confusion.
- **Running full discovery inside roadmap** — deep re-discovery is init's job. Roadmap does lightweight checks and hands off.

## Verification

- [ ] All PDR files loaded (memory + drafts)
- [ ] Milestone PDRs identified with their Features Included and Gates tables
- [ ] Issue URLs extracted from PDRs
- [ ] Issue states queried via MCP (or CLI fallback, or reported as unknown)
- [ ] Native tracker milestone progress pulled where links exist
- [ ] Code evidence verified (Mode A explicit, Mode B heuristic)
- [ ] Gate states rolled up per milestone
- [ ] Four-layer report generated with per-item status
- [ ] Done-means warnings emitted for mismatched layers
- [ ] Overall roadmap summary table generated
- [ ] `--update` blocked correctly on pending layers (if requested)
- [ ] `pdr.md` index regenerated after any updates
- [ ] Zero files modified unless `--update` explicitly requested
