"""PR #90 regressions, exercised against both helpers without network access."""

import json
import os
import shutil
import subprocess
from pathlib import Path

import pytest


ROOT = Path(__file__).resolve().parents[2]
SKILL = ROOT / "skills/tech-radar/tech-radar-boot/scripts"
TREE = ROOT / "tests/fixtures/radar-okf"
FALLBACK = ROOT / "tests/fixtures/radar-fallback.json"


@pytest.fixture(params=["bash", "pwsh"])
def radar(request):
    shell = request.param
    if shutil.which(shell) is None:
        pytest.skip(f"{shell} not installed")

    def run(*queries, json_output=True, options=(), env=None):
        environ = {k: v for k, v in os.environ.items() if not k.startswith("ADLC_RADAR_")}
        environ["ADLC_RADAR_REPO"] = str(TREE)
        for key, value in (env or {}).items():
            if value is None:
                environ.pop(key, None)
            else:
                environ[key] = str(value)
        if shell == "bash":
            command = ["bash", str(SKILL / "bash/radar-search.sh")]
            flags = ["--json"] if json_output else []
            flags += ["--" + key.lstrip("-").lower() if key.startswith("-") else key for key in options]
        else:
            command = ["pwsh", "-NoProfile", "-File", str(SKILL / "powershell/radar-search.ps1")]
            flags = ["-Json"] if json_output else []
            flags += list(options)
        result = subprocess.run(
            [*command, *queries, *flags], cwd=ROOT, env=environ,
            text=True, capture_output=True, timeout=30,
        )
        assert result.returncode == 0, result.stderr
        return result

    return run


def test_queries_bind_with_named_filters(radar):
    result = radar("node", options=("-Quadrant", "devops", "-Ring", "stop", "-Limit", "1"))
    rows = json.loads(result.stdout)
    assert isinstance(rows, list)
    assert len(rows) == 1
    assert (rows[0]["name"], rows[0]["quadrant"], rows[0]["ring"]) == ("Node.js", "DevOps", "Stop")


@pytest.mark.parametrize("queries", [("k8s",), ("k8s", "postgres")])
def test_json_contract_is_a_lowercase_array(radar, queries):
    rows = json.loads(radar(*queries).stdout)
    assert isinstance(rows, list)
    assert {row["name"] for row in rows} == ({"Kubernetes"} if len(queries) == 1 else {"Kubernetes", "PostgreSQL"})
    for row in rows:
        assert {"name", "quadrant", "ring", "why", "path", "source"} <= row.keys()
        assert row["why"]
        assert row["path"].endswith(".md")
        assert row["source"] == {"mode": "local", "reason": ""}


def test_json_no_matches_is_an_empty_array(radar):
    assert json.loads(radar("zzz-no-such-technology-xyz").stdout) == []


@pytest.mark.parametrize("available", [True, False])
@pytest.mark.parametrize("query", ["k8s", "zzz-no-such-technology-xyz"])
def test_degraded_json_keeps_notices_off_stdout(radar, tmp_path, available, query):
    result = radar(query, env={
        "ADLC_RADAR_REPO": None,
        "ADLC_RADAR_CACHE": tmp_path / "nested/cache",
        "ADLC_RADAR_URL": tmp_path / "missing.git",
        "ADLC_RADAR_FALLBACK_URL": f"file://{FALLBACK if available else tmp_path / 'missing.json'}",
    })
    rows = json.loads(result.stdout)
    assert "working with the public radar JSON" in result.stderr
    if available and query == "k8s":
        assert len(rows) == 1
        assert rows[0]["name"] == "Kubernetes"
        assert rows[0]["path"] == "public:radar.json"
        assert rows[0]["source"]["mode"] == "fallback"
        assert "clone failed" in rows[0]["source"]["reason"]
    else:
        assert rows == []
    if not available:
        assert "public radar JSON unavailable" in result.stderr


def _local_repo(path):
    shutil.copytree(TREE, path)
    for args in [
        ["init", "-q", "--initial-branch=main"],
        ["add", "."],
        ["-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid", "commit", "-qm", "fixture"],
    ]:
        subprocess.run(["git", "-C", str(path), *args], check=True, capture_output=True)
    return path


def test_stale_json_preserves_source_and_warning(radar, tmp_path):
    cache = _local_repo(tmp_path / "cache")
    (cache / ".adlc-radar-synced").write_text("1\n")
    result = radar("postgres", env={
        "ADLC_RADAR_REPO": None,
        "ADLC_RADAR_CACHE": cache,
        "ADLC_RADAR_URL": tmp_path / "missing.git",
    })
    rows = json.loads(result.stdout)
    assert len(rows) == 1
    assert rows[0]["name"] == "PostgreSQL"
    assert rows[0]["source"]["mode"] == "stale"
    assert "refresh failed" in rows[0]["source"]["reason"]
    assert "cached OKF tree" in result.stderr


def test_first_run_creates_nested_cache_before_cloning(radar, tmp_path):
    remote = _local_repo(tmp_path / "remote")
    cache = tmp_path / "fresh/adlc/radar"
    result = radar("k8s", json_output=False, env={
        "ADLC_RADAR_REPO": None,
        "ADLC_RADAR_CACHE": cache,
        "ADLC_RADAR_URL": remote.as_uri(),
        "ADLC_RADAR_FALLBACK_URL": f"file://{tmp_path / 'missing.json'}",
    })
    assert (cache / "knowledge/technologies").is_dir()
    assert "OKF tree (main@" in result.stdout
    assert "Kubernetes" in result.stdout
    assert "FALLBACK" not in result.stdout
    assert "⚠️" not in result.stdout


def test_bash_first_run_uses_empty_xdg_cache_home(tmp_path):
    remote = _local_repo(tmp_path / "remote")
    environ = {k: v for k, v in os.environ.items() if not k.startswith("ADLC_RADAR_")}
    environ.update(XDG_CACHE_HOME=str(tmp_path / "xdg"), ADLC_RADAR_URL=remote.as_uri())
    result = subprocess.run(
        ["bash", str(SKILL / "bash/radar-search.sh"), "k8s"],
        env=environ, capture_output=True, text=True, timeout=30,
    )
    assert result.returncode == 0, result.stderr
    assert (tmp_path / "xdg/adlc/radar/knowledge/technologies").is_dir()
    assert "OKF tree (main@" in result.stdout
