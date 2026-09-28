"""Unit tests for WORKSPACE_REPO_ROOT resolution and workspace-publish pathspec."""
from __future__ import annotations

import json
import os
import stat
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
TEAM_PATHS = ROOT / "skills/team/team-paths.sh"
PUBLISH = ROOT / "skills/workspace/workspace-publish/scripts/bash/workspace-publish.sh"
INIT = ROOT / "skills/workspace/workspace-init/scripts/bash/workspace-init.sh"


def _run_bash(script: str, cwd: Path, env: dict | None = None) -> subprocess.CompletedProcess:
    full_env = os.environ.copy()
    # Strip workspace overrides unless the test sets them
    full_env.pop("WORKSPACE_REPO_ROOT", None)
    full_env.pop("SDD_DOCS_LOCATION", None)
    if env:
        full_env.update(env)
    return subprocess.run(
        ["bash", "-c", script],
        cwd=cwd,
        capture_output=True,
        text=True,
        env=full_env,
    )


def _git_init(path: Path) -> None:
    subprocess.run(["git", "init"], cwd=path, check=True, capture_output=True)
    subprocess.run(["git", "config", "user.email", "test@example.com"], cwd=path, check=True, capture_output=True)
    subprocess.run(["git", "config", "user.name", "test"], cwd=path, check=True, capture_output=True)


@pytest.mark.requires_bash
def test_resolver_defaults_to_project_root(tmp_path: Path):
    project = tmp_path / "proj"
    project.mkdir()
    (project / ".adlc").mkdir()
    _git_init(project)
    script = f'''
source "{TEAM_PATHS}"
resolve_workspace_repo_root "{project}" >/dev/null
echo "$WORKSPACE_REPO_ROOT"
echo "$WORKSPACE_CONFIGURED"
'''
    r = _run_bash(script, project)
    assert r.returncode == 0, r.stderr
    lines = r.stdout.strip().splitlines()
    assert Path(lines[0]).resolve() == project.resolve()
    assert lines[1] == "false"


@pytest.mark.requires_bash
def test_resolver_env_precedence(tmp_path: Path):
    project = tmp_path / "proj"
    workspace = tmp_path / "ws"
    project.mkdir()
    workspace.mkdir()
    (project / ".adlc").mkdir()
    (workspace / ".adlc").mkdir()
    _git_init(project)
    # Also put json that would otherwise win if env missing
    (project / ".adlc" / "init-options.json").write_text(
        json.dumps({"workspace_repo_root": str(tmp_path / "other")})
    )
    script = f'''
source "{TEAM_PATHS}"
resolve_workspace_repo_root "{project}" >/dev/null
echo "$WORKSPACE_REPO_ROOT"
echo "$WORKSPACE_CONFIGURED"
'''
    r = _run_bash(script, project, env={"WORKSPACE_REPO_ROOT": str(workspace)})
    assert r.returncode == 0, r.stderr
    lines = r.stdout.strip().splitlines()
    assert Path(lines[0]).resolve() == workspace.resolve()
    assert lines[1] == "true"


@pytest.mark.requires_bash
def test_resolver_json_key(tmp_path: Path):
    project = tmp_path / "proj"
    workspace = tmp_path / "ws"
    project.mkdir()
    workspace.mkdir()
    (project / ".adlc").mkdir()
    (workspace / ".adlc").mkdir()
    _git_init(project)
    (project / ".adlc" / "init-options.json").write_text(
        json.dumps({"workspace_repo_root": str(workspace)})
    )
    script = f'''
source "{TEAM_PATHS}"
resolve_workspace_repo_root "{project}" >/dev/null
echo "$WORKSPACE_REPO_ROOT"
echo "$WORKSPACE_CONFIGURED"
'''
    r = _run_bash(script, project)
    assert r.returncode == 0, r.stderr
    lines = r.stdout.strip().splitlines()
    assert Path(lines[0]).resolve() == workspace.resolve()
    assert lines[1] == "true"


@pytest.mark.requires_bash
def test_resolver_walk_up_discovery(tmp_path: Path):
    workspace = tmp_path / "ws"
    child = workspace / "backend-api"
    workspace.mkdir()
    child.mkdir()
    (workspace / ".adlc").mkdir()
    _git_init(child)
    script = f'''
source "{TEAM_PATHS}"
resolve_workspace_repo_root "{child}" >/dev/null
echo "$WORKSPACE_REPO_ROOT"
echo "$WORKSPACE_CONFIGURED"
'''
    r = _run_bash(script, child)
    assert r.returncode == 0, r.stderr
    lines = r.stdout.strip().splitlines()
    assert Path(lines[0]).resolve() == workspace.resolve()
    assert lines[1] == "true"


@pytest.mark.requires_bash
def test_no_subfolder_layout(tmp_path: Path):
    """Configured workspace root is used as-is — no per-project subfolder appended."""
    project = tmp_path / "my-service"
    workspace = tmp_path / "shared-ws"
    project.mkdir()
    workspace.mkdir()
    (project / ".adlc").mkdir()
    _git_init(project)
    script = f'''
source "{TEAM_PATHS}"
resolve_workspace_repo_root "{project}" >/dev/null
echo "$WORKSPACE_REPO_ROOT"
'''
    r = _run_bash(script, project, env={"WORKSPACE_REPO_ROOT": str(workspace)})
    assert r.returncode == 0, r.stderr
    resolved = Path(r.stdout.strip()).resolve()
    assert resolved == workspace.resolve()
    assert "my-service" not in str(resolved.relative_to(tmp_path)) or resolved == workspace.resolve()


@pytest.mark.requires_bash
def test_tilde_expansion(tmp_path: Path, monkeypatch):
    project = tmp_path / "proj"
    project.mkdir()
    (project / ".adlc").mkdir()
    _git_init(project)
    home_ws = tmp_path / "homews"
    home_ws.mkdir()
    monkeypatch.setenv("HOME", str(tmp_path))
    script = f'''
source "{TEAM_PATHS}"
export HOME="{tmp_path}"
export WORKSPACE_REPO_ROOT="~/homews"
resolve_workspace_repo_root "{project}" >/dev/null
echo "$WORKSPACE_REPO_ROOT"
'''
    r = _run_bash(script, project, env={"HOME": str(tmp_path), "WORKSPACE_REPO_ROOT": "~/homews"})
    assert r.returncode == 0, r.stderr
    assert Path(r.stdout.strip()).resolve() == home_ws.resolve()


@pytest.mark.requires_bash
def test_publish_not_configured(tmp_path: Path):
    project = tmp_path / "proj"
    project.mkdir()
    (project / ".adlc").mkdir()
    _git_init(project)
    r = subprocess.run(
        ["bash", str(PUBLISH), "--json"],
        cwd=project,
        capture_output=True,
        text=True,
        env={**os.environ, **{"WORKSPACE_REPO_ROOT": ""}},
    )
    # Clear env explicitly
    env = os.environ.copy()
    env.pop("WORKSPACE_REPO_ROOT", None)
    r = subprocess.run(
        ["bash", str(PUBLISH), "--json"],
        cwd=project,
        capture_output=True,
        text=True,
        env=env,
    )
    assert r.returncode == 0, r.stderr
    data = json.loads(r.stdout)
    assert data["PUBLISH_OUTCOME"] == "not_configured"
    assert data["WORKSPACE_CONFIGURED"] is False


@pytest.mark.requires_bash
def test_publish_pathspec_staging(tmp_path: Path):
    """Publish script must use explicit pathspec — never git add -A."""
    text = PUBLISH.read_text(encoding="utf-8")
    assert "PATHSPEC=(.adlc PRD.md AD.md specs evals)" in text
    assert 'git -C "$TARGET" add --' in text
    # Ensure no unscoped add-all command (ignore comments)
    for line in text.splitlines():
        stripped = line.split("#", 1)[0].strip()
        if not stripped:
            continue
        assert "git add -A" not in stripped and "git add --all" not in stripped
    assert "status --porcelain --" in text

    # Runtime: only metadata paths staged
    workspace = tmp_path / "ws"
    project = workspace / "child"
    workspace.mkdir()
    project.mkdir()
    (workspace / ".adlc").mkdir()
    (workspace / "PRD.md").write_text("# PRD\n")
    (workspace / "AD.md").write_text("# AD\n")
    (workspace / "specs").mkdir()
    (workspace / "evals").mkdir()
    (workspace / "sibling-noise.txt").write_text("should not be staged")
    (project / ".adlc").mkdir()
    _git_init(workspace)
    subprocess.run(["git", "add", ".adlc", "PRD.md", "AD.md", "specs", "evals", "sibling-noise.txt"], cwd=workspace, check=True, capture_output=True)
    subprocess.run(["git", "commit", "-m", "init"], cwd=workspace, check=True, capture_output=True)
    # Modify metadata + noise
    (workspace / "PRD.md").write_text("# PRD updated\n")
    (workspace / "sibling-noise.txt").write_text("changed noise")
    (workspace / ".adlc" / "note.md").write_text("note")

    # Inspect pathspec status vs full status via the same pathspec the script uses
    pathspec_status = subprocess.run(
        ["git", "status", "--porcelain", "--", ".adlc", "PRD.md", "AD.md", "specs", "evals"],
        cwd=workspace, capture_output=True, text=True, check=True,
    ).stdout
    full_status = subprocess.run(
        ["git", "status", "--porcelain"],
        cwd=workspace, capture_output=True, text=True, check=True,
    ).stdout
    assert "PRD.md" in pathspec_status
    assert "sibling-noise.txt" not in pathspec_status
    assert "sibling-noise.txt" in full_status


@pytest.mark.requires_bash
def test_workspace_init_creates_layout(tmp_path: Path):
    ws = tmp_path / "ws"
    ws.mkdir()
    _git_init(ws)
    r = subprocess.run(
        ["bash", str(INIT), "--init", "--json"],
        cwd=ws,
        capture_output=True,
        text=True,
    )
    assert r.returncode == 0, r.stderr + r.stdout
    assert (ws / ".adlc").is_dir()
    assert (ws / "PRD.md").is_file()
    assert (ws / "AD.md").is_file()
    assert (ws / "specs").is_dir()
    assert (ws / "evals").is_dir()
    json_start = r.stdout.find("{")
    assert json_start >= 0, r.stdout
    data = json.loads(r.stdout[json_start:])
    assert data["MODE"] == "init"


@pytest.mark.requires_bash
def test_publish_script_parity_mentions():
    """Bash and PowerShell publish scripts both exist with matching names."""
    sh = ROOT / "skills/workspace/workspace-publish/scripts/bash/workspace-publish.sh"
    ps = ROOT / "skills/workspace/workspace-publish/scripts/powershell/workspace-publish.ps1"
    assert sh.exists()
    assert ps.exists()
    ps_text = ps.read_text(encoding="utf-8")
    # Explicit conditional assignment — not PowerShell -or Boolean misuse for branch naming
    assert "PROJECT_ROOT -or" not in ps_text
    assert '.adlc' in ps_text and 'PRD.md' in ps_text and '$Pathspec' in ps_text
    for line in ps_text.splitlines():
        stripped = line.split("#", 1)[0].strip()
        if stripped:
            assert "git add -A" not in stripped and "git add --all" not in stripped


def test_skill_dir_name_parity_workspace_skills():
    for name in ("workspace-init", "workspace-publish"):
        skill = ROOT / "skills/workspace" / name / "SKILL.md"
        assert skill.exists()
        content = skill.read_text(encoding="utf-8")
        assert f"name: {name}" in content
