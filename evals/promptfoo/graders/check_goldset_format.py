import re

def evaluate(output: str, context: dict = None) -> dict:
    """Grader for EVAL-003: Goldset formatting integrity."""
    # Must contain type: Eval, id, and inline pass/fail cases
    has_type = re.search(r"type:\s*Eval", output, re.IGNORECASE)
    has_cases = re.search(r"pass cases|fail cases|examples", output, re.IGNORECASE)
    has_no_traces = not re.search(r"traces/", output, re.IGNORECASE)
    
    if has_type and has_cases and has_no_traces:
        return {
            "pass": True,
            "score": 1.0,
            "reason": "Successfully verified that goldset has correct inline structure and does not publish traces."
        }
        
    return {
        "pass": False,
        "score": 0.0,
        "reason": f"Failed goldset formatting check. Output was: {output}"
    }
