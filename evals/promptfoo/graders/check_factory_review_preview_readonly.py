"""Binary grader: factory-review pre-PR preview performs no tracker writes and lists passes read-only.

Passes when the preview output:
  * references the read-only evidence-intake passes (bugs, security,
    spec-compliance, test-integrity, ci-integrity, quality), AND
  * describes them as structural checks only (not executed), AND
  * contains no tracker write commands (glab mr/issue, gh pr/api,
    create_pull_request_review).
Fails otherwise.

This grader verifies that the preview lists passes structurally and performs
no tracker writes; it does not confirm that review passes were executed.
"""

import re

READ_ONLY_PASSES = ("bugs", "security", "spec-compliance", "test-integrity", "ci-integrity", "quality")
STRUCTURAL_ONLY = re.compile(r"structural check only", re.IGNORECASE)
WRITE_COMMANDS = ("glab mr", "glab issue", "gh pr", "gh api", "create_pull_request_review")


def get_assert(output: str, context: dict = None) -> dict:
    combined = (output or "").lower()
    problems = []

    for name in READ_ONLY_PASSES:
        if name not in combined:
            problems.append(f"preview does not reuse the {name} pass")

    # The preview must describe passes as structural checks only, not claim
    # they were executed.
    if not STRUCTURAL_ONLY.search(combined):
        problems.append("preview must describe passes as structural checks only")

    for cmd in WRITE_COMMANDS:
        if cmd in combined:
            problems.append(f"preview must not issue tracker write command {cmd!r}")

    if problems:
        return {
            "pass": False,
            "score": 0.0,
            "reason": "preview is not read-only: " + "; ".join(problems),
        }

    return {
        "pass": True,
        "score": 1.0,
        "reason": "preview lists all evidence-intake reads as structural checks and performs no tracker writes.",
    }
