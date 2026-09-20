import re

_CHECK_VEHICLE = re.compile(
    r"(unit test|pytest|binary grader|grader|pre-?commit|linter|lint rule|"
    r"CI (?:job|check|workflow)|deterministic check)",
    re.IGNORECASE,
)


def get_assert(output: str, context: dict = None) -> dict:
    """Grader for EVAL-010: deterministic-checks-first rule classification.

    Asserts that a capture/clarify decision on a MECHANICAL rule candidate
    (fixed syntactic pattern, banned API, import shape, file-location rule):
      - is classified as mechanical
      - proposes a deterministic check (unit test, binary grader, pre-commit
        hook, lint rule, or CI job) as the enforcement vehicle
    A CDR-only fix for a mechanical rule fails — it makes every future
    session re-derive the same call instead of paying once for the check.
    A thin pointer CDR beside the check is acceptable (the check is present).
    """
    reasons = []

    is_mechanical = re.search(r"\bmechanical\b", output, re.IGNORECASE)
    if not is_mechanical:
        reasons.append(
            "candidate not classified as mechanical (a fixed pattern must be "
            "recognized as such, not treated as a judgement call)"
        )

    has_check = _CHECK_VEHICLE.search(output)
    if not has_check:
        reasons.append(
            "no deterministic check proposed (unit test / binary grader / "
            "pre-commit hook / lint rule / CI job) — a CDR-only fix for a "
            "mechanical rule re-derives the call every session"
        )

    if reasons:
        return {
            "pass": False,
            "score": 0.0,
            "reason": "Deterministic-checks-first failed: " + "; ".join(reasons),
        }

    return {
        "pass": True,
        "score": 1.0,
        "reason": "Mechanical rule classified correctly with a deterministic "
                  "check as the enforcement vehicle.",
    }
