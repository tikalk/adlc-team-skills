import re

def get_assert(output: str, context: dict = None) -> dict:
    """Grader for EVAL-013: diagnosing-team-skills evidence-first compliance.

    Asserts a diagnosis of "team context didn't appear at session start"
    runs concrete checks (init-options.json, jq, boot.sh) before concluding —
    no generic reinstall/restart advice without evidence.

    Pass: output names at least two concrete checks/commands from the chain
    AND does not lead with generic remediation (reinstall/restart/update)
    before any evidence.

    Fail: fabricated conclusions or generic advice with no chain checks.
    """
    reasons = []
    text = output or ""

    checks = [
        r"init-options\.json",
        r"jq",
        r"boot\.sh",
        r"acceptance-test",
        r"\.agents/skills/team-boot",
    ]
    found = [c for c in checks if re.search(c, text, re.IGNORECASE)]
    if len(found) < 2:
        reasons.append(
            f"fewer than 2 concrete chain checks named (found: {found or 'none'})"
        )

    # Generic remediation BEFORE any concrete check = guessing. Negation-
    # aware: "Don't restart yet — first check init-options.json" is advice
    # ordering evidence first, not generic remediation. (Fixed-width
    # lookbehinds — Python re rejects variable-width ones.)
    generic = None
    for m in re.finditer(
        r"(reinstall|re-install|restart|update (the )?(repo|skills)|try again)",
        text,
        re.IGNORECASE,
    ):
        prefix = text[max(0, m.start() - 12):m.start()].lower()
        if "don't" in prefix or "dont" in prefix or "never " in prefix or "not " in prefix:
            continue
        generic = m
        break
    first_check = min(
        (m.start() for c in checks for m in [re.search(c, text)] if m),
        default=None,
    )
    if generic and (first_check is None or generic.start() < first_check):
        reasons.append("generic remediation offered before any concrete check — evidence must come first")

    if reasons:
        return {
            "pass": False,
            "score": 0.0,
            "reason": "diagnosing-team-skills evidence-first check failed: " + "; ".join(reasons),
        }

    return {
        "pass": True,
        "score": 1.0,
        "reason": "Evidence-first diagnosis: concrete chain checks named before any conclusion or remediation.",
    }
