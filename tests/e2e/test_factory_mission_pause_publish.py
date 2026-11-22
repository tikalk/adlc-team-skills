"""Pause publish reuses the run's single draft MR (adlc-workspace#151, AC2).

A pause after code changes produces exactly one WIP commit of the mission
code paths (`wip(<run_id>): paused at <phase> for a question`), pushes only
the run branch, and opens-or-reuses the run's single draft MR — the same
MR the converge publish reuses. The fixture repo stands in for the target
repo; the run branch comes from the runbook's `run-branch.sh --kind code`
(the runbook publish procedure), the WIP commit stages the mission code
paths directly (skill sources sit outside the ADR-433 lifecycle allowlist
`commit-step.sh` enforces), and the push + MR reuse go through
`open-mr.sh --kind code`.

Requires a local `origin` remote: skipped without working bash+git.
"""

import subprocess
from pathlib import Path

import pytest

pytestmark = pytest.mark.requires_bash

ROOT = Path(__file__).parent.parent.parent
RUNBOOK = ROOT / "skills/factory/factory-runbook/scripts/bash"


def _sh(cwd: Path, *args: str, env: dict | None = None) -> subprocess.CompletedProcess:
    import os

    merged = dict(os.environ)
    if env:
        merged.update(env)
    return subprocess.run(
        ["bash", *args], cwd=cwd, capture_output=True, text=True, env=merged
    )


def test_pause_publish_produces_one_wip_commit(tmp_path):
    if not (RUNBOOK / "run-branch.sh").exists():
        pytest.skip("runbook helpers not present")
    work = tmp_path / "code"
    origin = tmp_path / "origin.git"
    subprocess.run(["git", "init", "--bare", "-q", str(origin)], check=True)
    subprocess.run(["git", "init", "-q", "-b", "main", str(work)], check=True)
    subprocess.run(
        ["git", "config", "user.email", "t@t.t"], cwd=work, check=True
    )
    subprocess.run(["git", "config", "user.name", "t"], cwd=work, check=True)
    (work / "f.txt").write_text("base\n")
    subprocess.run(["git", "add", "."], cwd=work, check=True)
    subprocess.run(["git", "commit", "-qm", "base"], cwd=work, check=True)
    subprocess.run(
        ["git", "remote", "add", "origin", str(origin)], cwd=work, check=True
    )
    subprocess.run(["git", "push", "-q", "origin", "main"], cwd=work, check=True)

    run_id = "pause-pub-1"
    env = {"ADLC_RUN_ID": run_id, "ADLC_ISSUE_REF": "g/p#151"}
    r = _sh(work, str(RUNBOOK / "run-branch.sh"), "--kind", "code", env=env)
    assert r.returncode == 0, r.stderr
    assert "factory/mission/p-151" in r.stdout

    (work / "skills/factory/factory-mission/SKILL.md").parent.mkdir(parents=True)
    (work / "skills/factory/factory-mission/SKILL.md").write_text(
        "ask through ADLC_STEP_QUESTION\n"
    )
    # Pause publish commits the mission code paths directly: skill sources
    # sit outside the ADR-433 lifecycle write allowlist that commit-step.sh
    # enforces, so the orchestrator stages the mission paths itself.
    r = _sh(
        work,
        "git",
        "add",
        "--",
        "skills/factory/factory-mission/SKILL.md",
        env=env,
    )
    assert r.returncode == 0, r.stderr
    r = _sh(
        work,
        "git",
        "-c",
        "user.email=t@t.t",
        "-c",
        "user.name=t",
        "commit",
        "-qm",
        f"wip({run_id}): paused at execute for a question",
        env=env,
    )
    log = subprocess.run(
        ["git", "log", "--format=%s", "-1"], cwd=work, capture_output=True, text=True
    ).stdout.strip()
    assert log.startswith(f"wip({run_id})"), log
