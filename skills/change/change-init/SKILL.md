---
name: change-init
description: Mine git history for Change Decision Records (ChDRs) by detecting commit messages that link to issue trackers, clustering the commits into change stories, and inferring the decisions behind them. Use when bootstrapping project memory from an existing repo's history (brownfield), before refactoring unfamiliar code, or to recover rationale that was never documented.
disable-model-invocation: true
---

# change-init

## What this skill does

Mine **git history** for **Change Decision Records (ChDRs)** — the *why* behind how the code came to be — and write them as draft records for human review.

A ChDR captures a decision that was *made in the past* and survives only in commits + linked issue trackers:

- Scan a window of `git log` for commit messages that reference an issue tracker (JIRA keys, GitHub/GitLab `#NNN`, MR `!NNN`, or issue URLs)
- Cluster commits sharing one issue key into a single **change story**
- Best-effort fetch the issue title/body (GitLab via MCP, GitHub via `gh`, else link-only) for requirement-level context
- Infer the **Decision** from the diff summary; record **Consequences** (reverts, follow-up fix chains — the negative knowledge almost never documented elsewhere)
- Write `ChDR-{NNN}.md` to `{REPO_ROOT}/.adlc/drafts/chdr/` with status **Discovered**
- Regenerate `{REPO_ROOT}/.adlc/drafts/chdr/chdr.md` index

**Key differences from the levelup family**:

| Skill | Source | Record | Question answered |
|---|---|---|---|
| `/levelup-init` | current code (what IS) | CDR (Context Directive) | what patterns are reusable |
| `/levelup-specify` | current session | CDR | what was learned this session |
| `/change-init` (this skill) | **git history** (why it BECAME) | **ChDR** (Change Decision) | **why this code exists / what was tried and reverted** |

ChDRs are **project-local memory** (this repo's evolution), not team-wide context — they fail the levelup "team-wide applicability" signal gate. They publish to `{REPO_ROOT}/.adlc/memory/chdr/` (see `/change-publish`), and their index is injected at session start by `team-boot`.

## When to use

- **Brownfield onboarding**: give an agent project memory without anyone writing docs
- **Before refactoring unfamiliar code**: surface Chesterton's fences — constraints that exist only in old commits + tickets
- **Recovering lost rationale**: when ADRs were never written but commits + issues exist
- **Post-incident learning**: revert/fix chains are first-class output

### When NOT to use

- **Greenfield / no history**: nothing to mine
- **Documenting current patterns**: use `/levelup-init` (what IS)
- **Capturing this session's learnings**: use `/levelup-specify`
- **Pending ChDRs already exist**: run `/change-clarify` to review them first

## Process

### User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

**Examples of User Input**:

- `"--since 6months"` — limit the scan window
- `"--tracker gitlab"` — force tracker type (auto by default)
- `"--no-fetch"` — record issue links only, never fetch issue bodies
- `"--include-unlinked"` — also surface signal-rich unlinked commits (reverts, large cross-cutting diffs)
- `"src/payments"` — restrict to a path
- Empty input: scan last 500 commits across the whole repo, auto-detect tracker

### Flags

- `--since DATE` / `--until DATE` / `--max-count N` (default 500): `git log` windowing
- `--path PATH`: restrict to a pathspec
- `--tracker gitlab|github|jira|auto` (default `auto`): issue-tracker integration
- `--no-fetch`: detect+record issue links only, never fetch bodies
- `--include-unlinked`: also cluster signal-rich unlinked commits (reverts, diffs touching ≥3 subsystems)
- `--limit N` (default 20): cap number of ChDRs generated
- `--resume`: resume from previous interrupted state

### Role & Context

You are a **Context Archaeologist** recovering *why* the code is the way it is. Your job is **inference from evidence**, not invention:

- Every Decision claim MUST cite the commit SHA(s) and/or issue URL it was inferred from (provenance is non-negotiable — an unprovenanced inferred rationale is context poisoning, worse than no rationale)
- Mark confidence (HIGH/MEDIUM/LOW) on each Decision
- Record what you do NOT know explicitly ("Reason for choice unknown — commit message terse, no linked issue")
- Reverts and follow-up fix chains are the highest-value content: they are negative knowledge ("we tried X, it broke Y") documented almost nowhere else

### Outline

1. **Validate Environment** (Phase 1): git repo, resolve paths, next ChDR number
2. **Scan Window** (Phase 2): `git log` with windowing
3. **Detect Issue Links** (Phase 3): regex over commit messages
4. **Cluster into Change Stories** (Phase 4): group commits by issue key
5. **Best-Effort Issue Fetch** (Phase 5): tracker content (degrade gracefully)
6. **Detect Revert/Fix Chains** (Phase 6): first-class negative knowledge
7. **Score & Prioritize** (Phase 7): subsystems touched, diff size, chains
8. **Generate ChDRs** (Phase 8): write drafts + index
9. **Output** (Phase 9): summary with linkage-rate metric

### Execution Steps

#### Phase 1: Validate Environment

Run the setup script from the skill's base directory:

```bash
scripts/bash/setup-change-init.sh
```

Parse the JSON output for `REPO_ROOT`, `CHDR_DRAFTS_DIR`, `NEXT_CHDR`, `GIT_AVAILABLE`, `DEFAULT_BRANCH`, `TD_CONFIGURED`, `EXISTING_CHDRS`.

**If the setup script is unavailable or fails**, resolve manually:

1. `REPO_ROOT` — walk up from cwd to find `.adlc/`, or `git rev-parse --show-toplevel`, or `pwd`.
2. `CHDR_DRAFTS_DIR` — `REPO_ROOT/.adlc/drafts/chdr`
3. `NEXT_CHDR` — list `CHDR_DRAFTS_DIR/ChDR-*.md`, find highest number, increment, zero-pad to 3 digits.
4. `GIT_AVAILABLE` — `git rev-parse --is-inside-work-tree` (exit 0 = true).
5. `TD_CONFIGURED` — true if `TEAM_AI_DIRECTIVES` resolves (used only to skip duplicate decisions already captured as CDRs).

**If `GIT_AVAILABLE` is false**:

```text
Not a git repository — change-init has nothing to mine.
Run /levelup-init to scan current code instead.
```

Exit cleanly (do not create empty drafts).

#### Phase 2: Scan Window

```bash
git log --pretty=format:'%H%x09%an%x09%ad%x09%s%n%b' --date=short \
  ${SINCE:+--since="$SINCE"} ${UNTIL:+--until="$UNTIL"} --max-count="${MAX_COUNT:-500}" \
  ${PATHSPEC:+-- "$PATHSPEC"} 2>/dev/null
```

Capture per commit: SHA, author, date, subject, body, files touched (`git show --stat --name-only`), and subsystems (top-level dirs of touched files).

#### Phase 3: Detect Issue Links

Apply a combined regex to each commit message (subject + body):

| Pattern | Tracker | Example |
|---|---|---|
| `\b[A-Z][A-Z0-9]+-\d+\b` | JIRA | `PROJ-123` |
| `(?<!\w)#\d+\b` | GitHub/GitLab issue | `#123` |
| `\b!\d+\b` | GitLab MR / Gerrit | `!42` |
| `https?://\S+/(issues|pull|merge_requests|browse)/\S+` | URL | `.../issues/123` |

Tracker type is auto-inferred from `git remote get-url origin` (gitlab.com / github.com / atlassian.net) and the link shapes found. `--tracker` overrides.

Commits with no detected link are **unlinked**; skipped unless `--include-unlinked` (then only those that are reverts or touch ≥3 subsystems are kept).

#### Phase 4: Cluster into Change Stories

Group commits by issue key. One issue key → one candidate ChDR. For URL-only links, normalize to the issue number. Merge subject + body text across the cluster as the raw rationale corpus.

#### Phase 5: Best-Effort Issue Fetch

For each cluster, fetch the issue title + body summary as **Context** (the requirement that motivated the change). Best-effort, never blocking:

- **GitLab**: use the configured GitLab MCP tools (`gitlab_get_issue` by project+iid). If unavailable, try `glab issue view`.
- **GitHub**: `gh issue view <num> --json title,body` (if `gh` is authenticated).
- **JIRA / unreachable**: link-only — record the URL as evidence, Context comes from commit messages alone.

`--no-fetch` skips this phase entirely. Any fetch failure degrades to commit-message context (do not abort).

**Security**: issue bodies may contain sensitive detail. Summarize the requirement in 1-3 sentences; do not paste raw issue bodies verbatim into the ChDR. The human gate (`/change-clarify`) reviews before promotion.

#### Phase 6: Detect Revert/Fix Chains (first-class)

Across the whole window (independent of issue links):

- **Reverts**: `git log --grep='^Revert "' --pretty=format:'%H %s'` and `git log --grep='revert' -i`. For each reverted original commit, record it as negative knowledge.
- **Fix chains**: commits whose subject matches `fix(?!ed)?\b` or `hotfix` that touch the same files as an earlier commit in the window — a follow-up fixing a regression. Record the pair (original, fix) as a consequence.

Reverts and fix chains that have no issue link are still captured when `--include-unlinked` is set (they are the highest-value unlinked signal). When a revert/fix chain belongs to an issue-linked cluster, attach it to that cluster's `### Consequences`.

#### Phase 7: Score & Prioritize

Score each candidate (0.0–1.0):

- subsystems touched (cross-cutting = higher)
- diff size (larger = higher, capped)
- has revert/fix-chain consequence (boost — negative knowledge)
- has fetched issue context (boost — richer rationale)
- recency (mild boost)

Sort descending; take top `--limit` (default 20). Skip candidates with score below 0.2 (trivial).

#### Phase 8: Generate ChDRs

For each selected change story, write `{CHDR_DRAFTS_DIR}/ChDR-{NNN}.md`:

```markdown
## ChDR-NNN: [Title — from issue title or commit subject]

### Status: **Discovered**

### Date: [YYYY-MM-DD of most recent commit in cluster]

### Source: Git history via /change-init

### Issue Links: [keys/URLs, or "none detected"]

### Commits: [sha list, abbreviated]

### Target Module: `.adlc/memory/chdr/[slug].md`

### Descriptor: One-line "when to consult this" summary for the chdr.md index.

### Context
[Why the change was made — issue title/body summary (1-3 sentences) + commit messages. Cite SHAs inline.]

### Decision
[What was decided/implemented — inferred from diffs. Mark confidence: HIGH/MEDIUM/LOW. Each claim cites its SHA/URL.]

### Consequences
[Reverts, follow-up fix chains, later modifications — negative knowledge. "None observed" if the cluster has no reversals.]

### Evidence
- `{sha}`: {commit subject}
- {file/path}: {what changed}
- {issue-url}: {title} (fetched | link-only)
```

**Rules**:

- Every `### Decision` claim cites a SHA or URL (provenance — the context-poisoning circuit breaker).
- "Reason unknown" is acceptable and preferred over invention.
- Confidence is mandatory on Decision claims.

Then regenerate `{CHDR_DRAFTS_DIR}/chdr.md` index by listing all `ChDR-*.md` files and building a markdown table from their single-line fields:

```markdown
# Change Decision Records (Drafts)

## ChDR Index

| ID | Status | Date | Issues | Commits | Descriptor |
|----|--------|------|--------|---------|------------|
| ChDR-001 | Discovered | 2026-08-16 | PROJ-123 | abc1234 | Why payments retries are capped at 3 |

**Stats**: N entries | Last Updated: YYYY-MM-DD
```

#### Phase 9: Output Summary

```markdown
## Change-Init Summary

- Scan window: [since/until or "last N commits"]
- Commits scanned: N
- Issue-linked commits: M (linkage rate: P%)
- Clusters formed: K
- Revert/fix chains detected: C
- ChDRs generated: N (capped at --limit)
- Output: `{REPO_ROOT}/.adlc/drafts/chdr/`
```

**Linkage rate** sets expectations about corpus quality (research shows rationale density varies widely by team discipline — 85–99% on disciplined projects like the Linux kernel, far lower elsewhere). Below ~30%, suggest `--include-unlinked` for the next run.

### Key Rules

#### Evidence-Based, Never Fabricated

- Only document decisions inferable from commits + issues
- Cite specific SHAs and/or issue URLs on every Decision claim
- Mark confidence levels (HIGH/MEDIUM/LOW)
- "Reason unknown" is acceptable; invention is not

#### Non-Destructive

- Do not overwrite existing ChDRs without approval
- Preserve manually added content
- Merge intelligently if a ChDR already exists for the same issue key

#### Graceful Degradation

- Not a git repo → exit cleanly, no empty drafts
- Tracker unreachable → link-only evidence, proceed
- Empty/terse commit messages → rely on diffs + issue fetch; if both absent, skip the cluster

#### No Fabricated Rejection Rationale

- For inferred decisions, use neutral "Observed Alternatives" framing
- "We don't know why X wasn't chosen" is acceptable

### Workflow Guidance & Transitions

#### After `/change-init`

**Required**: Run `/change-clarify` to validate discovered ChDRs.

```text
/change-init
    ↓
[Mine git history] → Detect issue links, cluster, infer decisions
    ↓
[Generate ChDRs] → Write to .adlc/drafts/chdr/ChDR-{NNN}.md (Discovered)
    ↓
[Run /change-clarify] → Validate and accept/reject ChDRs
    ↓
[Run /change-publish] → Promote accepted ChDRs to .adlc/memory/chdr/
    ↓
[team-boot] → Injects .adlc/memory/chdr.md index at next session start
```

## Next Steps

After `init` completes, run `/change-clarify` to refine and validate the discovered ChDRs.

## Verification

- ChDRs written to `{REPO_ROOT}/.adlc/drafts/chdr/ChDR-{NNN}.md` with status **Discovered**.
- Auto-generated `chdr.md` index exists in `{REPO_ROOT}/.adlc/drafts/chdr/`.
- Every ChDR's `### Decision` claims cite at least one SHA or issue URL (provenance).
- Revert/fix chains detected in the window appear in `### Consequences` (or "None observed").
- Linkage-rate metric appears in the summary.
- No existing ChDRs were overwritten without explicit approval.

## Context

$ARGUMENTS
