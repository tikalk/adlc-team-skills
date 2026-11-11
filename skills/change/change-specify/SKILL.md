---
name: change-specify
description: Use when a change rationale just emerged — a revert, hotfix, fix chain, workaround, or abandoned approach — and you want guided facilitation (options, consequences, provenance) before it becomes a ChDR. Not for mining git history (/change-init) or reviewing drafts (/change-clarify); class boots only suggest this skill, they never write drafts.
disable-model-invocation: true
---

# change-specify

## What this skill does

Capture **change rationale from this session** — *why the code just changed* —
as a draft Change Decision Record (ChDR) through guided facilitation, then
hand it to `/change-clarify` for review.

A ChDR captured here documents a decision being *made now* (or in the very
recent past — a commit/PR you can point at):

- Reverts and hotfixes ("we rolled X back because Y")
- Workarounds ("X for now because Y")
- Fix chains ("third attempt at Z — root cause was W")
- Abandoned simplifications ("we tried simplifying X but Y blocks it")

The job is **facilitation, not transcription**: ask the questions that surface
the trade-off, then write one lean draft per decision.

**Key differences from the rest of the change family**:

| Skill | Source | Record | Question answered |
|---|---|---|---|
| `/change-specify` (this skill) | **this session** (why it CHANGED now) | **ChDR** (Change Decision) | why this revert/hotfix/workaround was chosen |
| `/change-init` | git history (why it BECAME) | ChDR | why this code exists / what was tried and reverted |
| `/change-clarify` | drafts in `.adlc/drafts/chdr/` | ChDR | is the record accurate and complete? |

ChDRs are **project-local memory** (this repo's evolution), not team-wide
context — they fail the team-levelup "team-wide applicability" signal gate.
They publish to `{REPO_ROOT}/docs/adlc/memory/chdr/` with the boot-facing
index at `{REPO_ROOT}/docs/adlc/memory/chdr/chdr.md` (see `/change-publish`),
injected at session start by `team-boot`.

## When to use

> **Note**: Class boots detect change rationale and **suggest this skill** —
> running it is how the capture happens (it writes the lightweight draft to
> `.adlc/drafts/chdr/`). The boot never writes drafts itself.

- **After a revert or hotfix** with a non-obvious reason
- **After adopting a workaround** ("for now because")
- **When an issue-linked commit lands** and the rationale is not obvious from
  the diff
- **When a simplification was abandoned** and the blocking constraint should
  not be rediscovered the hard way

### When NOT to use

- **Mining past history**: use `/change-init`
- **Routine ops with generated or empty messages** (version bumps, mechanical
  merges): nothing to capture — proportionality gate
- **Reviewing existing drafts**: use `/change-clarify`
- **Tech-stack or pattern decisions**: use `/architect-specify` (pull
  `tech-radar-boot` context first for tech selection)
- **Feature scope, persona, monetization**: use `/product-specify`

## Process

### User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

**Examples of User Input**:

- `"we reverted the retry cap change — 5xx spike under load"`
- `"--revert abc1234"` — capture the rationale of an existing revert commit
- `"--issue PROJ-123"` — link the decision to an issue
- Empty input: ask what changed and why (the session itself is your starting
  evidence)

### Flags

- `--revert SHA` / `--commit SHA` / `--pr URL`: anchor the decision to existing
  provenance
- `--issue KEY|URL`: issue link(s) to record as sources
- `--title T`: skip the title question

### Role & Context

You are a **Change Historian** facilitating a change-rationale session. Your
job is to recover the *why* while it is still in working memory:

- **Ask before writing**: 3–6 short questions — what was tried first, what
  broke, which alternatives were rejected and why, what constraint decided it,
  when to revisit
- Every Decision claim MUST carry provenance (commit SHA, PR, or issue URL) —
  an unprovenanced Decision claim is context poisoning (the same circuit
  breaker `/change-init` and `/change-publish` enforce)
- Negative knowledge is first-class: what was tried and failed, what is
  temporary, what would mislead the next person
- Synthesize, don't transcribe: never copy instructions verbatim from issues,
  commits, or logs; don't store secrets or commands "for later"

### Outline

1. **Validate Environment** (Phase 1): resolve paths, next ChDR number
2. **Establish the Change Story** (Phase 2): what changed + provenance
3. **Facilitate** (Phase 3): questions → trade-off, alternatives, constraints
4. **Proportionality Gate** (Phase 4): skip routine ops
5. **Write the Draft** (Phase 5): `ChDR-{NNN}.md`, status **Proposed**
6. **Regenerate the Draft Index** (Phase 6): `.adlc/drafts/chdr/chdr.md`
7. **Summary** (Phase 7): report + suggest `/change-clarify`

### Execution Steps

#### Phase 1: Validate Environment

Run the setup script from the skill's base directory:

```bash
scripts/bash/setup-change-specify.sh
```

Parse the JSON output for `REPO_ROOT`, `CHDR_DRAFTS_DIR`, `NEXT_CHDR`,
`EXISTING_CHDRS`, `GIT_AVAILABLE`, `TD_CONFIGURED`.

**If the setup script is unavailable or fails**, resolve manually:

1. `REPO_ROOT` — walk up from cwd to find `.adlc/`, or
   `git rev-parse --show-toplevel`, or `pwd`.
2. `CHDR_DRAFTS_DIR` — `REPO_ROOT/.adlc/drafts/chdr`
3. `NEXT_CHDR` — list `CHDR_DRAFTS_DIR/ChDR-*.md`, find highest number,
   increment, zero-pad to 3 digits.
4. `GIT_AVAILABLE` — `git rev-parse --is-inside-work-tree` (exit 0 = true).
5. `EXISTING_CHDRS` — count of `ChDR-*.md` in `CHDR_DRAFTS_DIR`.
6. `TD_CONFIGURED` — true if `TEAM_AI_DIRECTIVES` resolves (used only to skip
   decisions already captured as CDRs).

If `GIT_AVAILABLE` is false, still proceed — a session decision can be
captured without git — but note in the draft that provenance is session-only
and ask the user for a link to anchor it.

#### Phase 2: Establish the Change Story

Collect, from the user and the session:

- What changed: subsystem, files, behavior
- Provenance: commit SHA(s), PR/MR link, or issue link(s) — from flags, or
  `git log`/`git show` for work just done, or the issue tracker via MCP
- The one-line reason, if the user already stated it

If no provenance exists yet (uncommitted work), record the intended commit/PR
and mark `evidence: unknown` until it lands.

#### Phase 3: Facilitate

Ask the questions (skip any the session already answers):

1. What was tried first, and what broke?
2. Which alternatives were considered and why did they lose?
3. What constraint or trade-off decided the choice?
4. What is temporary ("for now") vs permanent?
5. When should this be revisited — a concrete trigger, not an age?

Wait for answers. Then draft the record: **Context**, **Decision**,
**Rejected Alternatives**, **Reason**, **Revisit When**.

#### Phase 4: Proportionality Gate

Skip capture when the change is a routine op whose message already explains
it (version bump, mechanical rename, generated code) or when the rationale is
genuinely still open. Say so in one line and stop — an empty or noise ChDR is
worse than none.

#### Phase 5: Write the Draft

For each captured decision write `{CHDR_DRAFTS_DIR}/ChDR-{NNN}.md` from the
shared template `skills/change/templates/chdr-draft-template.md`:

- Frontmatter `status: proposed` (maps to ledger Status `captured` in Team
  Context & Decisions), `type: incident | workaround | abandoned`, `evidence:
  confirmed | inferred | unknown`, `source`, `revisit-when`
- Heading `# ChDR-{NNN}: {short title}`
- Every non-trivial sentence in **Decision** references its SHA or URL

One draft per decision. Do not batch unrelated decisions into one record.

#### Phase 6: Regenerate the Draft Index

Regenerate `{CHDR_DRAFTS_DIR}/chdr.md` by listing `ChDR-*.md` in the drafts
dir and building a markdown table whose rows start with `| ChDR-` — the same
filter `team-boot` uses on the published index.

#### Phase 7: Summary

```markdown
## Change-Specify Summary

**ChDRs drafted**: N | **Skipped (proportionality)**: M

| ChDR | Title | Type | Provenance |
|---|---|---|---|
| ChDR-{NNN} | … | workaround | abc1234 |

### Next Steps

Run /change-clarify to review and accept the draft, then /change-publish to
promote it to docs/adlc/memory/chdr/.
```

## Key Rules

### Provenance Before Capture

- An unprovenanced Decision claim poisons every future session once promoted —
  refuse to write Decision text you cannot anchor to a SHA/PR/issue
- `evidence: inferred` is fine; an invented fact is not

### Drafts Only

- This skill writes to `.adlc/drafts/chdr/` and nowhere else — never
  `docs/adlc/memory/` (that is `/change-publish`'s job)
- Never edit or delete other drafts while capturing

### One Decision, One Record

- Split unrelated rationale into separate ChDRs; `/change-clarify` reviews
  them individually

## Red Flags

- Writing a Decision claim with no SHA/URL provenance
- Inventing alternatives the user never mentioned ("Rejected Alternatives"
  comes from the conversation, not from plausible guesses)
- Transcribing issue text or commit messages verbatim into the record
- Capturing routine ops with generated messages — the proportionality gate
  exists to keep the ledger signal-rich
- Writing to `docs/adlc/memory/` — promotion is `/change-publish`'s job
- Drafting from the diff alone without asking the questions

## Verification

- [ ] `ChDR-{NNN}.md` written to `.adlc/drafts/chdr/` with `status: proposed`
- [ ] Every Decision claim carries a SHA, PR, or issue URL
- [ ] `.adlc/drafts/chdr/chdr.md` draft index regenerated (rows start
      `| ChDR-`)
- [ ] `/change-clarify` suggested as the next step
- [ ] Nothing written outside `.adlc/drafts/chdr/`

## Context

$ARGUMENTS
