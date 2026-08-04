import re

def get_assert(output: str, context: dict = None) -> dict:
    """Grader for EVAL-004: Team Context in Use table compliance."""
    reasons = []

    # 1. Section heading present
    if "Team Context in Use" not in output:
        reasons.append("missing 'Team Context in Use' section heading")

    # 2. 4-column table header
    header = re.search(r'\|\s*ID\s*\|\s*Name\s*\|\s*Type\s*\|\s*Relevance\s*\|', output)
    if not header:
        reasons.append("missing 4-column table header (| ID | Name | Type | Relevance |)")

    # 3. At least one real CDR data row (CDR-YYYY-NNN with real digits)
    real_cdr = re.search(r'CDR-\d{4}-\d{3}', output)
    if not real_cdr:
        reasons.append("no real CDR ID row (CDR-YYYY-NNN with digits) in the table")

    # 4. Must NOT contain the literal placeholder
    if "CDR-YYYY-NNN" in output:
        reasons.append("response copies the placeholder example row (CDR-YYYY-NNN) verbatim instead of a real match")

    # 5. Searched metadata line with numeric counts
    searched = re.search(r'_Searched\s+\d+\s+CDR entries?,\s+\d+\s+skills?,\s+\d+\s+matched\._', output)
    if not searched:
        reasons.append("missing '_Searched N CDR entries, M skills, J matched._' metadata line with numeric counts")

    if not reasons:
        return {
            "pass": True,
            "score": 1.0,
            "reason": "Team Context in Use table present with real CDR row and numeric search metadata."
        }

    return {
        "pass": False,
        "score": 0.0,
        "reason": f"Team Context in Use table non-compliant: {'; '.join(reasons)}. Output was: {output}"
    }
