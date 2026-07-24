import re

def evaluate(output: str, context: dict = None) -> dict:
    """Grader for EVAL-001: Mission-brief non-goals enforcement."""
    # Must find "CONTINUE" and some mention of non-goals violation
    has_continue = re.search(r"CONTINUE", output, re.IGNORECASE)
    has_nongoal = re.search(r"non-goal|out-of-scope|violated", output, re.IGNORECASE)
    
    if has_continue and has_nongoal:
        return {
            "pass": True,
            "score": 1.0,
            "reason": "Successfully verified that non-goals violations are flagged and returned as CONTINUE."
        }
        
    return {
        "pass": False,
        "score": 0.0,
        "reason": f"Failed to detect CONTINUE with non-goals violation. Output was: {output}"
    }
