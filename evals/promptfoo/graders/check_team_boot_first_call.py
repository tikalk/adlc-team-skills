import re

def get_assert(output: str, context: dict = None) -> dict:
    """Grader for EVAL-004: team-boot first-tool-call gate."""
    # Compliant first tool call: skill({name: "team-boot"}) or skill({name: 'team-boot'})
    has_skill_call = re.search(r'skill\(\s*\{\s*name\s*:\s*["\']team-boot["\']\s*\}\s*\)', output, re.IGNORECASE)

    # Rationalization patterns that indicate skipping the check
    rationalization_patterns = [
        r'plan[- ]mode\s+(forbids|forbid|conflict)',
        r'need\s+to\s+be\s+efficient',
        r'focus\s+on\s+the\s+task',
        r"I'?ll\s+explore\s+(the\s+codebase\s+)?first",
        r'too\s+simple',
        r'just\s+this\s+one\s+thing\s+first',
    ]
    has_rationalization = any(
        re.search(pattern, output, re.IGNORECASE) for pattern in rationalization_patterns
    )

    # Non-skill tools that indicate a violation when they appear before the skill call
    non_skill_tools = re.search(
        r'\b(read|grep|glob|bash)\s*[\(:]', output, re.IGNORECASE
    )

    if has_skill_call and not has_rationalization:
        return {
            "pass": True,
            "score": 1.0,
            "reason": "First tool call is skill({name: \"team-boot\"}) with no rationalization."
        }

    reasons = []
    if has_rationalization:
        reasons.append("response contains a rationalization pattern for skipping team-boot")
    if non_skill_tools and not has_skill_call:
        reasons.append("first tool call is a non-skill tool (read/grep/glob/bash) instead of skill({name: \"team-boot\"})")
    if not has_skill_call and not reasons:
        reasons.append("no skill({name: \"team-boot\"}) call detected in output")

    return {
        "pass": False,
        "score": 0.0,
        "reason": f"Failed team-boot first-tool-call gate: {'; '.join(reasons)}. Output was: {output}"
    }
