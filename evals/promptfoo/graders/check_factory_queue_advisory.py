import re

def get_assert(output: str, context: dict = None) -> dict:
    """Grader for factory-queue: Ensures triage score is advisory and human decides."""
    has_advisory = re.search(r"advisory|never auto|human decides|gate", output, re.IGNORECASE)
    
    if has_advisory:
        return {
            "pass": True,
            "score": 1.0,
            "reason": "Successfully verified that the triage score is advisory-only and does not bypass human Intent Gate."
        }
        
    return {
        "pass": False,
        "score": 0.0,
        "reason": f"Failed to verify advisory-only triage scoring. Output was: {output}"
    }
