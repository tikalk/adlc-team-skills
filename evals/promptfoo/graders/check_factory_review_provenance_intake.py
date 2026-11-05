"""Binary grader: factory-review pre-PR preview handles provenance intake.

Passes when the preview output:
  * when provenance is missing: mentions provenance and requests it
    ("which files came from where" / AI-contribution-policy compliance), AND
  * when provenance is present: acknowledges it as present.
Fails otherwise.
"""

import re

PROVENANCE = re.compile(r"provenance", re.IGNORECASE)
REQUEST = re.compile(
    r"request|missing|not provided|which files came from where|ai-contribution",
    re.IGNORECASE,
)
PRESENT = re.compile(r"provenance.*present|provenance.*ok", re.IGNORECASE)


def get_assert(output: str, context: dict = None) -> dict:
    combined = output or ""
    problems = []

    is_present = PRESENT.search(combined) is not None

    if is_present:
        if not PROVENANCE.search(combined):
            problems.append("present provenance is not acknowledged by name")
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
