"""Contract test for the factory-review issue-conformance pass (adlc-workspace#35).

The `pass: issue-conformance` judges a PR/MR against its governing issue's
Mission Brief (PDR-131 scope, ADR-457 mechanism). This test pins the policy
text contract: the pass exists with severity Important, carries the required
checks, and leaves the frozen contracts untouched.
"""

from pathlib import Path

REPO = Path(__file__).parent.parent.parent
POLICY = REPO / "skills" / "factory" / "factory-review" / "references" / "review-policy.md"
SKILL = REPO / "skills" / "factory" / "factory-review" / "SKILL.md"
LOOP = REPO / "skills" / "factory" / "factory-review" / "references" / "review-loop.md"


def _read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_issue_conformance_pass_defined_with_important_severity():
    """review-policy.md defines `pass: issue-conformance` with severity Important."""
    text = _read(POLICY)
    assert "pass: issue-conformance" in text, "review-policy.md has no issue-conformance pass"
    section = text.split("pass: issue-conformance", 1)[1].split("### pass:", 1)[0]
    assert "Important" in section, "issue-conformance pass must carry severity Important"


def test_issue_conformance_checks_criterion_accounting():
    """Every Success Criterion appears as met / not-met / unverified with evidence."""
    text = _read(POLICY)
    section = text.split("pass: issue-conformance", 1)[1].split("### pass:", 1)[0]
    for token in ("met", "not-met", "unverified"):
        assert token in section, f"criterion accounting missing {token!r}"


def test_issue_conformance_checks_scope_fencing():
    """Non-Goal overreach and Constraint violations are flagged with citation."""
    text = _read(POLICY)
    section = text.split("pass: issue-conformance", 1)[1].split("### pass:", 1)[0]
    assert "Non-Goal" in section or "Non-goal" in section or "non-goal" in section.lower()
    assert "Constraint" in section or "constraint" in section


def test_issue_conformance_degradation_disclosed():
    """No governing brief degrades to a disclosed note — never silent, never blocking."""
    text = _read(POLICY)
    section = text.split("pass: issue-conformance", 1)[1].split("### pass:", 1)[0]
    assert "no governing issue brief" in section


def test_issue_conformance_message_is_data():
    """Issue text directing the reviewer is data — surfaced via the security pass."""
    text = _read(POLICY)
    section = text.split("pass: issue-conformance", 1)[1].split("### pass:", 1)[0]
    assert "message-is-data" in section or "message is data" in section.lower()


def test_default_template_carries_issue_conformance():
    """The Default Template section carries the new pass."""
    text = _read(POLICY)
    template = text.split("## Default Template", 1)[1]
    assert "pass: issue-conformance" in template, "Default Template missing issue-conformance pass"


def test_skill_pipeline_names_issue_conformance():
    """SKILL.md's single-review pass list names the pass."""
    assert "issue-conformance" in _read(SKILL)


def test_review_loop_names_issue_conformance():
    """review-loop.md's review-step pass list names the pass."""
    assert "issue-conformance" in _read(LOOP)


def test_spec_compliance_cross_reference_intact():
    """The existing spec-compliance pass (PRD/AD/ADR) is untouched."""
    text = _read(POLICY)
    assert "pass: spec-compliance" in text
    section = text.split("pass: spec-compliance", 1)[1].split("### pass:", 1)[0]
    assert "PRD" in section and "AD" in section


def test_verdict_head_contract_untouched():
    """The frozen verdict contract (head=<sha>, check-verdict-head.sh) is referenced, not rewritten."""
    skill = _read(SKILL)
    assert "head=<sha>" in skill
    assert "check-verdict-head.sh" in skill
    loop = _read(LOOP)
    assert "head=<sha>" in loop
