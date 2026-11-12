"""Binary grader: factory-review pre-PR preview handles provenance intake.

Passes when the preview output:
  * when provenance is missing: mentions provenance and requests it
    ("which files came from where" / AI-contribution-policy compliance), AND
  * when provenance is present: acknowledges it as detected.
Fails otherwise.

This grader verifies detection of a textual provenance reference only; it
does not validate provenance completeness or AI-contribution-policy
compliance, as those require owner-defined rules (owner sign-off path).
"""

import re

PROVENANCE = re.compile(r"provenance", re.IGNORECASE)
REQUEST = re.compile(
    r"request|missing|not provided|which files came from where|ai-contribution",
    re.IGNORECASE,
)
DETECTED = re.compile(r"provenance:\s*detected", re.IGNORECASE)


def get_assert(output: str, context: dict = None) -> dict:
    combined = output or ""
    problems = []

    is_detected = DETECTED.search(combined) is not None

    if is_detected:
        if not PROVENANCE.search(combined):
            problems.append("detected provenance is not acknowledged by name")
    else:
        if not PROVENANCE.search(combined):
            problems.append("preview does not mention provenance at all")
        if not REQUEST.search(combined):
            problems.append("preview does not request missing provenance")

    if problems:
        return {
            "pass": False,
            "score": 0.0,
            "reason": "provenance intake is incomplete: " + "; ".join(problems),
        }

    return {
        "pass": True,
        "score": 1.0,
        "reason": "provenance intake handled correctly.",
    }
