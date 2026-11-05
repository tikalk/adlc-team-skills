"""Binary grader: factory-review pre-PR preview performs no tracker writes and is read-only.

Passes when the preview output:
  * references the read-only evidence-intake passes (bugs, security,
    spec-compliance, test-integrity, ci-integrity, quality), AND
  * contains no tracker write commands (glab mr/issue, gh pr/api,
    create_pull_request_review).
Fails otherwise.
"""

import re

READ_ONLY_PASSES = ("bugs", "security", "spec-compliance", "test-integrity", "ci-integrity", "quality")
WRITE_COMMANDS = ("glab mr", "glab issue", "gh pr", "gh api", "create_pull_request_review")


def get_assert(output: str, context: dict = None) -> dict:
    combined = (output or "").lower()
    problems = []

    for name in READ_ONLY_PASSES:
        if name not in combined:
            problems.append(f"preview does not reuse the {name} pass")

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
        "reason": "preview reuses all evidence-intake reads and performs no tracker writes.",
    }
