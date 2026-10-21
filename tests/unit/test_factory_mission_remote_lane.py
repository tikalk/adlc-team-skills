"""Contract tests for factory-mission remote lane (remote:coder).

Verifies lanes.md documents the remote lane and that env setup is delegated
to the adlc-cli provider transport (ADR-007 / PDR-010), not skill-side scripts.
"""
import os
import re
import stat
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).parent.parent.parent
LANES = ROOT / "skills/factory/factory-mission/references/lanes.md"
SCRIPTS = ROOT / "skills/factory/factory-mission/scripts/bash"
ENV_SYNC = SCRIPTS / "remote-coder-env-sync.sh"
TEARDOWN = SCRIPTS / "remote-coder-teardown.sh"


def test_lanes_documents_remote_lane():
    text = LANES.read_text()
    assert "`remote:<provider>`" in text
    assert "--provider" in text
    assert "known: `coder`" in text
    assert "argo" not in text


def test_lanes_no_agent_fallback():
    text = LANES.read_text()
    assert "NEVER degrades to `agent`" in text
    assert "halt" in text.lower()


def test_lanes_degradation_ladder():
    text = LANES.read_text()
    assert "remote:<provider>" in text and "HALT" in text


def test_env_sync_script_removed():
    assert not ENV_SYNC.exists(), (
        "remote-coder-env-sync.sh must be deleted: env setup is owned by "
        "adlc-cli --provider coder (ADR-007)"
    )


def test_teardown_script_syntax_clean_and_executable():
    assert TEARDOWN.exists(), f"missing {TEARDOWN.name}"
    r = subprocess.run(["bash", "-n", str(TEARDOWN)], capture_output=True, text=True)
    assert r.returncode == 0, f"{TEARDOWN.name} syntax: {r.stderr}"
    mode = oct(TEARDOWN.stat().st_mode & 0o777)
    assert mode == "0o755", f"{TEARDOWN.name} mode {mode}, want 0o755"


def test_lanes_delegates_setup_to_adlc_cli():
    text = LANES.read_text()
    assert "adlc-cli workspace setup" in text
    assert "--provider coder" in text
    assert "`.adlc/workspace.yml`" in text
    assert ".adlc/workspaces/" in text


def test_lanes_has_no_skill_side_env_sync():
    text = LANES.read_text()
    assert "Sync env over `coder ssh`" not in text
    assert "adlc-cli skills add" not in text
    assert "coder scp" not in text
    assert "NEVER carries its own env bootstrap" in text


def test_lanes_transport_failure_halts_without_fallback():
    text = LANES.read_text()
    assert "not implemented: live coder transport" in text
    assert "do not fall back to a script" in text.lower()


def test_lanes_secret_contract():
    text = LANES.read_text()
    assert "${VAR}" in text
    assert "fail-fast" in text
    assert "redacted outbound" in text
    assert "location-free" in text


def test_lanes_per_mission_workspace_name():
    text = LANES.read_text()
    assert "name: ${WORKSPACE_NAME}" in text
    assert "WORKSPACE_NAME=<repo>-mission-<issue>" in text
    assert "never invents a fallback name" in text
    assert "name_var" in text


def _fake_coder(tmp_path, behavior="missing"):
    bindir = tmp_path / "fakebin"
    bindir.mkdir(exist_ok=True)
    fake = bindir / "coder"
    if behavior == "missing":
        fake.write_text("#!/usr/bin/env bash\necho 'fake coder: no such workspace' >&2\nexit 1\n")
    else:
        fake.write_text("#!/usr/bin/env bash\necho 'fake coder: workspace exists'\nexit 0\n")
    fake.chmod(0o755)
    return bindir


def _env_without_coder(tmp_path):
    env = dict(os.environ)
    env["PATH"] = str(tmp_path) + os.pathsep + "/usr/bin" + os.pathsep + "/bin"
    return env


def test_teardown_requires_coder_cli(tmp_path):
    r = subprocess.run(["bash", str(TEARDOWN), "coder-mission-1"],
                       capture_output=True, text=True,
                       env=_env_without_coder(tmp_path))
    assert r.returncode == 127


def test_teardown_refuses_non_lane_name(tmp_path):
    env = dict(os.environ)
    env["PATH"] = str(_fake_coder(tmp_path)) + os.pathsep + env["PATH"]
    r = subprocess.run(["bash", str(TEARDOWN), "some-random-ws", "--yes"],
                       capture_output=True, text=True, env=env)
    assert r.returncode == 3
    assert "REFUSE" in r.stdout + r.stderr


def test_teardown_missing_workspace_noop(tmp_path):
    env = dict(os.environ)
    env["PATH"] = str(_fake_coder(tmp_path, "missing")) + os.pathsep + env["PATH"]
    r = subprocess.run(["bash", str(TEARDOWN), "coder-mission-99999"],
                       capture_output=True, text=True, env=env)
    assert r.returncode == 0
    assert "nothing to delete" in r.stdout + r.stderr


def test_teardown_finds_workspace_via_show(tmp_path):
    env = dict(os.environ)
    env["PATH"] = str(_fake_coder(tmp_path, "exists")) + os.pathsep + env["PATH"]
    r = subprocess.run(["bash", str(TEARDOWN), "coder-mission-1"],
                       capture_output=True, text=True, env=env)
    assert r.returncode == 0
    assert "Teardown gate" in r.stdout + r.stderr


def test_zero_secret_literals():
    text = TEARDOWN.read_text()
    assert not re.search(r"glpat-|ghp_|xoxb-|sk-|CODER_TOKEN=.|GITLAB_TOKEN=.", text)


def test_lanes_developer_owned_tab():
    text = LANES.read_text()
    assert "NEVER opens tabs" in text
    assert "developer owns their tab" in text or "OWN tab" in text


def test_lanes_dispatch_matrix():
    text = LANES.read_text()
    assert "interactive" in text and "remote:coder" in text
    assert "local CLI session, as today" in text


def test_lanes_attach_order():
    text = LANES.read_text()
    ssh_pos = text.find("coder ssh <workspace>` (primary)")
    herdr_pos = text.find("herdr --remote coder.<workspace>.main` fallback")
    assert ssh_pos != -1 and herdr_pos != -1 and ssh_pos < herdr_pos
    assert 'opencode --prompt' in text


def test_skill_issue_plus_provider():
    skill = (ROOT / "skills/factory/factory-mission/SKILL.md").read_text()
    assert "--provider coder" in skill
    assert "never opens tabs" in skill
