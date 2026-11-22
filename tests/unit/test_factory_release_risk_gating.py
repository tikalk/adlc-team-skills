"""Human-gated mechanical merge contract (Task 4 of the merge-risk plan).

Pins the governance the prose must state: merge executes only via the
factory-release gated exact-head executor after both gates green on the SAME
SHA with a recorded human; risk bands route review effort (low -> fast-lane
single-approval queue, medium -> standard, high -> full) strictly DOWNSTREAM
of both-gates-green; branch-rule auto-merge is the executor, never the
authorization; no auto-approve tier exists.

TDD RED step: none of this prose exists yet, so every assertion FAILS here.
"""
from pathlib import Path

REVIEW = Path(__file__).parent.parent.parent / "skills/factory/factory-review"
RELEASE = Path(__file__).parent.parent.parent / "skills/factory/factory-release"

REVIEW_SKILL = REVIEW / "SKILL.md"
RELEASE_SKILL = RELEASE / "SKILL.md"
GATED = RELEASE / "references/gated-merge.md"


def test_gated_merge_states_risk_routing_is_downstream_of_both_gates():
    text = GATED.read_text(encoding="utf-8")
    assert "fast-lane" in text, "gated-merge: no fast-lane routing"
    low_i = text.index("**low**")
    assert "both" in text[:low_i].lower() and "same sha" in text[:low_i].lower(), \
        "gated-merge: risk routing must sit downstream of both-gates-green-same-SHA"


def test_gated_merge_states_no_auto_approve_tier():
    text = GATED.read_text(encoding="utf-8")
    assert "no auto-approve tier" in text.lower(), "gated-merge: missing no-auto-approve rule"


def test_gated_merge_states_single_gate_is_never_enough():
    text = GATED.read_text(encoding="utf-8")
    assert "single gate is never enough" in text.lower(), \
        "gated-merge: missing single-gate red flag"


def test_review_safety_names_executor_never_authorizes():
    text = REVIEW_SKILL.read_text(encoding="utf-8")
    assert "never the authorization" in text, \
        "factory-review Safety: executor-never-authorizes rule missing"
    assert "code-owner approval recorded on the exact head" in text, \
        "factory-review Safety: recorded code-owner approval on exact head missing"


def test_release_skill_names_risk_band_routing():
    text = RELEASE_SKILL.read_text(encoding="utf-8")
    assert "Merge risk:" in text or "risk band" in text.lower(), \
        "factory-release SKILL: no risk-band routing note"
