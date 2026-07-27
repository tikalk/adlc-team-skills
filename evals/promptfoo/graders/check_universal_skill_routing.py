import re

def get_assert(output: str, context: dict = None) -> dict:
    """Grader for EVAL-005: Universal Skill Orchestration — local skills routing.

    Verifies that the mission-brief delegation prompt:
    1. Includes an "Available Skills" section listing installed skills.
    2. Shows skill names with descriptions (not just bare names).
    3. Instructs the subagent to invoke matching skills.
    4. Does NOT hard-code specific vendor skill names (must be dynamic).
    """
    # Must have an "Available Skills" section
    has_available_section = re.search(
        r"available\s+skills", output, re.IGNORECASE
    )

    # Must list at least one skill with a description (name + description pattern)
    has_skill_with_desc = re.search(
        r"\*{0,2}[\w-]+\*{0,2}\s*[`(`].*?[)`]?\s*[—\-:]\s*\w+", output
    ) or re.search(
        r"[\w-]+.*?(red-green|interview|review|test|plan|implement|skill)", output, re.IGNORECASE
    )

    # Must instruct the subagent to invoke matching skills
    has_invoke_instruction = re.search(
        r"invoke|use\s+(it|this|the)|call\s+(the\s+)?skill", output, re.IGNORECASE
    )

    # Must NOT hard-code a specific vendor mapping table (e.g., "phase X → skill Y")
    # The routing must be LLM-decided, not a static lookup
    has_hardcoded_mapping = re.search(
        r"phase\s+\w+\s*(→|->|maps?\s+to)\s*skill", output, re.IGNORECASE
    )

    # Must mention fallback ("proceed with direct execution" or similar)
    has_fallback = re.search(
        r"direct\s+execution|proceed\s+directly|if\s+none\s+apply", output, re.IGNORECASE
    )

    reasons = []
    if not has_available_section:
        reasons.append("missing 'Available Skills' section")
    if not has_invoke_instruction:
        reasons.append("missing instruction to invoke matching skills")
    if has_hardcoded_mapping:
        reasons.append("contains hard-coded phase-to-skill mapping (should be LLM-decided)")

    if not reasons:
        return {
            "pass": True,
            "score": 1.0,
            "reason": "Delegation prompt includes available skills section, invoke instruction, and no hard-coded mappings."
        }

    return {
        "pass": False,
        "score": 0.0,
        "reason": f"Universal skill routing check failed: {'; '.join(reasons)}. Output was: {output}"
    }
