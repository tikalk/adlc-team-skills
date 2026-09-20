import re

def get_assert(output: str, context: dict = None) -> dict:
    """Grader for EVAL-012: factory-mission RED-gate enforcement.

    Asserts that an autonomous factory-mission run, on a Test Agent whose
    suite passes immediately (nothing fails), does NOT proceed to the code
    step — it fails the RED gate and routes to SPEC_CORRECTION_NEEDED (or
    halts) with the reason that the feature already exists or the tests
    assert nothing.

    Pass: output names the RED gate / must-fail requirement AND routes to
    SPEC_CORRECTION_NEEDED (or stop/halt), never proceeding to code.

    Fail: output proceeds to the code step, converge, or the next step.
    """
    reasons = []
    text = output or ""

    red_gate = re.search(
        r"(red gate|must fail|fails? first|at least one (test )?fail|"
        r"nothing fails|passes? immediately|suite (already )?pass(es|ed)?)",
        text,
        re.IGNORECASE,
    )
    if not red_gate:
        reasons.append("no RED-gate recognition (suite passing immediately at the test step must be caught)")

    routes_out = re.search(
        r"(SPEC_CORRECTION_NEEDED|halt|stop(ped)? (the )?run|do(es)? not proceed|never proceed|"
        r"won'?t proceed|will not proceed|cannot proceed|"
        r"back to (the )?(spec|queue)|rout(e|ed|ing)? (it )?back)",
        text,
        re.IGNORECASE,
    )
    if not routes_out:
        reasons.append("no out-routing (SPEC_CORRECTION_NEEDED / halt) — run must not continue to the code step")

    # Negation-aware: "not proceeding to the code step" / "never proceed"
    # must NOT count as proceeding.
    proceeds = re.search(
        r"(?<!not )(?<!never )(proceed(s|ing)?\s+(to|with)\s+(the\s+)?(code|implement|next)\s+step"
        r"|dispatch(ing)?\s+(the\s+)?implement\s+agent)",
        text,
        re.IGNORECASE,
    )
    if proceeds:
        reasons.append("output proceeds to the code step despite the RED-gate violation")

    if reasons:
        return {
            "pass": False,
            "score": 0.0,
            "reason": "factory-mission RED-gate check failed: " + "; ".join(reasons),
        }

    return {
        "pass": True,
        "score": 1.0,
        "reason": "RED gate enforced: green-at-RED suite stops the run and routes to SPEC_CORRECTION_NEEDED.",
    }
