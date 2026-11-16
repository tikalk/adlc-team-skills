"""PR + agent-run review route in factory-learn (user request: review a PR and
its agent run, suggest CDRs to the team).

Pins the contract added to factory-learn/SKILL.md: the PR + run route takes
both evidence sources (exact-head review verdict + run record), routes each
candidate through the correction-elimination ladder before proposing a prose
CDR, and gates publishing on the same human clarify gate team-levelup uses.
"""

from pathlib import Path

REPO = Path(__file__).parent.parent.parent
SKILL = REPO / "skills" / "factory" / "factory-learn" / "SKILL.md"
TEMPLATE = REPO / "skills" / "team" / "templates" / "cdr-draft-template.md"


def _read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def _route_section() -> str:
    text = _read(SKILL)
    assert "PR + Agent-Run Review Route" in text, "factory-learn has no PR + run route"
    section = text.split("PR + Agent-Run Review Route", 1)[1]
    cut = len(section)
    for marker in ("\n### ", "\n## "):
        idx = section.find(marker)
        if idx != -1:
            cut = min(cut, idx)
    return section[:cut]


def test_route_takes_pr_and_run_inputs():
    section = _route_section()
    assert "--pr" in section and "--run" in section, "route must take PR id + run id"


def test_route_requires_both_evidence_sources():
    section = _route_section()
    for token in ("head=<sha>", "outcome=", ".adlc/workflows/runs/"):
        assert token in section, f"route must pin evidence source {token!r}"


def test_route_candidates_cite_both_sources():
    section = _route_section()
    assert "PR link" in section and "run ID" in section, (
        "every candidate must cite the PR and the run"
    )


def test_route_runs_ladder_before_prose_cdr():
    section = _route_section()
    assert "correction-elimination ladder" in section or "ADR-494" in section
    assert "Promote to" in section, "Tier 2 must name the promote-to-check vehicle"
    text = _read(SKILL)
    assert "Tier 3" in text or "judgment" in text.lower(), (
        "prose CDRs must be scoped to judgment-only"
    )


def test_route_gates_publish_on_clarify():
    section = _route_section()
    assert "clarify" in section, "nothing publishes without the human gate"
    assert "team-levelup" in section, "gate reuses the team-levelup choice contract"


def test_route_reuses_shared_cdr_template():
    text = _read(SKILL)
    assert "skills/team/templates/cdr-draft-template.md" in text
    assert TEMPLATE.exists(), "shared CDR template missing"
