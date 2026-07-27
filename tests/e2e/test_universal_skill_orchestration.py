"""E2E tests for mission-brief Universal Skill Orchestration (Phase 4a.1).

These tests simulate the local skills inventory discovery and delegation prompt
wiring without calling real LLMs. They verify:
1. SKILL.md frontmatter is parsed correctly into the inventory.
2. Empty skills dirs produce an empty inventory + fallback message.
3. The delegation prompt template includes the skills list when populated.
4. The delegation prompt uses the fallback message when inventory is empty.
5. Skills from multiple sources (vendor-agnostic) are all discovered.
"""
import json
import re
import os
from pathlib import Path

import pytest


# ---------------------------------------------------------------------------
# Helpers — simulate Phase 4a.1 discovery logic from SKILL.md
# ---------------------------------------------------------------------------

def _parse_skill_frontmatter(skill_md_path: Path) -> dict:
    """Read a SKILL.md and extract name + description from YAML frontmatter."""
    text = skill_md_path.read_text()
    fm_match = re.match(r"^---\s*\n(.*?)\n---", text, re.DOTALL)
    if not fm_match:
        return {"name": skill_md_path.parent.name, "description": ""}
    fm = fm_match.group(1)
    name = skill_md_path.parent.name
    description = ""
    name_match = re.search(r"^name:\s*(.+)$", fm, re.MULTILINE)
    if name_match:
        raw = name_match.group(1).strip()
        if raw.startswith('"') and raw.endswith('"'):
            raw = raw[1:-1]
        elif raw.startswith("'") and raw.endswith("'"):
            raw = raw[1:-1]
        name = raw
    desc_match = re.search(r"^description:\s*[>|]?\s*\n?(.*?)(?=\n\w|\Z)", fm, re.DOTALL | re.MULTILINE)
    if desc_match:
        description = desc_match.group(1).strip().strip('"').strip("'")
    return {"name": name, "description": description}


def _build_local_skills_inventory(skills_dirs: list) -> list:
    """Simulate Phase 4a.1: scan skills dirs, parse SKILL.md, build inventory."""
    inventory = []
    for skills_dir in skills_dirs:
        p = Path(skills_dir)
        if not p.is_dir():
            continue
        for entry in sorted(p.iterdir()):
            skill_md = entry / "SKILL.md"
            if skill_md.exists():
                meta = _parse_skill_frontmatter(skill_md)
                inventory.append({
                    "name": meta["name"],
                    "path": str(entry),
                    "description": meta["description"],
                })
    return inventory


def _build_local_skills_list(inventory: list) -> str:
    """Build the <LOCAL_SKILLS_LIST> string injected into the delegation prompt."""
    if not inventory:
        return "No custom skills detected in this workspace."
    lines = []
    for skill in inventory:
        lines.append(
            f"- **{skill['name']}** (`{skill['path']}`) — {skill['description']}"
        )
    return "\n".join(lines)


def _make_skill_md(name: str, description: str) -> str:
    """Create a minimal SKILL.md with YAML frontmatter."""
    return f"""---
name: {name}
description: >-
  {description}
---

# {name}

Skill body.
"""


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

def test_local_skills_inventory_discovery(sandbox_project):
    """Phase 4a.1: SKILL.md frontmatter is parsed into discovered.local_skills."""
    skills_dir = sandbox_project / ".claude" / "skills"
    skills_dir.mkdir(parents=True)

    (skills_dir / "tdd").mkdir()
    (skills_dir / "tdd" / "SKILL.md").write_text(
        _make_skill_md("tdd", "Test-driven development with red-green-refactor loop.")
    )
    (skills_dir / "grill-me").mkdir()
    (skills_dir / "grill-me" / "SKILL.md").write_text(
        _make_skill_md("grill-me", "Get relentlessly interviewed about a plan or design.")
    )
    (skills_dir / "code-review").mkdir()
    (skills_dir / "code-review" / "SKILL.md").write_text(
        _make_skill_md("code-review", "Two-axis review of the diff since a fixed point.")
    )

    inventory = _build_local_skills_inventory([str(skills_dir)])

    assert len(inventory) == 3
    names = [s["name"] for s in inventory]
    assert "tdd" in names
    assert "grill-me" in names
    assert "code-review" in names

    tdd = next(s for s in inventory if s["name"] == "tdd")
    assert "Test-driven development" in tdd["description"]
    assert tdd["path"].endswith("/tdd")


def test_local_skills_inventory_empty(sandbox_project):
    """Phase 4a.1: no skills dir → empty inventory + fallback message."""
    inventory = _build_local_skills_inventory([])
    assert inventory == []

    list_str = _build_local_skills_list(inventory)
    assert list_str == "No custom skills detected in this workspace."


def test_local_skills_inventory_missing_frontmatter(sandbox_project):
    """Phase 4a.1: SKILL.md without frontmatter falls back to directory name."""
    skills_dir = sandbox_project / ".agents" / "skills"
    skills_dir.mkdir(parents=True)

    (skills_dir / "custom-skill").mkdir()
    (skills_dir / "custom-skill" / "SKILL.md").write_text(
        "# custom-skill\n\nNo frontmatter here.\n"
    )

    inventory = _build_local_skills_inventory([str(skills_dir)])
    assert len(inventory) == 1
    assert inventory[0]["name"] == "custom-skill"
    assert inventory[0]["description"] == ""


def test_local_skills_inventory_vendor_agnostic(sandbox_project):
    """Phase 4a.1: skills from multiple dirs (simulating multiple sources) are all found."""
    claude_dir = sandbox_project / ".claude" / "skills"
    agents_dir = sandbox_project / ".agents" / "skills"
    claude_dir.mkdir(parents=True)
    agents_dir.mkdir(parents=True)

    (claude_dir / "tdd").mkdir()
    (claude_dir / "tdd" / "SKILL.md").write_text(
        _make_skill_md("tdd", "Matt Pocock's TDD skill.")
    )
    (agents_dir / "evals-validate").mkdir()
    (agents_dir / "evals-validate" / "SKILL.md").write_text(
        _make_skill_md("evals-validate", "ADLC evals validation skill.")
    )

    inventory = _build_local_skills_inventory([str(claude_dir), str(agents_dir)])
    assert len(inventory) == 2
    names = [s["name"] for s in inventory]
    assert "tdd" in names
    assert "evals-validate" in names


def test_delegation_prompt_includes_skills_list(sandbox_project):
    """Phase 5: delegation prompt includes <LOCAL_SKILLS_LIST> when inventory is populated."""
    inventory = [
        {"name": "tdd", "path": ".claude/skills/tdd", "description": "Red-green-refactor loop."},
        {"name": "grill-me", "path": ".claude/skills/grill-me", "description": "Interview about a plan."},
    ]
    list_str = _build_local_skills_list(inventory)

    assert "**tdd**" in list_str
    assert ".claude/skills/tdd" in list_str
    assert "Red-green-refactor loop." in list_str
    assert "**grill-me**" in list_str

    # Verify the list can be embedded in the delegation prompt template
    delegation_prompt = f"""## Available Skills in This Workspace

{list_str}

The list above shows skills installed in this workspace from any source.
"""
    assert "## Available Skills in This Workspace" in delegation_prompt
    assert "**tdd**" in delegation_prompt
    assert "**grill-me**" in delegation_prompt


def test_delegation_prompt_empty_fallback(sandbox_project):
    """Phase 5: empty inventory → fallback message in delegation prompt."""
    list_str = _build_local_skills_list([])

    delegation_prompt = f"""## Available Skills in This Workspace

{list_str}
"""
    assert "No custom skills detected in this workspace." in delegation_prompt


def test_mission_state_json_includes_local_skills(sandbox_project):
    """Phase 4a.1: .mission-state.json.discovered includes local_skills field."""
    skills_dir = sandbox_project / ".claude" / "skills"
    skills_dir.mkdir(parents=True)
    (skills_dir / "tdd").mkdir()
    (skills_dir / "tdd" / "SKILL.md").write_text(
        _make_skill_md("tdd", "TDD skill.")
    )

    inventory = _build_local_skills_inventory([str(skills_dir)])

    state = {
        "discovered": {
            "skills_dirs": [str(skills_dir)],
            "commands_dirs": [],
            "local_skills": inventory,
        }
    }

    state_file = sandbox_project / ".adlc" / "workflow" / ".mission-state.json"
    state_file.parent.mkdir(parents=True, exist_ok=True)
    state_file.write_text(json.dumps(state, indent=2))

    loaded = json.loads(state_file.read_text())
    assert "local_skills" in loaded["discovered"]
    assert len(loaded["discovered"]["local_skills"]) == 1
    assert loaded["discovered"]["local_skills"][0]["name"] == "tdd"
