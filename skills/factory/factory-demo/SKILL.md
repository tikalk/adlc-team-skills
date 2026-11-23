---
name: factory-demo
description: Use when running a factory demo from a repo runbook — walking demo/pre-flight through demo/runbook anchors top to bottom, rehearsing with --dry-run, or resuming a demo mid-runbook with --from.
---

# factory-demo

## Overview

One walker, every demo: the runbook carries the repo-specific content
(Say/Do/Show per `### demo/*` anchor); this skill carries only the walking
mechanics. It dispatches each segment to its owning skill
(`references/dispatch-map.md`) and pauses only at human gates.

## When to Use

- `/factory-demo --runbook <path> --customer=<name>` — walk a demo runbook
  end to end for an audience.
- `--dry-run` — prove every segment's live path before the show; print
  live/fallback per segment, change nothing.
- `--from <anchor>` — resume mid-runbook after a break (e.g. `demo/review`).
- Second-person rehearsal of someone else's runbook before showtime.

**When NOT to use:** implementing, reviewing, approving, or merging anything
the demo produces — dispatch the owning skill (`factory-mission`,
`factory-review`, …); this skill never performs segment work itself. Not for
repo work outside a demo runbook.

## Core Process

**Requires:** the runbook path. Without `--runbook`, state what is missing
and stop. Resolve skill dependencies per `Requires` lines if invoked outside
a harness that injects them.

### Step 1. Parse and validate (always first, including `--dry-run`)

1. `scripts/bash/list-anchors.sh --runbook <path> [--from <anchor>]`
   (PowerShell twin: `scripts/powershell/list-anchors.ps1`) — the segment
   order. File order is authoritative; `--from` slices off earlier anchors.
2. `scripts/bash/validate-runbook.sh --runbook <path>` (PowerShell twin:
   `scripts/powershell/validate-runbook.ps1`) — fail closed on a malformed
   runbook. A non-zero exit names the offending anchor: fix the runbook,
   never guess past it.
3. Refuse ambiguous input: missing runbook, unreadable file, zero anchors,
   unknown `--from` anchor — report the anchor name and stop.

### Step 2. Dry-run (`--dry-run`)

Walk the anchors from Step 1 in order. Per segment print: the Say line, the
Do command as the live path, the runbook's fallback, and the owning skill it
*would* dispatch to. Attempt read-only verification where the runbook names
a checkable live path (fetch a URL, list a sensor workflow) and report its
status; never mistake reference evidence for tonight's state — label quoted
history as history.

Dry-run changes nothing: no tracker writes, no commits, no branches, no
dispatches, no gate answers. Enforce structurally (read-only tools only),
not by self-restraint.

### Step 3. Live walk

Walk the validated anchors in order, threading `--customer=<name>`
(default `Tikal`) into mission briefs and verifications per the runbook's
convention. Per segment:

1. Check lease/heartbeat before dispatching a mission — one live run per
   work item; never dispatch a second run for work a live run owns.
2. **Invoke** the owning skill from `references/dispatch-map.md` via the
   Skill tool for the segment's work. Never implement, review, approve, or
   merge inline — copying a command from the runbook into the terminal
   instead of dispatching is the failure this skill exists to prevent.
3. **Pause for real at human gates** (Intent Gate, PDR/ADR gates, spec
   approval, PR hand-off, merge). Present the gate prompt and wait. Advisory
   scores never open a gate; a timeout parks (`parked` → `resume`), never
   auto-answers.
4. `--from` resumes at the named anchor; never restart completed segments,
   never re-triage work that already carries a lifecycle label.
5. Write the walk position (current anchor) where the facilitator can see it
   so a later `--from` resumes cleanly; never overwrite the runbook's
   reference evidence with tonight's links.

### Step 4. After the show

Report per segment: walked/dispatched/paused-at-gate with the owning skill
and the resulting work-item or MR link. Name every fallback taken and every
gap found (M19 reference: the `!1339` zero-verdict finding became
adlc-workspace#166 — gaps are findings, not failures to hide).

## Red Flags

- Typing a dispatch command yourself instead of invoking the owning skill —
  STOP, invoke the skill.
- Answering a gate, assuming approval, or merging "to keep the show moving"
  — STOP, wait for the human.
- Reordering, skipping, or merging anchors because "the audience won't
  notice" — STOP, walk file order.
- Deriving the customer slug by feel — use the runbook's convention or fail
  closed on empty; never ship a guessed branch name.
- Overwriting reference evidence with dry-run links, or presenting quoted
  history as verified state — label, don't blur.

**All of these mean: stop the walk, fix the input, resume with `--from`.**

## Verification

A run of this skill is done when:

- [ ] `validate-runbook.sh --runbook <path>` exits 0 (anchor contract holds)
- [ ] Every walked anchor dispatched its owning skill or paused at a named
  human gate — no anchor was performed inline
- [ ] `--dry-run` produced zero tracker writes (verify: no new notes/issues/MRs)
- [ ] Human gates were answered by humans, merges by humans — reviews never
  approved or merged
- [ ] The show report names every segment outcome plus fallbacks/gaps taken

## Configuration

| Flag | Meaning | Default |
|---|---|---|
| `--runbook <path>` | Repo run sheet to walk (required) | — |
| `--customer=<name>` | Audience customer, threaded into briefs/verifications | `Tikal` |
| `--from <anchor>` | Resume at this `demo/*` anchor | start |
| `--dry-run` | Print live/fallback per segment; change nothing | off |
