"""set-lifecycle: tracker-integration Operation 9 as one self-checking command (SF-SKILL-04).

Evidence: octopus-next#1507 (supervised, run adlc-mission-octopus-next-xlmzw,
2026-11-09) still carries `executing` although its code MR !1302 is open and
was reviewed — the move to `validation` existed only as a sentence in
factory-mission, and nothing ran it or checked it afterwards.

Both twins run the same cases against the fake `glab` in
tests/fixtures/fake-tracker (the pwsh rows are skipped where pwsh is absent;
CI installs it).
"""
import json
import os
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).parent.parent.parent
SCRIPTS = ROOT / "skills/factory/factory-runbook/scripts"
FAKE = ROOT / "tests/fixtures/fake-tracker"
MISSION = ROOT / "skills/factory/factory-mission/SKILL.md"
TRACKER = ROOT / "skills/factory/factory-runbook/references/tracker-integration.md"
ISSUE = "tikalk/engineering/octopus-next#1507"

TWINS = [
    pytest.param(["bash", str(SCRIPTS / "bash/set-lifecycle.sh")], id="bash",
                 marks=pytest.mark.requires_bash),
    pytest.param(["pwsh", "-NoProfile", "-File", str(SCRIPTS / "powershell/set-lifecycle.ps1")], id="pwsh",
                 marks=pytest.mark.skipif(shutil.which("pwsh") is None, reason="needs pwsh (CI runs it)")),
]

pytestmark = pytest.mark.skipif(shutil.which("node") is None, reason="needs node")


def run(cmd, tmp_path, labels, *args, env_extra=None, **knobs):
    (tmp_path / "labels.json").write_text(json.dumps(labels))
    env = {k: v for k, v in os.environ.items()
           if not k.startswith(("FAKE_", "ADLC_")) and k not in ("WORKFLOW_INPUTS", "ISSUE_PROVIDER")}
    env.update({"PATH": f"{FAKE}{os.pathsep}{env['PATH']}", "FAKE_TRACKER_DIR": str(tmp_path),
                "GITLAB_HOST": "gitlab.example.test"}, **knobs)
    env.update(env_extra or {})
    r = subprocess.run([*cmd, *args], capture_output=True, text=True, env=env, cwd=tmp_path)
    return r, json.loads((tmp_path / "labels.json").read_text())


def calls(tmp_path, method):
    log = tmp_path / "calls.log"
    return [l for l in log.read_text().splitlines() if l.startswith(method)] if log.exists() else []


@pytest.mark.parametrize("cmd", TWINS)
def test_executing_moves_to_validation_in_one_call(cmd, tmp_path):
    r, labels = run(cmd, tmp_path, ["Backlog", "executing", "supervised"], "--issue", ISSUE, "--to", "validation")
    assert r.returncode == 0, r.stderr
    assert sorted(labels) == ["Backlog", "supervised", "validation"]
    assert len(calls(tmp_path, "PUT")) == 1
    assert "moved to 'validation' (removed: executing)" in r.stdout


@pytest.mark.parametrize("cmd", TWINS)
def test_a_stray_pair_is_cleaned_and_resume_is_never_touched(cmd, tmp_path):
    r, labels = run(cmd, tmp_path, ["intent", "parked", "resume"], "--issue", ISSUE, "--to", "executing")
    assert r.returncode == 0, r.stderr
    assert sorted(labels) == ["executing", "resume"]


@pytest.mark.parametrize("cmd", TWINS)
def test_already_there_is_a_no_op(cmd, tmp_path):
    r, _ = run(cmd, tmp_path, ["validation"], "--issue", ISSUE, "--to", "validation")
    assert r.returncode == 0, r.stderr
    assert "already" in r.stdout
    assert calls(tmp_path, "PUT") == []


@pytest.mark.parametrize("cmd", TWINS)
def test_a_remove_that_did_not_happen_fails(cmd, tmp_path):
    # The tracker accepts the call but leaves `executing` (permission, label lock).
    r, labels = run(cmd, tmp_path, ["executing"], "--issue", ISSUE, "--to", "validation", FAKE_IGNORE_REMOVE="1")
    assert r.returncode == 1
    assert "executing,validation" in r.stderr and "never as done" in r.stderr


@pytest.mark.parametrize("cmd", TWINS)
def test_usage_errors_and_an_unreadable_tracker_exit_2(cmd, tmp_path):
    r, _ = run(cmd, tmp_path, [], "--issue", ISSUE, "--to", "review")
    assert r.returncode == 2 and "--to must be one of" in r.stderr
    r, _ = run(cmd, tmp_path, [], "--issue", "g/../x#1", "--to", "validation")
    assert r.returncode == 2
    r, _ = run(cmd, tmp_path, ["executing"], "--issue", ISSUE, "--to", "validation", FAKE_READ_FAIL="1")
    assert r.returncode == 2 and "cannot read" in r.stderr
    r, labels = run(cmd, tmp_path, ["executing"], "--issue", ISSUE, "--to", "validation", FAKE_REFUSE="1")
    assert r.returncode == 2 and "refused" in r.stderr
    assert labels == ["executing"]


@pytest.mark.parametrize("cmd", TWINS)
def test_the_issue_defaults_to_the_run_context(cmd, tmp_path):
    lane = {"WORKFLOW_INPUTS": json.dumps({"issue_ref": ISSUE, "run_id": "4335f623", "dispatch": "autonomous"})}
    r, labels = run(cmd, tmp_path, ["executing"], "--to", "validation", env_extra=lane)
    assert r.returncode == 0, r.stderr
    assert labels == ["validation"]
    r, _ = run(cmd, tmp_path, ["executing"], "--to", "validation")
    assert r.returncode == 2 and "--issue" in r.stderr


@pytest.mark.parametrize("cmd", TWINS)
def test_custom_label_names_are_refused_not_guessed(cmd, tmp_path):
    (tmp_path / ".adlc").mkdir()
    (tmp_path / ".adlc/issues-provider.yml").write_text("provider: gitlab\nlabels:\n  executing: running\n")
    r, labels = run(cmd, tmp_path, ["executing"], "--issue", ISSUE, "--to", "validation")
    assert r.returncode == 2 and "custom lifecycle label names" in r.stderr
    assert labels == ["executing"]


@pytest.mark.parametrize("cmd", TWINS)
def test_gitlab_never_sends_the_token_to_a_guessed_host(cmd, tmp_path):
    r, _ = run(cmd, tmp_path, ["executing"], "--issue", ISSUE, "--to", "validation", GITLAB_HOST="")
    assert r.returncode == 2 and "GITLAB_HOST" in r.stderr
    assert calls(tmp_path, "") == []


def _factory_run_section():
    text = MISSION.read_text(encoding="utf-8")
    start = text.index("## In a factory run")
    return text[start:text.index("## In a local session", start)]


def test_mission_runs_the_command_for_both_end_states():
    section = _factory_run_section()
    assert "set-lifecycle.sh --issue <issue ref> --to validation" in section
    assert "set-lifecycle.sh --issue <issue ref> --to spec-gated" in section
    assert "Exit 0 is the only success" in section


def test_operation_9_names_the_command():
    text = TRACKER.read_text(encoding="utf-8")
    op9 = text[text.index("### Operation 9"):text.index("### Operation 10")]
    assert "scripts/bash/set-lifecycle.sh --issue <group>/<project>#<iid> --to <state>" in op9
