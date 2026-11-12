"""Contract test for the correction-elimination ladder (work item #90).

Guards the Tier 1 → Tier 2 → Tier 3 routing wired into factory-review §5,
team-levelup Phase 1b, factory-learn's retrospective route, and EVAL-016.
No prose CDR may be the default for a mechanically checkable mistake.
"""

from pathlib import Path
import re

ROOT = Path(__file__).parent.parent.parent

REVIEW = ROOT / "skills/factory/factory-review/SKILL.md"
POLICY = ROOT / "skills/factory/factory-review/references/review-policy.md"
LEVELUP = ROOT / "skills/team/team-levelup/SKILL.md"
LEARN = ROOT / "skills/factory/factory-learn/SKILL.md"


def test_review_routes_through_ordered_ladder():
    """factory-review §5 names all three tiers in structural-first order."""
    text = REVIEW.read_text(encoding="utf-8")
    t1 = text.find("Tier 1")
    t2 = text.find("Tier 2")
    t3 = text.find("Tier 3")
    assert t1 != -1 and t2 != -1 and t3 != -1, "all three tiers must be named"
    assert t1 < t2 < t3, "tiers must appear structural-first, mechanical-second, judgment-last"
    assert "must never become the default" in text or "never become the default" in text, (
        "prose-CDR default must be explicitly forbidden"
    )


def test_review_policy_recurrence_identity_kept():
    """Twice-mistake identity (same pass + same check item) is the recurrence key."""
    text = POLICY.read_text(encoding="utf-8")
    assert "same pass + same check item" in text, "recurrence identity must be pass+check"
    assert "Tier 1" in text and "Tier 2" in text and "Tier 3" in text


def test_levelup_classifies_before_scoring():
    """team-levelup Phase 1b classifies corrections; scoring never overrides."""
    text = LEVELUP.read_text(encoding="utf-8")
    i_class = text.find("Phase 1b")
    i_score = text.find("Phase 2: Score Confidence")
    assert i_class != -1, "Phase 1b classification must exist"
    assert i_score != -1 and i_class < i_score, "classification must precede scoring"
    assert "never" in text[i_class:i_class + 1200].lower() and "overrides" in text[i_class:i_class + 1200].lower(), (
        "scoring-must-not-override must be explicit"
    )
    seg1b = text[i_class:i_class + 2000]
    assert "Promote to check" in seg1b, "Tier 2 must prefer action P"


def test_levelup_tier_routes_correct():
    """Tier 1 → architect-specify/ADR, Tier 2 → action P/evals-specify, Tier 3 → prose CDR."""
    seg_start = LEVELUP.read_text(encoding="utf-8").find("Phase 1b")
    seg = LEVELUP.read_text(encoding="utf-8")[seg_start:seg_start + 2000]
    assert "/architect-specify" in seg and "ADR" in seg
    assert "/evals-specify" in seg
    assert "Tier 3" in seg and "CDR" in seg


def test_learn_reuses_phase6_verbatim():
    """factory-learn Git signals reuse change-init Phase 6 grep shapes verbatim."""
    text = LEARN.read_text(encoding="utf-8")
    assert "git log --grep='^Revert \"'" in text, "revert grep must match Phase 6 verbatim"
    assert "git log --grep='revert' -i" in text
    assert "fix(?!ed)?\\b" in text and "hotfix" in text, "fix-chain subject shapes must match Phase 6"


def test_learn_recurrence_evidence_stays_in_repo():
    """Recurrence evidence lives in adlc-team-skills; destination does not move it."""
    text = LEARN.read_text(encoding="utf-8")
    assert "adlc-team-skills" in text
    assert "same pass + same check item" in text
    assert "review-findings" in text, "run scratchpads must be a recurrence source"


def test_learn_memory_contract_unchanged():
    """memory.jsonl contract (weights, use counts, auto-archive) is preserved."""
    text = LEARN.read_text(encoding="utf-8")
    assert "memory.jsonl" in text
    assert "weights" in text and "use counts" in text
    assert "automatically archived" in text


def test_mechanical_checkable_never_prose_default():
    """End-to-end guard: none of the three skills default mechanical issues to prose CDRs."""
    for path in (REVIEW, LEVELUP, LEARN):
        text = path.read_text(encoding="utf-8")
        assert re.search(r"never.*prose CDR|prose CDR.*never|must never.*default|no prose CDR",
                         text, re.IGNORECASE), (
            f"{path.name} must forbid prose-CDR default for mechanical issues"
        )
