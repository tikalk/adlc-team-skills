import re

SHA = re.compile(r"\b[0-9a-f]{7,40}\b", re.IGNORECASE)
URL = re.compile(r"https?://\S+")
DECISION_SECTION = re.compile(
    r"^#{2,3}\s*Decision\b[^\n]*\n(.*?)(?=^#{2,3}\s|\Z)",
    re.MULTILINE | re.DOTALL,
)
PROMOTED_CLAIM = re.compile(
    r"(promoted|published|pushed)\s+(it\s+)?to\s+.*docs/adlc/memory"
    r"|wrote\s+.*docs/adlc/memory",
    re.IGNORECASE,
)


def get_assert(output: str, context: dict = None) -> dict:
    """Grader for EVAL-015: change-specify in-session ChDR capture.

    A change-specify run must:
      - produce a ChDR draft (draft status proposed, not published),
      - anchor the Decision claim with provenance (commit SHA, PR, or issue URL),
      - route review to /change-clarify,
      - NOT promote to docs/adlc/memory (that is /change-publish's job).
    """
    reasons = []

    if not re.search(r"chdr-\d+|change decision record", output, re.IGNORECASE):
        reasons.append("no ChDR draft identified")

    if not re.search(r"status:\s*proposed|status:\s*\*\*proposed\*\*", output, re.IGNORECASE):
        reasons.append("draft not marked status: proposed")

    decision_body = ""
    m = DECISION_SECTION.search(output)
    if m:
        decision_body = m.group(1)
    provenance_source = decision_body or output
    if not (SHA.search(provenance_source) or URL.search(provenance_source)):
        reasons.append("Decision claim carries no SHA/PR/issue-URL provenance")

    if "/change-clarify" not in output:
        reasons.append("does not route review to /change-clarify")

    if PROMOTED_CLAIM.search(output):
        reasons.append("claims promotion to docs/adlc/memory (change-publish's job)")

    if reasons:
        return {
            "pass": False,
            "score": 0.0,
            "reason": "change-specify capture check failed: " + "; ".join(reasons),
        }

    return {
        "pass": True,
        "score": 1.0,
        "reason": "Proposed ChDR draft with Decision provenance, routed to /change-clarify, drafts-only.",
    }
