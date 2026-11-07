import re

def get_assert(output: str, context: dict = None) -> dict:
    """Grader for EVAL-005: Universal Skill Orchestration — harness-native skill routing.

    Verifies that the factory-mission delegation prompt:
    1. Names at least one skill by exact name (routing stays LLM-decided).
    2. Directs the subagent to resolve named skills through its own Skill tool.
    3. Carries the commands-dir fallback for commands-based frameworks.
    4. Does NOT embed a scanned "Available Skills" inventory section
       (the removed scan mechanism).
    5. Does NOT hard-code phase-to-skill mapping tables.
    """
    # Removed mechanism: scanned skills inventory embedded in the prompt
    # (pre-rewrite delegation prompts carried a filesystem-scanned inventory)
    has_scanned_inventory = re.search(
        r"available\s+skills(\s+in\s+(this|the)\s+workspace)?\s*[:\-\n|]",
        output,
        re.IGNORECASE,
    )

    # Must name at least one skill by exact name — a backticked/quoted token
    # adjacent to the word "skill" (e.g. "the `tdd` skill"), so a backticked
    # non-skill token (e.g. "the `retry` helper") does not satisfy the check
    names_exact_skill = re.search(
        r"[`\"'][\w-]+[`\"']\s+skill\b|skill\s+[`\"'][\w-]+[`\"']",
        output,
        re.IGNORECASE,
    )

    # Must direct resolution through the subagent's own Skill tool
    resolves_via_skill_tool = re.search(
        r"(your|its|their|the)\s+(own\s+)?skill\s+tool"
        r"|via\s+(the\s+|your\s+|its\s+)?skill\s+tool"
        r"|resolve[sd]?\s+[^.\n]{0,40}skill\s+tool",
        output,
        re.IGNORECASE,
    )

    # Must carry the commands-dir fallback for commands-based frameworks
    has_commands_fallback = re.search(
        r"commands?[- ]dir|commands[- ]based|agent-integrations"
        r"|absent[^.\n]{0,60}direct|execute[sd]?\s+directly",
        output,
        re.IGNORECASE,
    )

    # Must NOT hard-code phase-to-skill mapping (routing is LLM-decided)
    has_hardcoded_mapping = re.search(
        r"phase\s+\w+\s*(→|->|maps?\s+to)\s*skill", output, re.IGNORECASE
    )

    reasons = []
    if has_scanned_inventory:
        reasons.append(
            "embeds a scanned 'Available Skills' inventory (removed mechanism — "
            "skills are named by exact name and resolved via the subagent's "
            "Skill tool)"
        )
    if not names_exact_skill:
        reasons.append("does not name a skill by exact name")
    if not resolves_via_skill_tool:
        reasons.append("missing Skill-tool resolution instruction")
    if not has_commands_fallback:
        reasons.append("missing commands-dir fallback for commands-based frameworks")
    if has_hardcoded_mapping:
        reasons.append("contains hard-coded phase-to-skill mapping (should be LLM-decided)")

    if not reasons:
        return {
            "pass": True,
            "score": 1.0,
            "reason": "Delegation prompt names skills by exact name, resolves them "
            "via the subagent's own Skill tool, carries the commands-dir "
            "fallback, and embeds no scanned inventory or hard-coded mapping.",
        }

    return {
        "pass": False,
        "score": 0.0,
        "reason": f"Universal skill routing check failed: {'; '.join(reasons)}. Output was: {output}",
    }
