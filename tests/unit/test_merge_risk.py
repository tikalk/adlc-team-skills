"""Contract test for the factory-review merge-risk scoring sub-step (Task 3).

After the passes run, the reviewer scores five risk rows (Verification /
Alignment / Impact / Rollback cost / Error detection) from the pass
outputs before compiling the verdict. The `sensitive-paths:` policy
field (with auth / billing / migrations defaults) feeds the Impact row
and replaces Task 2's interim inline triage list; `codeowners:` is an
advisory-only routing hint. Risk informs the verdict narrative — it
never changes `outcome=` (only an open Important finding does that).
"""

from pathlib import Path

REPO = Path(__file__).parent.parent.parent
POLICY = REPO / "skills" / "factory" / "factory-review" / "references" / "review-policy.md"
SKILL = REPO / "skills" / "factory" / "factory-review" / "SKILL.md"
LOOP = REPO / "skills" / "factory" / "factory-review" / "references" / "review-loop.md"

# Task 2's interim inline triage list. Task 3 moves this into the
# REVIEW.md `sensitive-paths:` policy field; the triage preamble reads
# that field instead of carrying its own copy.
SENSITIVE_PATHS = ("auth", "billing", "migrations")

RISK_ROWS = ("verification", "alignment", "impact", "rollback", "error detection")


def _read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_policy_defines_sensitive_paths_with_defaults():
    """review-policy.md defines `sensitive-paths:` with auth/billing/migrations."""
    text = _read(POLICY)
    assert "sensitive-paths:" in text, "review-policy.md must define a `sensitive-paths:` field"
    lowered = text.lower()
    for path in SENSITIVE_PATHS:
        assert path in lowered, f"`sensitive-paths:` must list default '{path}'"


def test_policy_defines_codeowners_advisory_only():
    """review-policy.md defines `codeowners:` as an advisory-only routing hint."""
    text = _read(POLICY)
    assert "codeowners:" in text, "review-policy.md must define a `codeowners:` field"
    assert "advisory" in text.lower(), "`codeowners:` must be marked advisory-only"


def test_default_template_carries_policy_fields():
    """The Default Template section carries `sensitive-paths:` + `codeowners:`."""
    text = _read(POLICY)
    template = text.split("## Default Template", 1)[1]
    assert "sensitive-paths:" in template, "Default Template missing `sensitive-paths:`"
    assert "codeowners:" in template, "Default Template missing `codeowners:`"


def test_skill_risk_substep_five_rows():
    """SKILL.md scores five risk rows before the verdict compile."""
    skill = _read(SKILL).lower()
    assert "merge-risk" in skill or "risk" in skill, "SKILL.md must name the risk sub-step"
    for row in RISK_ROWS:
        assert row in skill, f"risk sub-step must score the '{row}' row"


def test_skill_risk_rows_require_evidence_or_unverified():
    """Each risk row carries an evidence pointer or `unverified`."""
    skill = _read(SKILL)
    lowered = skill.lower()
    assert "evidence" in lowered, "risk rows must require an evidence pointer"
    assert "unverified" in lowered, "risk rows with missing evidence must be `unverified`"


def test_risk_never_changes_outcome():
    """Risk informs the verdict narrative; only Important findings change `outcome=`."""
    skill = _read(SKILL).lower()
    assert "outcome=" in skill, "risk rule must name `outcome=`"
    assert "never" in skill, "risk rule must state risk never changes `outcome=`"


def test_triage_reads_policy_sensitive_paths():
    """review-loop.md triage reads the policy field instead of an inline copy."""
    text = _read(LOOP)
    lowered = text.lower()
    assert "sensitive-paths" in lowered, (
        "triage preamble must reference the `sensitive-paths:` policy field"
    )
    assert "review-policy" in lowered, "triage preamble must point at review-policy.md"
