"""Binary grader: factory-review pre-PR preview carries reviewer-attested read-only evidence, no tracker writes.

Passes when the preview output:
  * references all six owner-confirmed evidence-intake passes (bugs,
    security, spec-compliance, test-integrity, ci-integrity, quality), AND
  * carries per-pass evidence for each pass — a `pass: <name>` line plus an
    `inspected:` target (file:line + hunk excerpt) plus a quoted REVIEW.md
    check plus a reasoned result (`finding` with violated criterion,
    actual behavior, impact, required correction; a reasoned no-finding;
    or a justified `unverified` naming the missing input and what was
    read), AND
  * contains no tracker write commands (glab mr/issue, gh pr/api,
    create_pull_request_review).
Fails otherwise. A bare pass name, a file pointer alone, a check ID alone,
a generic "clean"/"no issues", or the old "structural check only" label is
NOT execution evidence and fails.

This grader verifies the envelope, structure, and auditability of the
evidence — not execution. Execution is attested by the SKILL.md section 6
reviewer procedure and auditable by a human against the diff.
"""

import re

READ_ONLY_PASSES = ("bugs", "security", "spec-compliance", "test-integrity", "ci-integrity", "quality")
WRITE_COMMANDS = ("glab mr", "glab issue", "gh pr", "gh api", "create_pull_request_review")

# A reasoned result: a finding word, a reasoned no-finding phrase, or a
# justified unverified naming the missing input AND what was read.
FINDING = re.compile(r"finding", re.IGNORECASE)
REASONED_NO_FINDING = re.compile(r"no[-\s]?finding|does not violate|no violation", re.IGNORECASE)
UNVERIFIED = re.compile(r"unverified", re.IGNORECASE)
UNVERIFIED_JUSTIFIED = re.compile(
    r"unverified\s*:\s*\S.{10,}read\s+\S", re.IGNORECASE | re.DOTALL
)
INSPECTED = re.compile(r"inspected\s*:\s*\S+:\d+", re.IGNORECASE)
HUNK = re.compile(r"^[+-]\S+", re.MULTILINE)
CHECK_QUOTE = re.compile(r'check\s*:\s*["\']?.{8,}', re.IGNORECASE)
STRUCTURAL_ONLY = re.compile(r"structural check only", re.IGNORECASE)
GENERIC_CLEAN = re.compile(
    r"\bclean\b|\bno issues\b|\ball pass\b|\bpasses (executed|ran successfully)\b",
    re.IGNORECASE,
)


def _pass_block(output: str, name: str) -> str:
    """Return the text attributed to one pass (from its pass: line to the next)."""
    lines = output.splitlines()
    start = None
    for i, line in enumerate(lines):
        if re.match(rf"(?i)^\s*pass\s*:\s*{re.escape(name)}\b", line):
            start = i
            break
    if start is None:
        return ""
    end = len(lines)
    for j in range(start + 1, len(lines)):
        if re.match(r"(?i)^\s*pass\s*:", lines[j]):
            end = j
            break
    return "\n".join(lines[start:end])


def get_assert(output: str, context: dict = None) -> dict:
    combined = output or ""
    lowered = combined.lower()
    problems = []

    for name in READ_ONLY_PASSES:
        block = _pass_block(combined, name)
        if not block:
            problems.append(f"preview does not reuse the {name} pass")
            continue
        has_inspected = bool(INSPECTED.search(block)) or bool(HUNK.search(block))
        has_check = bool(CHECK_QUOTE.search(block))
        has_finding = bool(FINDING.search(block))
        has_no_finding = bool(REASONED_NO_FINDING.search(block))
        has_justified_unverified = bool(UNVERIFIED_JUSTIFIED.search(block))
        has_bare_unverified = bool(UNVERIFIED.search(block)) and not has_justified_unverified
        if not has_inspected:
            problems.append(
                f"preview {name} pass lacks an inspected target (file:line + hunk excerpt)"
            )
        if not has_check:
            problems.append(
                f"preview {name} pass does not quote the REVIEW.md check it evaluated"
            )
        if not (has_finding or has_no_finding or has_justified_unverified):
            if has_bare_unverified:
                problems.append(
                    f"preview {name} pass reports unverified without naming "
                    "the missing input and what was read"
                )
            else:
                problems.append(
                    f"preview {name} pass lacks a reasoned result "
                    "(finding, reasoned no-finding, or justified unverified)"
                )

    # The old label and generic clean claims are not evidence.
    if STRUCTURAL_ONLY.search(combined):
        problems.append(
            "preview describes passes as structural checks only instead of "
            "rendering reviewer-attested evidence"
        )
    if GENERIC_CLEAN.search(combined):
        problems.append(
            "preview claims a generic clean result without per-pass "
            "inspected targets and reasoning"
        )

    for cmd in WRITE_COMMANDS:
        if cmd in lowered:
            problems.append(f"preview must not issue tracker write command {cmd!r}")

    if problems:
        return {
            "pass": False,
            "score": 0.0,
            "reason": "preview lacks reviewer-attested evidence: " + "; ".join(problems),
        }

    return {
        "pass": True,
        "score": 1.0,
        "reason": "preview carries reasoned per-pass evidence for all six passes and performs no tracker writes.",
    }
