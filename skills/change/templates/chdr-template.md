---
# ChDR template — full format for /change-init mining and /change-clarify enrichment.
# Written to .adlc/drafts/chdr/ChDR-{NNN}.md, promoted to .adlc/memory/chdr/ by /change-publish.
status: discovered  # discovered | proposed | accepted | rejected | superseded
date: YYYY-MM-DD
type: incident  # incident | workaround | abandoned
evidence: inferred  # confirmed | inferred | unknown
source: ""  # git history via /change-init, or session YYYY-MM-DD
issue-links: ""  # issue keys/URLs, or "none detected"
commits: ""  # sha list, abbreviated
revisit-when: ""  # concrete trigger or "N/A"
---

# ChDR-NNN: {Title — from issue title or commit subject}

## Status

{discovered | proposed | accepted | rejected | superseded}

## Context

{Why the change was made — issue title/body summary (1-3 sentences) + commit
messages. Cite SHAs inline.}

## Decision

{What was decided/implemented — inferred from diffs. Mark confidence:
HIGH/MEDIUM/LOW. Each claim cites its SHA/URL. "Reason unknown" is
acceptable and preferred over invention.}

## Consequences

{Reverts, follow-up fix chains, later modifications — negative knowledge.
"None observed" if the cluster has no reversals.}

## Rejected Alternatives

* {alternative 1} — {why it lost, or "reason unknown"}
* {alternative 2} — {why it lost, or "reason unknown"}

## Reason

{Why the chosen path won — the constraint or trade-off that decided it.
May be "inferred from diff" if not explicitly stated in commits/issues.}

## Evidence

* `{sha}`: {commit subject}
* {file/path}: {what changed}
* {issue-url}: {title} (fetched | link-only)

## Revisit When

{When this should be re-checked, or "N/A". A concrete trigger, not age.}
