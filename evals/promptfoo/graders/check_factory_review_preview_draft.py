"""Binary grader: factory-review pre-PR preview is labeled draft and is not a verdict.

Passes when the preview output:
  * carries an explicit "draft"/non-verdict label, AND
  * carries no verdict marker tokens (no head-SHA marker, no outcome=,
    no important=, no factory-review:step=review marker).
Fails otherwise.

This grader verifies the output contract only; it does not confirm that
review passes were executed (the preview lists them as structural checks,
it does not run them).
"""

import re

DRAFT = re.compile(r"\bdraft\b", re.IGNORECASE)
VERDICT_TOKENS = (
    "head=", "outcome=", "important=", "factory-review:step=review",
)


def get_assert(output: str, context: dict = None) -> dict:
    combined = output or ""
    problems = []

    if not DRAFT.search(combined):
        problems.append("preview output is not explicitly labeled draft")

    for token in VERDICT_TOKENS:
        if token in combined:
            problems.append(f"preview must not carry verdict token {token!r}")

    if problems:
        return {
            "pass": False,
            "score": 0.0,
            "reason": "preview is not a valid draft verdict: " + "; ".join(problems),
        }

    return {
        "pass": True,
        "score": 1.0,
        "reason": "preview is labeled draft and carries no verdict marker tokens.",
    }
