"""Terminal lifecycle contract (adlc-workspace#82, G3).

A closed issue always ends with one terminal lifecycle label:

- merged with `Closes #` → `done`; closed without a merge → `cancelled`
- factory-review babysit and factory-orchestrator wrap-up set it through the
  Set Lifecycle step; the lane close Sensor covers closes outside the factory
- factory-setup Mode 3 verifies every lifecycle label exists with a
  description, offers to create `cancelled` and fill descriptions only on
  confirmation, and removes a stray `factory-stage:` label only on explicit
  confirmation
"""
from pathlib import Path

ROOT = Path(__file__).parent.parent.parent
FACTORY = ROOT / "skills/factory"
REVIEW = FACTORY / "factory-review/SKILL.md"
ORCHESTRATOR = FACTORY / "factory-orchestrator/SKILL.md"
MODE3 = FACTORY / "factory-setup/references/mode-configured.md"
TRACKER = FACTORY / "factory-runbook/references/tracker-integration.md"

LIFECYCLE = ["intent", "spec-gated", "executing", "parked", "validation", "done", "cancelled"]


def _section(text, start, end):
    i = text.index(start)
    j = text.find(end, i + len(start))
    return text[i:j if j != -1 else len(text)]


def test_review_babysit_lands_done_on_merge_and_cancelled_on_unmerged_close():
    babysit = _section(REVIEW.read_text(encoding="utf-8"), "### 4. Agent Comment-Addressing", "### 5.")
    assert "Set Lifecycle" in babysit
    assert "`done`" in babysit and "`cancelled`" in babysit


def test_orchestrator_completion_covers_both_terminal_states():
    completion = _section(ORCHESTRATOR.read_text(encoding="utf-8"), "### 6. Completion", "\n## ")
    assert "Set Lifecycle" in completion
    assert "`done`" in completion and "`cancelled`" in completion
    assert "without a merge" in completion


def test_mode3_checks_every_lifecycle_label_has_a_description():
    text = MODE3.read_text(encoding="utf-8")
    assert "description" in text.lower()
    for name in LIFECYCLE:
        assert f"`{name}`" in text, f"Mode 3 must give a description for `{name}`"


def test_mode3_fills_descriptions_only_on_confirmation():
    text = MODE3.read_text(encoding="utf-8").lower()
    assert "label edit" in text, "Mode 3 must offer to fill a missing description"
    assert "confirm" in text


def test_mode3_removes_a_stray_prefixed_label_only_on_explicit_confirmation():
    # Named without the colon: no skill text may carry the retired prefix form.
    text = MODE3.read_text(encoding="utf-8")
    stray = next(l for l in text.splitlines() if "retired `factory-stage` prefix" in l)
    assert "explicit" in stray.lower() and "confirm" in stray.lower()


def test_transition_table_names_the_lane_close_sensor():
    text = TRACKER.read_text(encoding="utf-8")
    rows = [l for l in text.splitlines() if l.startswith("| 9 ") or l.startswith("| 10 ")]
    assert len(rows) == 2
    for row in rows:
        assert "close Sensor" in row, f"edge row must name the lane close Sensor: {row}"
