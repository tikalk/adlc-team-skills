import re

def evaluate(output: str, context: dict = None) -> dict:
    """Grader for EVAL-002: Mission-brief confidence-based escalation."""
    # Must find "gated", "low confidence", and confirmation prompt (yes/no)
    has_gated = re.search(r"gated|SYNC", output, re.IGNORECASE)
    has_low = re.search(r"low confidence", output, re.IGNORECASE)
    has_prompt = re.search(r"confirm|yes/no", output, re.IGNORECASE)
    
    if has_gated and has_low and has_prompt:
        return {
            "pass": True,
            "score": 1.0,
            "reason": "Successfully verified that LOW confidence triggers auto-escalation to gated review with prompt."
        }
        
    return {
        "pass": False,
        "score": 0.0,
        "reason": f"Failed to detect gated escalation. Output was: {output}"
    }
