import re

def evaluate(output: str, context: dict = None) -> dict:
    """Binary pass/fail grader for hallucination detection (EDD Principle II)."""
    # Simple regex checking for common placeholders or obvious fabrications
    hallucination_indicators = [
        r"\[placeholder\]",
        r"<insert .* here>",
        r"fabricate",
        r"I'm sorry, I cannot verify this fact"
    ]
    
    violations = []
    for pattern in hallucination_indicators:
        if re.search(pattern, output, re.IGNORECASE):
            violations.append(pattern)
            
    if violations:
        return {
            "pass": False,
            "score": 0.0,
            "reason": f"Hallucination / Placeholder patterns detected: {', '.join(violations)}"
        }
        
    return {
        "pass": True,
        "score": 1.0,
        "reason": "Compliance verified: No obvious hallucination patterns detected."
    }
