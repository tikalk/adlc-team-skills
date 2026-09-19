"""Sync checks between the source skills tree and CLI-generated artifacts.

The `adlc-skills-cli` install generates artifacts that are gitignored
(`.agents/skills/` flattened mirror, `.opencode/commands/` slash commands).
Nothing else verifies they match `skills/` — a stale local install silently
behaves differently from a fresh one. These tests fail when the generated
layer drifts from the source of truth.

They skip on trees where the artifacts were never generated (e.g. fresh
clones, CI): regenerate locally with
`npx adlc-skills-cli add tikalk/adlc-team-skills -a opencode`.
"""

import yaml
import pytest
from pathlib import Path

ROOT = Path(__file__).parent.parent.parent
SKILLS_DIR = ROOT / "skills"
MIRROR_DIR = ROOT / ".agents" / "skills"
COMMANDS_DIR = ROOT / ".opencode" / "commands"

pytestmark = pytest.mark.skipif(
    not MIRROR_DIR.exists() or not COMMANDS_DIR.exists(),
    reason="generated install artifacts not present — run adlc-skills-cli locally",
)


def _load_frontmatter(skill_file: Path) -> dict:
    parts = skill_file.read_text(encoding="utf-8").split("---", 2)
    assert len(parts) >= 3, f"Malformed frontmatter in {skill_file}"
    return yaml.safe_load(parts[1]) or {}


def _source_skills() -> dict:
    """Map skill name -> (source SKILL.md path, frontmatter)."""
    skills = {}
    for skill_file in sorted(SKILLS_DIR.glob("**/SKILL.md")):
        meta = _load_frontmatter(skill_file)
        name = meta["name"]
        assert name == skill_file.parent.name, f"name/dir mismatch: {skill_file}"
        skills[name] = (skill_file, meta)
    return skills


def test_mirror_contains_every_skill_with_matching_frontmatter():
    """The flattened .agents/skills/ mirror must match every source skill's name+description."""
    skills = _source_skills()
    mirrored = {p.name for p in MIRROR_DIR.iterdir() if p.is_dir()}

    missing = sorted(set(skills) - mirrored)
    orphans = sorted(mirrored - set(skills))
    assert not missing, f"Skills missing from .agents/skills mirror (stale install): {missing}"
    assert not orphans, f"Mirror orphans with no source skill (stale install): {orphans}"

    mismatches = []
    for name, (_, meta) in skills.items():
        mirror_file = MIRROR_DIR / name / "SKILL.md"
        if not mirror_file.exists():
            mismatches.append(f"{name}: mirror has no SKILL.md")
            continue
        mirror_meta = _load_frontmatter(mirror_file)
        if mirror_meta.get("description") != meta.get("description"):
            mismatches.append(f"{name}: description differs between skills/ and mirror")
    assert not mismatches, f"Mirror frontmatter drift (regenerate with adlc-skills-cli): {mismatches}"


def test_commands_cover_invocable_skills_and_have_no_orphans():
    """.opencode/commands/ must expose every model-invocable skill and nothing else."""
    skills = _source_skills()
    commands = {p.stem for p in COMMANDS_DIR.glob("*.md")}

    # disable-model-invocation skills are deliberately command-less.
    invocable = {name for name, (_, meta) in skills.items()
                 if not meta.get("disable-model-invocation")}
    exempt = sorted(set(skills) - invocable)

    missing = sorted(invocable - commands)
    orphans = sorted(commands - set(skills))
    assert not missing, (
        f"Model-invocable skills without a command file (regenerate with "
        f"adlc-skills-cli): {missing}"
    )
    assert not orphans, f"Command files with no source skill (stale install): {orphans}"


def test_command_files_reference_their_skill():
    """Each generated command must point at the skill it belongs to."""
    skills = _source_skills()
    broken = []
    for command_file in sorted(COMMANDS_DIR.glob("*.md")):
        name = command_file.stem
        if name not in skills:
            continue  # orphan case is covered by the coverage test
        content = command_file.read_text(encoding="utf-8")
        if f"`{name}`" not in content:
            broken.append(f"{command_file.name}: does not reference the `{name}` skill")
    assert not broken, broken
