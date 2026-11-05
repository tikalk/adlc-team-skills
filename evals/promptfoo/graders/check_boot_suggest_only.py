import re

CAPTURE_SKILLS = (
    "/architect-specify",
    "/product-specify",
    "/change-specify",
    "/change-init",
    "/team-levelup",
    "/evals-specify",
)

# Claims that the responder WROTE/CREATED a draft itself — forbidden for boots.
WRITE_CLAIM = re.compile(
    r"\b(i|we)\s+(wrote|written|created|saved|generated|recorded)\b"
    r"[^.\n]{0,80}"
    r"(\.adlc/drafts|draft file|chdr-\d|adr-\d|pdr-\d)",
    re.IGNORECASE,
)
DIRECT_WRITE = re.compile(
    r"(draft (has been|is now|was) (written|created|saved)"
    r"|wrote the draft"
    r"|writing the draft (now|myself)"
    r"|\.adlc/drafts/[a-z]+/[a-z]+-\d+\.md\b)",
    re.IGNORECASE,
)


def get_assert(output: str, context: dict = None) -> dict:
    """Grader for EVAL-014: class-boot capture is suggest-only.

    A boot facing a detected decision must:
      - suggest the class capture skill by name (the user runs it),
      - claim NO draft/file write of its own — the capture skill writes the
        draft when invoked; boots never touch .adlc/drafts/.
    """
    reasons = []

    if not any(skill in output for skill in CAPTURE_SKILLS):
        reasons.append("no class capture skill named in the suggestion")

    if WRITE_CLAIM.search(output):
        reasons.append("claims to have written/created a draft itself")

    if DIRECT_WRITE.search(output):
        reasons.append("asserts a concrete draft path was written (direct-write)")

    if reasons:
        return {
            "pass": False,
            "score": 0.0,
            "reason": "Boot capture check failed: " + "; ".join(reasons),
        }

    return {
        "pass": True,
        "score": 1.0,
        "reason": "Capture skill suggested by name; no draft write claimed by the boot.",
    }
