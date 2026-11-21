"""Contract test for the computer-use `browser` verify lane.

The `verify` step dispatches a `browser` lane run only when the brief's
Success Criteria name user-visible behavior; the lane produces screenshots
plus a trimmed (<=60s) recording published as an artifact-ref on the
comment bus. Without tooling it falls back to suite-only with honest
`unverified` findings on behavioral criteria — never faked evidence.
"""

from pathlib import Path

REPO = Path(__file__).parent.parent.parent
LANES = REPO / "skills" / "factory" / "factory-runbook" / "references" / "lanes.md"
SKILL = REPO / "skills" / "mission" / "mission-brief" / "SKILL.md"
TRIM_SH = REPO / "skills" / "mission" / "mission-brief" / "scripts" / "bash" / "trim-evidence.sh"
TRIM_PS = REPO / "skills" / "mission" / "mission-brief" / "scripts" / "powershell" / "trim-evidence.ps1"


def _read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def test_lanes_defines_browser_lane():
    """lanes.md defines a `browser` lane kind in the lane kinds table."""
    text = _read(LANES)
    assert "`browser`" in text, "lanes.md must define a `browser` lane kind"


def test_lanes_browser_degradation_ladder():
    """Degradation ladder is browser -> agent -> inline with tooling-absent disclosure."""
    text = _read(LANES)
    assert "browser" in text and "agent" in text and "inline" in text
    ladder = text.split("## Degradation ladder", 1)[1].split("## ", 1)[0]
    assert "browser" in ladder, "degradation ladder must name the browser lane"
    assert "agent" in ladder
    lowered = ladder.lower()
    assert "disclos" in lowered, "degradation must be disclosed"


def test_verify_dispatches_browser_lane_for_user_visible_behavior():
    """mission-brief verify dispatches the browser lane only for user-visible criteria."""
    skill = _read(SKILL)
    verify = skill.split("## Step contract", 1)[0]
    assert "browser" in verify, "verify section must dispatch the browser lane"
    lowered = verify.lower()
    assert "user-visible" in lowered, "browser lane must trigger on user-visible behavior"
    assert "disclos" in lowered, "a skip must be disclosed, not silent"


def test_trim_evidence_scripts_exist_with_60s_target():
    """trim-evidence.sh and its .ps1 twin exist and target <=60s."""
    assert TRIM_SH.exists(), f"missing {TRIM_SH.relative_to(REPO)}"
    assert TRIM_PS.exists(), f"missing powershell twin {TRIM_PS.relative_to(REPO)}"
    for script in (TRIM_SH, TRIM_PS):
        text = _read(script)
        assert "60" in text, f"{script.name} must name the 60s target"
        assert "ffmpeg" in text.lower() or "trim" in text.lower(), (
            f"{script.name} must trim (ffmpeg/dead-zone)"
        )


def test_no_tooling_fallback_is_suite_only_with_unverified():
    """Without browser tooling: suite-only + `unverified` on behavioral criteria, never faked."""
    skill = _read(SKILL)
    verify = skill.split("## Step contract", 1)[0]
    lowered = verify.lower()
    assert "unverified" in lowered, "fallback must mark behavioral criteria `unverified`"
    assert "suite" in lowered, "fallback must stay suite-only"


def test_risk_never_overrides_outcome():
    """Browser-lane evidence informs converge; risk never changes the verdict."""
    skill = _read(SKILL)
    assert "outcome=" in skill or "never overrides" in skill.lower(), (
        "browser-lane evidence must not override the converge outcome"
    )
