"""Contract test for the factory-review visual-evidence pass.

The `pass: visual-evidence` requires a verdict-first proof chain
(banner -> intent diagram -> change diagram -> recording with
per-criterion timestamps). This test pins the policy text contract:
the pass exists with severity Important, carries the required checks,
and degrades honestly for docs/config-only PRs.
"""

from pathlib import Path

REPO = Path(__file__).parent.parent.parent
POLICY = REPO / "skills" / "factory" / "factory-review" / "references" / "review-policy.md"
SKILL = REPO / "skills" / "factory" / "factory-review" / "SKILL.md"


def _read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def _section(text: str) -> str:
    assert "pass: visual-evidence" in text, "review-policy.md has no visual-evidence pass"
    return text.split("pass: visual-evidence", 1)[1].split("### pass:", 1)[0]


def test_visual_evidence_pass_defined_with_important_severity():
    """review-policy.md defines `pass: visual-evidence` with severity Important."""
    text = _read(POLICY)
    assert "### pass: visual-evidence" in text
    section = _section(text)
    assert "Important" in section, "visual-evidence pass must carry severity Important"


def test_visual_evidence_checks_verdict_banner():
    """Banner check names `head=` + `outcome=` at the top of the verdict body."""
    section = _section(_read(POLICY))
    assert "head=" in section, "banner check must name head="
    assert "outcome=" in section, "banner check must name outcome="


def test_visual_evidence_checks_intent_diagram_criterion_hunk_mapping():
    """Intent diagram is a criterion->hunk mapping citing the governing brief."""
    section = _section(_read(POLICY))
    assert "criterion" in section.lower(), "intent diagram must map criteria"
    assert "hunk" in section.lower(), "intent diagram must map hunks"
    assert "mermaid" in section.lower(), "intent diagram must be mermaid in v1"


def test_visual_evidence_checks_change_diagram_before_after_names_files():
    """Change diagram shows before -> after and names the files/paths changed."""
    section = _section(_read(POLICY))
    assert "before" in section.lower(), "change diagram must show before"
    assert "after" in section.lower(), "change diagram must show after"
    assert "files" in section.lower() or "paths" in section.lower()


def test_visual_evidence_checks_recording_per_criterion_timestamps():
    """Recording is mp4/webm with one timestamp per Success Criterion."""
    section = _section(_read(POLICY))
    assert "mp4/webm" in section, "recording must be mp4/webm in v1"
    assert "@M:SS" in section, "recording must carry per-criterion @M:SS timestamps"


def test_visual_evidence_missing_artifact_is_unverified_important():
    """A missing artifact is an `unverified:` Important finding blocking merge-readiness."""
    section = _section(_read(POLICY))
    assert "unverified:" in section
    assert "Important" in section


def test_visual_evidence_not_applicable_disclosure_for_docs_config():
    """Docs-only / config-only PRs degrade to disclosed `not-applicable`, never a block."""
    section = _section(_read(POLICY))
    assert "not-applicable" in section
    lowered = section.lower()
    assert "docs" in lowered and "config" in lowered


def test_default_template_carries_visual_evidence():
    """The Default Template section carries the new pass."""
    text = _read(POLICY)
    template = text.split("## Default Template", 1)[1]
    assert "pass: visual-evidence" in template, "Default Template missing visual-evidence pass"


def test_skill_pipeline_names_visual_evidence():
    """SKILL.md's single-review pipeline names the pass and its banner + chain."""
    skill = _read(SKILL)
    assert "visual-evidence" in skill
    assert "head=" in skill


def test_skill_preview_renders_draft_chain_without_marker():
    """SKILL.md's --preview renders the chain as draft with no marker."""
    skill = _read(SKILL)
    assert "visual-evidence" in skill
    assert "draft" in skill.lower()
