"""Contract tests for factory-mission remote lane (remote:coder).

Verifies lanes.md documents the remote lane + scripts behave:
naming gate, dirty-tree gate, usage errors, zero secret literals.
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


def test_scripts_exist_syntax_clean_and_executable():
    for p in (ENV_SYNC, TEARDOWN):
        assert p.exists(), f"missing {p.name}"
        r = subprocess.run(["bash", "-n", str(p)], capture_output=True, text=True)
        assert r.returncode == 0, f"{p.name} syntax: {r.stderr}"
    for p in (ENV_SYNC, TEARDOWN):
        mode = oct(p.stat().st_mode & 0o777)
        assert mode == "0o755", f"{p.name} mode {mode}, want 0o755"


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


def test_env_sync_requires_coder_cli(tmp_path):
    brief = tmp_path / "brief.md"
    brief.write_text("# brief\n")
    workdir = tmp_path / "clean"
    workdir.mkdir()
    r = subprocess.run(["bash", str(ENV_SYNC), "ws", "url", "br", str(brief)],
                       capture_output=True, text=True,
                       env=_env_without_coder(tmp_path), cwd=workdir)
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


def test_env_sync_dirty_gate(sandbox_project):
    p = ENV_SYNC
    (sandbox_project / "README.md").write_text("dirty-test\n")
    r = subprocess.run(["bash", str(p), "dummy", "dummy", "dummy", "dummy"],
                       capture_output=True, text=True, cwd=sandbox_project)
    assert r.returncode == 2
    assert "dirty" in (r.stdout + r.stderr).lower()


def test_env_sync_rejects_missing_brief(tmp_path):
    env = dict(os.environ)
    env["PATH"] = str(_fake_coder(tmp_path)) + os.pathsep + env["PATH"]
    workdir = tmp_path / "clean"
    workdir.mkdir()
    r = subprocess.run(["bash", str(ENV_SYNC), "ws", "url", "br", "/nonexistent/brief.md"],
                       capture_output=True, text=True, env=env, cwd=workdir)
    assert r.returncode == 2
    assert "brief" in (r.stdout + r.stderr).lower()


def test_env_sync_usage_error():
    p = ENV_SYNC
    r = subprocess.run(["bash", str(p)], capture_output=True, text=True)
    assert r.returncode != 0


def test_env_sync_no_coder_scp():
    text = ENV_SYNC.read_text()
    assert "coder scp" not in text
    assert 'cat > ' in text


def test_env_sync_brief_path():
    text = ENV_SYNC.read_text()
    assert ".adlc/workflows/runs/" in text


def test_zero_secret_literals():
    text = "".join(p.read_text() for p in SCRIPTS.glob("remote-coder-*.sh"))
    assert not re.search(r"glpat-|ghp_|xoxb-|sk-|CODER_TOKEN=.|GITLAB_TOKEN=.", text)


def test_lanes_developer_owned_tab():
    text = LANES.read_text()
    assert "NEVER opens a herdr tab" in text
    assert "developer owns their tab" in text or "OWN herdr tab" in text


def test_lanes_dispatch_matrix():
    text = LANES.read_text()
    assert "interactive" in text and "remote:coder" in text
    assert "local CLI session, as today" in text


def test_lanes_herdr_prereqs():
    text = LANES.read_text()
    assert "herdr" in text.lower() and "coder.<workspace>.main" in text


def test_skill_issue_plus_provider():
    skill = (ROOT / "skills/factory/factory-mission/SKILL.md").read_text()
    assert "--provider coder" in skill
    assert "never opens tabs" in skill
