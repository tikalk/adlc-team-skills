"""Contract tests for factory-mission remote lane (remote:coder).

Verifies lanes.md documents the remote lane + scripts behave:
naming gate, dirty-tree gate, usage errors, zero secret literals.
"""
import re
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).parent.parent.parent
LANES = ROOT / "skills/factory/factory-mission/references/lanes.md"
SCRIPTS = ROOT / "skills/factory/factory-mission/scripts/bash"


def test_lanes_documents_remote_lane():
    text = LANES.read_text()
    assert "`remote:<provider>`" in text
    assert "--provider" in text
    assert "known: `argo`, `coder`" in text


def test_lanes_degradation_ladder():
    text = LANES.read_text()
    assert "remote:<provider>" in text and "agent" in text and "inline" in text


def test_scripts_exist_and_syntax_clean():
    for name in ("remote-coder-env-sync.sh", "remote-coder-teardown.sh"):
        p = SCRIPTS / name
        assert p.exists(), f"missing {name}"
        r = subprocess.run(["bash", "-n", str(p)], capture_output=True, text=True)
        assert r.returncode == 0, f"{name} syntax: {r.stderr}"


def test_teardown_refuses_non_lane_name():
    p = SCRIPTS / "remote-coder-teardown.sh"
    r = subprocess.run(["bash", str(p), "some-random-ws", "--yes"],
                       capture_output=True, text=True)
    assert r.returncode == 3
    assert "REFUSE" in r.stdout + r.stderr


def test_teardown_missing_workspace_noop():
    p = SCRIPTS / "remote-coder-teardown.sh"
    r = subprocess.run(["bash", str(p), "coder-mission-99999"],
                       capture_output=True, text=True)
    assert r.returncode == 0
    assert "nothing to delete" in r.stdout + r.stderr


def test_env_sync_dirty_gate(sandbox_project):
    p = SCRIPTS / "remote-coder-env-sync.sh"
    (sandbox_project / "README.md").write_text("dirty-test\n")
    r = subprocess.run(["bash", str(p), "dummy", "dummy", "dummy", "dummy"],
                       capture_output=True, text=True, cwd=sandbox_project)
    assert r.returncode == 2
    assert "dirty" in (r.stdout + r.stderr).lower()


def test_env_sync_usage_error():
    p = SCRIPTS / "remote-coder-env-sync.sh"
    r = subprocess.run(["bash", str(p)], capture_output=True, text=True)
    assert r.returncode != 0


def test_zero_secret_literals():
    text = "".join(p.read_text() for p in SCRIPTS.glob("remote-coder-*.sh"))
    assert not re.search(r"glpat-|ghp_|xoxb-|sk-|CODER_TOKEN=.|GITLAB_TOKEN=.", text)
