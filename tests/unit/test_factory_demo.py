"""factory-demo anchor mechanics (the walker contract).

Pins the walker contract: list-anchors emits demo/* anchors in file order, --from slices
at the named anchor, validate-runbook fails closed naming the anchor, and
dry-run changes nothing. Bash twins are canonical; PowerShell twins agree
(twin parity per test_script_layout.py only requires both exist).
"""

import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).parent.parent.parent
SKILL = ROOT / "skills/factory/factory-demo"
LIST = SKILL / "scripts/bash/list-anchors.sh"
VALIDATE = SKILL / "scripts/bash/validate-runbook.sh"

# First consumer: the M19 octopus-next runbook.
M19_RUNBOOK = Path("/Users/amir/git/tikalk/engineering/octopus-next/docs/adlc/training/factory-octopus-next-demo.md")

EXPECTED_M19_ORDER = [
    "demo/pre-flight",
    "demo/intent-gates",
    "demo/intent-records",
    "demo/follow-through",
    "demo/supervised-run",
    "demo/autonomous-run",
    "demo/review",
    "demo/merge-close",
    "demo/runbook",
]


def _run(script, *args):
    return subprocess.run(
        ["bash", str(script), *args],
        capture_output=True, text=True, timeout=30,
    )


def _anchors(*args):
    proc = _run(LIST, *args)
    assert proc.returncode == 0, f"list-anchors failed: {proc.stderr}"
    return [l for l in proc.stdout.splitlines() if l.strip()]


def _write_runbook(tmp_path, body):
    p = tmp_path / "runbook.md"
    p.write_text(body, encoding="utf-8")
    return p


def _section(anchor, say=True, do=True):
    lines = [f"### {anchor}", ""]
    if say:
        lines.append("**Say:** something.")
    if do:
        lines.append("**Do:** something.")
    lines += ["**Show:** something.", ""]
    return "\n".join(lines)


# ── SKILL.md presence ─────────────────────────────────────────────────────

def test_demo_skill_is_present_and_invocable():
    import yaml
    parts = (SKILL / "SKILL.md").read_text(encoding="utf-8").split("---", 2)
    assert len(parts) >= 3, "Malformed frontmatter"
    meta = yaml.safe_load(parts[1]) or {}
    assert meta.get("name") == "factory-demo"
    desc = meta.get("description") or ""
    assert desc.strip().startswith("Use when"), "description is trigger-only: must start with 'Use when'"
    body = parts[2]
    for heading in ("## Overview", "## When to Use", "## Core Process", "## Red Flags", "## Verification"):
        assert heading in body, f"missing heading {heading}"


# ── list-anchors: order ───────────────────────────────────────────────────

def test_list_anchors_m19_file_order():
    assert _anchors("--runbook", str(M19_RUNBOOK)) == EXPECTED_M19_ORDER


def test_list_anchors_json_shape():
    import json
    proc = _run(LIST, "--runbook", str(M19_RUNBOOK), "--json")
    assert proc.returncode == 0, proc.stderr
    data = json.loads(proc.stdout)
    assert [d["anchor"] for d in data] == EXPECTED_M19_ORDER
    assert all(isinstance(d["line"], int) and d["line"] > 0 for d in data)


def test_from_slices_at_named_anchor():
    got = _anchors("--runbook", str(M19_RUNBOOK), "--from", "demo/review")
    assert got == ["demo/review", "demo/merge-close", "demo/runbook"]


def test_from_first_anchor_returns_all():
    assert _anchors("--runbook", str(M19_RUNBOOK), "--from", "demo/pre-flight") == EXPECTED_M19_ORDER


def test_unknown_from_fails_closed_with_anchor_name():
    proc = _run(LIST, "--runbook", str(M19_RUNBOOK), "--from", "demo/nope")
    assert proc.returncode != 0
    assert "demo/nope" in proc.stderr


def test_missing_runbook_fails_closed():
    proc = _run(LIST, "--runbook", "/does/not/exist.md")
    assert proc.returncode != 0


def test_no_anchors_fails_closed(tmp_path):
    p = _write_runbook(tmp_path, "# Nothing here\n\nNo anchors.\n")
    proc = _run(LIST, "--runbook", str(p))
    assert proc.returncode != 0


# ── validate-runbook ──────────────────────────────────────────────────────

def test_validate_m19_runbook():
    proc = _run(VALIDATE, "--runbook", str(M19_RUNBOOK))
    assert proc.returncode == 0, proc.stderr
    assert "valid: 9 anchors" in proc.stdout


def test_validate_duplicate_anchor_fails_with_name(tmp_path):
    body = _section("demo/alpha") + _section("demo/alpha")
    proc = _run(VALIDATE, "--runbook", str(_write_runbook(tmp_path, body)))
    assert proc.returncode != 0
    assert "demo/alpha" in proc.stderr


def test_validate_missing_say_fails_with_name(tmp_path):
    body = _section("demo/alpha", say=False)
    proc = _run(VALIDATE, "--runbook", str(_write_runbook(tmp_path, body)))
    assert proc.returncode != 0
    assert "demo/alpha" in proc.stderr


def test_validate_missing_do_fails_with_name(tmp_path):
    body = _section("demo/alpha", do=False)
    proc = _run(VALIDATE, "--runbook", str(_write_runbook(tmp_path, body)))
    assert proc.returncode != 0
    assert "demo/alpha" in proc.stderr


def test_dry_run_changes_nothing(tmp_path):
    """list + validate are read-only: runbook byte-identical afterwards."""
    import shutil
    src = M19_RUNBOOK.read_bytes()
    work = tmp_path / "copy.md"
    shutil.copy(M19_RUNBOOK, work)
    _run(LIST, "--runbook", str(work))
    _run(LIST, "--runbook", str(work), "--from", "demo/review")
    _run(VALIDATE, "--runbook", str(work))
    assert work.read_bytes() == src
