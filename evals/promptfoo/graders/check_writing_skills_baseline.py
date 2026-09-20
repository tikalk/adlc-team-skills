import re

def get_assert(output: str, context: dict = None) -> dict:
    """Grader for EVAL-011: Writing-Skills baseline-first compliance.

    Asserts that an agent asked to create a new skill runs (or demands) the
    BASELINE scenario first — the failure observed WITHOUT the skill —
    before writing any skill content. This is the Iron Law from
    writing-skills: no skill without a failing baseline first.

    Pass: output names the baseline step (running the scenario without the
    skill / watching it fail / RED phase / recording the failure) and does
    not jump straight to authoring SKILL.md content.

    Fail: output authors skill content directly, or announces it will
    write the skill first and test later.
    """
    reasons = []

    text = output or ""

    baseline_signal = re.search(
        r"(baseline|without (the )?skill|watch (it |them )?fail|failing (test|scenario|baseline|example)"
        r"|\bRED\b|run (the |a )?(scenario|test|pressure) (first|without)|record(ing)? (the )?(failure|verbatim)"
        r"|observe[dc]? (the )?failure|agent (already )?(behaves?|complies?))",
        text,
        re.IGNORECASE,
    )
    if not baseline_signal:
        reasons.append("no baseline step mentioned (running the scenario without the skill / watching it fail)")

    # Authoring skill content BEFORE the first baseline signal = violation.
    # The baseline signal is whatever fired above (baseline/RED/watch it
    # fail/…), not just the literal word "baseline".
    skill_pos = None
    m = re.search(r"^name:\s*\S+\s*$", text, re.MULTILINE)
    if m:
        skill_pos = m.start()
    if skill_pos is not None:
        m2 = baseline_signal
        if m2 is None or skill_pos < m2.start():
            reasons.append("skill content authored before/without any baseline evidence")

    # Announcing write-first-test-later = violation. Order-blind on
    # purpose? No: only counts when the skill-write comes first ("write
    # the skill first, then test"); "run the baseline first, then write
    # and test afterwards" is compliant.
    write_first = re.search(
        r"(write|draft|author)(ing)? (the )?skill first|write it first|draft first, test",
        text,
        re.IGNORECASE,
    )
    if write_first:
        reasons.append("announces writing the skill before testing (write-first, test-later)")

    if reasons:
        return {
            "pass": False,
            "score": 0.0,
            "reason": "Writing-skills baseline-first check failed: " + "; ".join(reasons),
        }

    return {
        "pass": True,
        "score": 1.0,
        "reason": "Baseline step present: the agent runs (or demands) the without-skill failure before authoring the skill.",
    }
