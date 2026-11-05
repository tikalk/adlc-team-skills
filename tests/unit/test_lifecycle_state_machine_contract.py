"""Lifecycle state machine contract (adlc-workspace#80, G1).

tracker-integration §2 is the one authoritative lifecycle state machine for
`autonomous` and `supervised` issues:

- seven exclusive states, `parked` among them; `done`/`cancelled` terminal
- `resume` documented as a transient trigger label, not a state
- a transition table naming every edge, its trigger, its owner and how it
  differs by dispatch
- bare label names: no `factory-stage:` prefix anywhere under skills/factory
"""
import re
from pathlib import Path

ROOT = Path(__file__).parent.parent.parent

FACTORY_DIR = ROOT / "skills/factory"
TRACKER_INTEGRATION = FACTORY_DIR / "factory-runbook/references/tracker-integration.md"
TEMPLATE = FACTORY_DIR / "factory-runbook/references/issues-provider.yml"

STATES = ["intent", "spec-gated", "executing", "parked", "validation", "done", "cancelled"]

# (from, to) — "(none)" is a new issue, "any non-terminal" the cancel edge.
EDGES = [
    ("(none)", "intent"),
    ("intent", "spec-gated"),
    ("intent", "cancelled"),
    ("spec-gated", "executing"),
    ("executing", "spec-gated"),
    ("executing", "parked"),
    ("parked", "executing"),
    ("executing", "validation"),
    ("validation", "done"),
    ("any non-terminal", "cancelled"),
]


def _section(text, start_heading, end_prefix):
    start = text.index(start_heading)
    end = text.find(end_prefix, start + len(start_heading))
    return text[start:end if end != -1 else len(text)]


def _label_gate():
    text = TRACKER_INTEGRATION.read_text(encoding="utf-8")
    return _section(text, "### 2. Label Gate", "\n### 3.")


def _op9():
    text = TRACKER_INTEGRATION.read_text(encoding="utf-8")
    return _section(text, "### Operation 9", "\n### Operation 10")


def _transition_rows():
    """Return {(from, to): [cells]} for the §2 transition table."""
    rows = {}
    for line in _label_gate().splitlines():
        if not line.startswith("|") or set(line) <= set("|- "):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        edge = next((c for c in cells if "→" in c), None)
        if edge is None:
            continue
        left, right = (s.replace("`", "").strip() for s in edge.split("→", 1))
        rows[(left, right)] = cells
    return rows


def _header_cells():
    for line in _label_gate().splitlines():
        if line.startswith("|") and "Edge" in line:
            return [c.strip().lower() for c in line.strip().strip("|").split("|")]
    raise AssertionError("§2 must carry a transition table with an Edge column")


def test_lifecycle_dimension_lists_all_states():
    line = next(l for l in _label_gate().splitlines() if "**Lifecycle-stage**" in l)
    found = re.findall(r"`([a-z-]+)`", line)
    assert found == STATES, f"lifecycle states must be {STATES}, got {found}"


def test_terminal_states_named():
    gate = _label_gate().lower()
    assert "terminal" in gate and "`done`" in gate and "`cancelled`" in gate


def test_resume_is_a_trigger_not_a_state():
    gate = _label_gate()
    lifecycle = next(l for l in gate.splitlines() if "**Lifecycle-stage**" in l)
    assert "`resume`" not in lifecycle, "`resume` must not be a lifecycle state"
    resume_lines = [l for l in gate.splitlines() if "`resume`" in l and "**Lifecycle-stage**" not in l]
    assert resume_lines, "§2 must document the `resume` label"
    joined = " ".join(resume_lines).lower()
    assert "trigger" in joined and "removes" in joined, (
        "`resume` must be documented as a trigger the runtime removes"
    )


def test_transition_table_has_trigger_owner_dispatch_columns():
    header = _header_cells()
    for col in ("edge", "trigger", "owner", "dispatch"):
        assert any(col in h for h in header), f"transition table needs a {col!r} column"


def test_transition_table_covers_every_edge_with_an_owner():
    rows = _transition_rows()
    owner_idx = next(i for i, h in enumerate(_header_cells()) if "owner" in h)
    trigger_idx = next(i for i, h in enumerate(_header_cells()) if "trigger" in h)
    for edge in EDGES:
        assert edge in rows, f"transition table missing edge {edge[0]} → {edge[1]}"
        cells = rows[edge]
        assert cells[owner_idx] not in ("", "—", "-"), f"edge {edge} has no owner"
        assert cells[trigger_idx] not in ("", "—", "-"), f"edge {edge} has no trigger"
    extra = set(rows) - set(EDGES)
    assert not extra, f"transition table has undocumented edges: {sorted(extra)}"


def test_parked_edges_are_supervised_only():
    rows = _transition_rows()
    dispatch_idx = next(i for i, h in enumerate(_header_cells()) if "dispatch" in h)
    for edge in (("executing", "parked"), ("parked", "executing")):
        assert "supervised only" in rows[edge][dispatch_idx].lower(), (
            f"edge {edge} must state it is reachable by supervised runs only"
        )


def test_resume_edge_names_the_resume_trigger():
    rows = _transition_rows()
    assert "`resume`" in " ".join(rows[("parked", "executing")])


def test_op9_uses_bare_lifecycle_names():
    op9 = _op9()
    assert "factory-stage:" not in op9
    assert '--add-label "<target>"' in op9 and '--remove-label "<others>"' in op9
    assert '--label "<target>"' in op9 and '--unlabel "<others>"' in op9


def test_no_factory_stage_prefix_under_skills_factory():
    hits = [
        str(p.relative_to(ROOT))
        for p in FACTORY_DIR.rglob("*")
        if p.is_file() and "factory-stage:" in p.read_text(encoding="utf-8", errors="ignore")
    ]
    assert not hits, f"`factory-stage:` must not appear under skills/factory: {hits}"


def test_template_lists_parked_and_resume():
    content = TEMPLATE.read_text(encoding="utf-8")
    vocab = _section(content, "factory label vocabulary", "# --- Optional")
    for name in STATES:
        assert name in vocab, f"template vocabulary must list {name!r}"
    assert "resume" in vocab, "template vocabulary must list the `resume` trigger"
