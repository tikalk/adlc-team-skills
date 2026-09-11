---
name: factory-tickets
description: "Show what is on the user's plate across trackers: open pull requests with their next actionable move, merged work not yet closed, takable tickets, and blocked work. Read-only. Use when the user asks \"what is on my plate\" or \"list my active tickets.\""
---

# factory-tickets

## What this skill does

`factory-tickets` is the read-only personal worklist engine of the software factory (deck slide 12 Ingestion & Triage stage). It provides the user with an immediate, live, and actionable overview of their active queue, categorized by "next move" rather than abstract status.

It operates directly against the external issue tracker and PR host (GitHub, GitLab, Linear, Jira) using the tracker-agnostic integration layer (`factory-mission/references/tracker-integration.md`).

---

## When to use

- At the start of a session or when planning your day, to find out exactly what needs your attention next.
- To identify which of your pull requests are ready to merge, blocked, or awaiting your review feedback.
- To discover unassigned, unblocked tickets (`spec-gated`) that are ready for execution.

**When NOT to use**:
- To change ticket status, assignees, or edit bodies (this skill is **strictly read-only**, PDR-052).
- To execute or implement tasks (use `factory-mission` instead).

---

## Operating Process

### 1. Provider & Identity Discovery
1. Discover the active tracker provider and credentials (`factory-mission/references/tracker-integration.md`).
2. Identify the authenticated user's login. Restrict the search to:
   - Pull requests **authored by** the authenticated account.
   - Tickets **assigned to** the authenticated account (or another login if explicitly requested).

### 2. Dual-Authority Paged Queries
Never poll individual items. Run two paged searches (via MCP or CLI) to fetch the entire active set in one round-trip per source:
1. **Pull Request Search**: fetch the user's open PRs, including: draft status, review decision, unresolved threads, named check statuses, and mergeability.
2. **Issue Search**: fetch the user's assigned open issues, including: title, description, state, labels, milestones, and linked project metadata.

### 3. Match Evidence (Tracker-Agnostic, PDR-052)
A PR routinely cross-references multiple tickets. Associate a pull request to a ticket **only** when there is explicit evidence:
- A **closing link** established by the tracker itself.
- A **branch name** that contains the ticket number in the repository's convention.
- A **PR title** that explicitly names the ticket number.
If no explicit evidence exists, leave the association cell empty. Never guess based on mere textual mention.

### 4. Classify Next Action (Next-Move Sections)
Assign every retrieved item to exactly one of the following priority sections. **Render what was assigned — never reclassify during formatting**:

1. **Active Pull Requests (My Turn)**: Pull requests where the next action belongs to the user:
   - `Merge` — required checks are green, human approval is complete. **Ready-to-merge sorts first (highest priority)**.
   - `Address Review Feedback` — changes requested by a reviewer.
   - `Fix failing check: <name>` — a required CI check has failed (reported by name, not rolled up).
   - `Answer N comment threads` — unresolved reviewer questions.
   - `Finish Draft` — PR is still in draft state.
2. **Active Pull Requests (Their Turn)**: Pull requests waiting on external actions:
   - `Awaiting Review` — Ready for review, requested reviewer hasn't responded.
   - `Awaiting CI` — required checks are still running.
3. **Merged, Ticket Still Open**: The PR that closes this ticket has merged, but the ticket remains open on the board. Move is: verify, then close.
4. **Takable Now (Backlog)**: Open issues with lifecycle `spec-gated`, automation-gating `agent-can-execute`, and no pull request claiming them. (If empty, display an explicit "none").
5. **Waiting on Someone Else**: Open issues with unresolved blocked-by dependencies, naming the blocking ticket.

*Note: Epics and parent issues go in an Appendix below a rule, showing child counts and progress. They are never mixed into the active task list.*

---

## Invariants & Safety Constraints

1. **Strictly Read-Only (PDR-052)**: This skill physically cannot edit, comment, create, or modify any ticket, label, assignee, or board field. No `gh` or `glab` write commands are present.
2. **No Caching**: Every run performs a live fetch. A cached or stale queue is worse than none.
3. **No Rollup Guessing**: Never report check status from a rolled-up "failing" commit status if a job was merely cancelled or skipped. Read and name the exact failing context.
4. **Unparsed Word Reporting**: If the user's request contains words the query parser doesn't recognize, do not drop them. List them in an "Unparsed Terms" section below the table so the user knows what was ignored.
