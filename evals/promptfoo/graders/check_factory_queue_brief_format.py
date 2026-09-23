import re


def get_assert(output: str, context: dict = None) -> dict:
    """Grader for factory-queue plan mode: generated gate/task issues must use
    the mission-brief format (ADR-389)."""
    fields = ["**Goal**", "**Constraints**", "**Non-Goals**", "**Success Criteria**"]
    missing = [f for f in fields if f not in output]
    prefixed = re.search(r"^\s*#{0,3}\s*\[(G\d+|M\d+)[^\]]*\]", output, re.MULTILINE)

    if not missing and not prefixed:
        return {
            "pass": True,
            "score": 1.0,
            "reason": "Plan-mode output uses the mission-brief format (Goal/Constraints/Non-Goals/Success Criteria) with no title prefixes."
        }

    problems = []
    if missing:
        problems.append("missing fields: " + ", ".join(missing))
    if prefixed:
        problems.append("prefixed title: " + prefixed.group(0).strip())
    return {
        "pass": False,
        "score": 0.0,
        "reason": "Plan-mode output violates the mission-brief contract (ADR-389) — "
        + "; ".join(problems)
        + f". Output was: {output}"
    }
