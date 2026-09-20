"""Unit test for check_factory_init_matrix.py grader.

Verifies the grader produces correct pass/fail results for the
factory-init sweep coverage matrix output (PDR-072).
Follows the evals-implement Phase 2 closed-loop self-tuning pattern.
"""
import sys
from pathlib import Path

# Add graders dir to path so we can import the grader directly.
graders_dir = Path(__file__).parent.parent / "graders"
sys.path.insert(0, str(graders_dir))

from check_factory_init_matrix import get_assert


# ---------------------------------------------------------------------------
# Pass cases
# ---------------------------------------------------------------------------

PASS_MATRIX = """# Coverage Matrix: acme-payments

## Pivot: Area Coverage

| Area | Feature-Area | Sub-System | PDRs | ADRs | ChDRs | Code Evidence | Coverage |
|------|--------------|------------|------|------|-------|---------------|----------|
| payments | billing | payments | 3 | 1 | 4 | present (src/payments/) | 62% |
| users | core | users | 2 | 2 | 1 | present (src/users/) | 88% |
| notifications | — | — | 0 | 0 | 2 | partial (src/notify/) | 20% |

Unreconciled: notifications (no feature-area match).

## Relations

### PDR↔ADR
Coverage: 71% (5/7)
- Gap: PDR-003 has no supporting ADR [layer: product]
- Gap: ADR-012 has no product grounding [layer: architecture]

### PDR↔code
Coverage: 83% (5/6)
- Gap: PDR-005 decided but not implemented (src/billing/ absent) [layer: product]

### ADR↔code
Coverage: 75% (6/8)
- Gap: code pattern without ADR — `src/cache/redis.ts` client usage undocumented [layer: architecture]

### ChDR↔code
Coverage: 60% (3/5)
- Gap: ChDR-004 dense area with no ADR (src/payments/retry) [layer: change]
- Gap: ChDR-007 describes superseded code (src/legacy/queue no longer present) [layer: change]

## Drift vs 2026-09-12 sweep

- New gaps: ADR-012 ungrounded (was grounded — PDR-009 deprecated)
- Closed gaps: PDR-002 now implemented
- Regressed areas: payments 71% -> 62%
"""


def test_pass_full_matrix():
    """A complete matrix with pivot, four relations, tagged+cited gaps, and drift passes."""
    result = get_assert(PASS_MATRIX)
    assert result["pass"] is True
    assert result["score"] == 1.0


def test_pass_baseline_first_sweep():
    """First sweep uses a Baseline section instead of Drift — both are valid."""
    matrix = PASS_MATRIX.replace(
        "## Drift vs 2026-09-12 sweep",
        "## Baseline",
    )
    result = get_assert(matrix)
    assert result["pass"] is True
    assert result["score"] == 1.0


def test_pass_ascii_relation_arrows():
    """Relations written with ASCII '<->' instead of '↔' pass."""
    matrix = (
        PASS_MATRIX.replace("### PDR↔ADR", "### PDR<->ADR")
        .replace("### PDR↔code", "### PDR<->code")
        .replace("### ADR↔code", "### ADR<->code")
        .replace("### ChDR↔code", "### ChDR<->code")
    )
    result = get_assert(matrix)
    assert result["pass"] is True
    assert result["score"] == 1.0


# ---------------------------------------------------------------------------
# Fail cases
# ---------------------------------------------------------------------------

def test_fail_missing_relation():
    """Missing the ChDR↔code relation section fails."""
    matrix = PASS_MATRIX.replace("### ChDR↔code\nCoverage: 60% (3/5)\n", "")
    result = get_assert(matrix)
    assert result["pass"] is False
    assert result["score"] == 0.0
    assert "ChDR" in result["reason"]


def test_fail_pivot_missing_column():
    """Pivot header missing the ChDRs column fails."""
    matrix = PASS_MATRIX.replace(
        "| Area | Feature-Area | Sub-System | PDRs | ADRs | ChDRs | Code Evidence | Coverage |",
        "| Area | Feature-Area | Sub-System | PDRs | ADRs | Code Evidence | Coverage |",
    )
    result = get_assert(matrix)
    assert result["pass"] is False
    assert result["score"] == 0.0
    assert "pivot" in result["reason"].lower()


def test_fail_relation_missing_coverage():
    """A relation section without a 'Coverage: N%' line fails."""
    matrix = PASS_MATRIX.replace("Coverage: 71% (5/7)\n", "")
    result = get_assert(matrix)
    assert result["pass"] is False
    assert result["score"] == 0.0
    assert "coverage" in result["reason"].lower()


def test_fail_gap_without_layer_tag():
    """A gap line missing its [layer: ...] tag fails."""
    matrix = PASS_MATRIX.replace(
        "- Gap: PDR-003 has no supporting ADR [layer: product]",
        "- Gap: PDR-003 has no supporting ADR",
    )
    result = get_assert(matrix)
    assert result["pass"] is False
    assert result["score"] == 0.0
    assert "layer" in result["reason"].lower()


def test_fail_gap_without_citation():
    """A gap line with neither a record ID nor a file path citation fails."""
    matrix = PASS_MATRIX.replace(
        "- Gap: PDR-005 decided but not implemented (src/billing/ absent) [layer: product]",
        "- Gap: one product decision was decided but never implemented [layer: product]",
    )
    result = get_assert(matrix)
    assert result["pass"] is False
    assert result["score"] == 0.0
    assert "citation" in result["reason"].lower()


def test_fail_no_drift_or_baseline():
    """Neither a Drift nor a Baseline section fails."""
    matrix = PASS_MATRIX.replace(
        "## Drift vs 2026-09-12 sweep\n\n- New gaps: ADR-012 ungrounded (was grounded — PDR-009 deprecated)\n- Closed gaps: PDR-002 now implemented\n- Regressed areas: payments 71% -> 62%\n",
        "",
    )
    result = get_assert(matrix)
    assert result["pass"] is False
    assert result["score"] == 0.0
    assert "drift" in result["reason"].lower() or "baseline" in result["reason"].lower()


def test_fail_missing_pivot_heading():
    """Removing the Pivot section heading fails (pivot header row check unreachable)."""
    matrix = PASS_MATRIX.replace("## Pivot: Area Coverage\n", "")
    result = get_assert(matrix)
    assert result["pass"] is False
    assert result["score"] == 0.0
    assert "pivot" in result["reason"].lower()


def test_fail_missing_pivot_header_row():
    """A Pivot heading with no table header row fails."""
    matrix = PASS_MATRIX.replace(
        "| Area | Feature-Area | Sub-System | PDRs | ADRs | ChDRs | Code Evidence | Coverage |\n"
        "|------|--------------|------------|------|------|-------|---------------|----------|\n",
        "",
    )
    result = get_assert(matrix)
    assert result["pass"] is False
    assert result["score"] == 0.0
    assert "pivot" in result["reason"].lower()


def test_fail_adversarial_slash_citation():
    """A slash phrase like 'product/architecture teams' is not a path citation — must fail."""
    matrix = PASS_MATRIX.replace(
        "- Gap: code pattern without ADR — `src/cache/redis.ts` client usage undocumented [layer: architecture]",
        "- Gap: code pattern without ADR — product/architecture teams disagree about it [layer: architecture]",
    )
    result = get_assert(matrix)
    assert result["pass"] is False
    assert result["score"] == 0.0
    assert "citation" in result["reason"].lower()


def test_fail_adversarial_abbreviation_citation():
    """'e.g.' is not a filename citation — must fail."""
    matrix = PASS_MATRIX.replace(
        "- Gap: code pattern without ADR — `src/cache/redis.ts` client usage undocumented [layer: architecture]",
        "- Gap: code pattern without ADR — e.g. the auth caching decision was never documented [layer: architecture]",
    )
    result = get_assert(matrix)
    assert result["pass"] is False
    assert result["score"] == 0.0
    assert "citation" in result["reason"].lower()
