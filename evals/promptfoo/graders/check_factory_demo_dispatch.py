import re

def get_assert(output: str, context: dict = None) -> dict:
    """Grader for factory-demo: the walker dispatches owning skills and never
    performs segment work itself (the product-decision risk is walker drift
    into implementing/reviewing; the architecture decision makes non-dispatch
    a hard rule)."""
    lowered = output.lower()
    # Dispatching language: names an owning skill as the performer.
    dispatches = re.search(r"dispatch\w*\s+(to\s+)?factory-(queue|intent|mission|review|release|learn|clean)\b", lowered)
    invokes_skill = re.search(r"invok\w*\s+.*factory-(queue|intent|mission|review|release|learn|clean)\b", lowered)
    # Self-performance: the walker itself implements/reviews/approves/merges.
    self_performs = (
        re.search(r"\bi\s+(will\s+)?(implement|review|approve|merge)\b", lowered)
        or re.search(r"walker\s+(implements|reviews|approves|merges)\b", lowered)
    )
    if (dispatches or invokes_skill) and not self_performs:
        return {
            "pass": True,
            "score": 1.0,
            "reason": "Walker dispatches the owning skill and performs no segment work itself."
        }
    if self_performs:
        return {
            "pass": False,
            "score": 0.0,
            "reason": f"Walker performed segment work itself instead of dispatching. Output was: {output}"
        }
    return {
        "pass": False,
        "score": 0.0,
        "reason": f"No owning-skill dispatch found. Output was: {output}"
    }
