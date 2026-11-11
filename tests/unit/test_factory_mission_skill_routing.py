"""factory-mission skill routing contract.

Skill routing is harness-native: step prompts name skills by exact name and
the dispatched subagent resolves them through its own Skill tool (the
runtime injects the installed inventory — no filesystem scan).
`references/agent-integrations.md` is the fallback for commands-based
frameworks the model cannot see, and nothing more.

Carries no record IDs; contracts are prose tokens and headings.
"""

from pathlib import Path

ROOT = Path(__file__).parent.parent.parent
FACTORY_MD = ROOT / "skills/factory/factory-mission/SKILL.md"
REF_MD = ROOT / "skills/factory/factory-mission/references/agent-integrations.md"


def test_skill_routing_is_harness_native_not_scanned():
    text = FACTORY_MD.read_text(encoding="utf-8")
    assert "resolves them through its own Skill tool" in text, (
        "skill resolution must go through the harness Skill tool — "
        "the capability bullet must state the mechanism"
    )
    assert "scans installed skills" not in text
    assert "Local skills inventory" not in text
    assert "discovered.local_skills" not in text


def test_agent_integrations_is_commands_fallback_only():
    ref = REF_MD.read_text(encoding="utf-8")
    assert "## Commands-based agents" in ref
    assert "## Skills-based agents" not in ref
    assert "local_skills" not in ref
    assert ".mission-state.json" not in ref
    assert "fallback" in ref.lower()
