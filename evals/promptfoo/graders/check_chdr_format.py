import re

def get_assert(output: str, context: dict = None) -> dict:
    """Grader for EVAL-006: Change Decision Record (ChDR) format integrity.

    Asserts a mined ChDR draft has:
      - the four required sections (Context, Decision, Consequences, Evidence)
      - at least one commit SHA (provenance anchor)
      - an issue link OR an explicit "no linked issue" marker
      - provenance on Decision claims: at least one SHA or URL appears in the
        Decision section body (the context-poisoning circuit breaker — an
        unprovenanced inferred rationale is worse than no rationale).
    """
    reasons = []

    # Required sections (### headings — allow trailing text on the line,
    # e.g. "### Decision (confidence: HIGH)")
    required_sections = ["Context", "Decision", "Consequences", "Evidence"]
    for sec in required_sections:
        if not re.search(rf"^###\s+{sec}\b", output, re.MULTILINE):
            reasons.append(f"missing section: {sec}")

    # At least one commit SHA (7-40 hex chars) anywhere
    has_sha = re.search(r"\b[0-9a-f]{7,40}\b", output, re.IGNORECASE)
    if not has_sha:
        reasons.append("no commit SHA found (provenance anchor missing)")

    # Issue link OR explicit "no linked issue" marker
    issue_link = re.search(
        r"(\b[A-Z][A-Z0-9]+-\d+\b|https?://\S+/(?:issues|pull|merge_requests|browse)/\S+)",
        output,
    )
    no_link_marker = re.search(r"no linked issue|none detected", output, re.IGNORECASE)
    if not issue_link and not no_link_marker:
        reasons.append("no issue link and no explicit 'no linked issue' marker")

    # Provenance on Decision claims: extract the Decision section body and
    # require at least one SHA or URL inside it.
    decision_body = ""
    m = re.search(r"^###\s+Decision\b[^\n]*\n(.*?)(?=^###\s|\Z)", output, re.MULTILINE | re.DOTALL)
    if m:
        decision_body = m.group(1)
        decision_has_provenance = re.search(
            r"(\b[0-9a-f]{7,40}\b|https?://\S+)", decision_body, re.IGNORECASE
        )
        if not decision_has_provenance:
            reasons.append("Decision section has no SHA/URL provenance on its claims")

    if reasons:
        return {
            "pass": False,
            "score": 0.0,
            "reason": "ChDR format check failed: " + "; ".join(reasons),
        }

    return {
        "pass": True,
        "score": 1.0,
        "reason": "ChDR has all required sections, a commit SHA, an issue link or no-link marker, and Decision provenance.",
    }
