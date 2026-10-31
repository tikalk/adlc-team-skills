"""Deterministic team-setup script flags: --validate and --wire.

These flags are the non-interactive half of the team-setup skill. They let a
headless caller (adlc-cli `team setup --directives <path>`) run the skill's
Mode 2 (point to existing local path) without an LLM session: the script
validates the team-ai-directives structure and writes the absolute path into
.adlc/init-options.json. The interactive skill (mode selection + confirmation)
stays the in-session path; the script is the single source of the validation
and wiring logic for both.

Pins:
- bash + powershell twins expose the same flags (twin parity).
- --validate: exit 0 for a complete structure, exit 1 with MISSING lines for an
  incomplete one.
- --wire: merges team_ai_directives (absolute path) into an existing
  .adlc/init-options.json without clobbering other keys; refuses an invalid
  structure without writing; rejects a nonexistent directory.
"""

import json
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).parent.parent.parent
BASH = ROOT / "skills/team/team-setup/scripts/bash/team-helpers.sh"
PS1 = ROOT / "skills/team/team-setup/scripts/powershell/team-helpers.ps1"


def _make_valid_directives(tmp_path: Path) -> Path:
    """A minimal team-ai-directives repo passing the 6-path structure check."""
    d = tmp_path / "tad"
    (d / "context_modules" / "rules").mkdir(parents=True)
    (d / "context_modules" / "personas").mkdir(parents=True)
    (d / "context_modules" / "examples").mkdir(parents=True)
    (d / "context_modules" / "constitution.md").write_text("# Constitution\n")
    (d / "CDR.md").write_text("# CDR\n")
    (d / ".skills.json").write_text(json.dumps({"version": "2.0.0", "default": []}))
    return d


def _run_bash(args, cwd, project_root, extra_env=None):
    env = {"PATH": "/usr/bin:/bin", "PROJECT_ROOT": str(project_root)}
    if extra_env:
        env.update(extra_env)
    return subprocess.run(
        ["bash", str(BASH), *args],
        cwd=cwd,
        env=env,
        capture_output=True,
        text=True,
    )


def _run_bash_no_project_root(args, cwd):
    """Invoke without PROJECT_ROOT (U1 regression: must fall back, not crash)."""
    import os

    env = {"PATH": os.environ.get("PATH", "/usr/bin:/bin")}
    env.pop("PROJECT_ROOT", None)
    return subprocess.run(
        ["bash", str(BASH), *args],
        cwd=cwd,
        env=env,
        capture_output=True,
        text=True,
    )


# ── twin parity (structural) ────────────────────────────────────────────


def test_bash_usage_documents_validate_and_wire():
    usage = [l for l in BASH.read_text().splitlines() if "Usage:" in l]
    assert usage, "no usage line in team-helpers.sh"
    assert "--validate" in usage[0] and "--wire" in usage[0], usage[0]


def test_powershell_twin_declares_validate_and_wire():
    text = PS1.read_text()
    assert "[string]$Validate" in text, "ps1 twin missing -Validate param"
    assert "[string]$Wire" in text, "ps1 twin missing -Wire param"


# ── --validate (bash) ───────────────────────────────────────────────────


@pytest.mark.requires_bash
def test_validate_accepts_complete_structure(tmp_path):
    d = _make_valid_directives(tmp_path)
    r = _run_bash(["--validate", str(d)], cwd=tmp_path, project_root=tmp_path)
    assert r.returncode == 0, r.stderr
    assert "MISSING" not in r.stdout


@pytest.mark.requires_bash
def test_validate_rejects_incomplete_structure(tmp_path):
    d = tmp_path / "tad"
    d.mkdir()
    (d / "CDR.md").write_text("# CDR\n")  # everything else missing
    r = _run_bash(["--validate", str(d)], cwd=tmp_path, project_root=tmp_path)
    assert r.returncode == 1, r.stdout
    assert "MISSING: context_modules/constitution.md" in r.stdout
    assert "MISSING: .skills.json" in r.stdout


# ── --wire (bash) ───────────────────────────────────────────────────────


@pytest.mark.requires_bash
def test_wire_writes_absolute_path_and_preserves_existing_keys(tmp_path):
    d = _make_valid_directives(tmp_path)
    project = tmp_path / "proj"
    (project / ".adlc").mkdir(parents=True)
    init = project / ".adlc" / "init-options.json"
    init.write_text(json.dumps({"agent": "opencode", "skills_source": "tikalk/adlc-team-skills"}))

    r = _run_bash(["--wire", str(d)], cwd=project, project_root=project)
    assert r.returncode == 0, f"stdout={r.stdout} stderr={r.stderr}"
    assert f"WIRED team_ai_directives={d.resolve()}" in r.stdout

    cfg = json.loads(init.read_text())
    assert cfg["team_ai_directives"] == str(d.resolve())
    assert cfg["agent"] == "opencode", "existing keys must survive the merge"
    assert cfg["skills_source"] == "tikalk/adlc-team-skills"


@pytest.mark.requires_bash
def test_wire_creates_missing_init_options(tmp_path):
    d = _make_valid_directives(tmp_path)
    project = tmp_path / "proj"
    project.mkdir()

    r = _run_bash(["--wire", str(d)], cwd=project, project_root=project)
    assert r.returncode == 0, r.stderr
    cfg = json.loads((project / ".adlc" / "init-options.json").read_text())
    assert cfg["team_ai_directives"] == str(d.resolve())


@pytest.mark.requires_bash
def test_wire_refuses_invalid_structure_without_writing(tmp_path):
    d = tmp_path / "tad"
    d.mkdir()  # no constitution, no CDR.md, no .skills.json
    project = tmp_path / "proj"
    (project / ".adlc").mkdir(parents=True)
    init = project / ".adlc" / "init-options.json"
    init.write_text(json.dumps({"agent": "opencode"}))

    r = _run_bash(["--wire", str(d)], cwd=project, project_root=project)
    assert r.returncode == 1, r.stdout
    assert "not wired" in r.stderr
    assert "team_ai_directives" not in init.read_text(), "must not wire an invalid structure"


@pytest.mark.requires_bash
def test_wire_rejects_nonexistent_directory(tmp_path):
    project = tmp_path / "proj"
    project.mkdir()
    r = _run_bash(["--wire", str(tmp_path / "nope")], cwd=project, project_root=project)
    assert r.returncode == 1
    assert "not found" in r.stderr


@pytest.mark.requires_bash
def test_wire_rejects_malformed_skills_json(tmp_path):
    d = _make_valid_directives(tmp_path)
    (d / ".skills.json").write_text("{not json")
    project = tmp_path / "proj"
    project.mkdir()
    r = _run_bash(["--wire", str(d)], cwd=project, project_root=project)
    assert r.returncode == 1, r.stdout
    assert "not valid JSON" in r.stdout + r.stderr


@pytest.mark.requires_bash
def test_validate_rejects_malformed_skills_json(tmp_path):
    """U3: --validate must agree with --wire that malformed .skills.json fails."""
    d = _make_valid_directives(tmp_path)
    (d / ".skills.json").write_text("{not json")
    r = _run_bash(["--validate", str(d)], cwd=tmp_path, project_root=tmp_path)
    assert r.returncode == 1, r.stdout
    assert "not valid JSON" in r.stdout + r.stderr


@pytest.mark.requires_bash
@pytest.mark.parametrize("poison", ["{bad json", "[1,2]", "null", '"str"'])
def test_wire_refuses_corrupt_or_non_object_init_options(tmp_path, poison):
    """U2: corrupt/non-object init-options.json → clean ERROR refusal, file untouched."""
    d = _make_valid_directives(tmp_path)
    project = tmp_path / "proj"
    (project / ".adlc").mkdir(parents=True)
    init = project / ".adlc" / "init-options.json"
    init.write_text(poison)

    r = _run_bash(["--wire", str(d)], cwd=project, project_root=project)
    assert r.returncode == 1, f"stdout={r.stdout} stderr={r.stderr}"
    assert "not valid JSON or not an object" in r.stderr
    assert "Traceback" not in r.stdout + r.stderr
    assert init.read_text() == poison, "refusal must not touch the file"


@pytest.mark.requires_bash
def test_wire_without_project_root_falls_back(tmp_path):
    """U1: unset PROJECT_ROOT must fall back (git root/pwd), not crash unbound."""
    d = _make_valid_directives(tmp_path)
    project = tmp_path / "proj"
    project.mkdir()

    r = _run_bash_no_project_root(["--wire", str(d)], cwd=project)
    assert r.returncode == 0, f"stdout={r.stdout} stderr={r.stderr}"
    assert "unbound variable" not in r.stderr
    assert f"WIRED team_ai_directives={d.resolve()}" in r.stdout
    cfg = json.loads((project / ".adlc" / "init-options.json").read_text())
    assert cfg["team_ai_directives"] == str(d.resolve())


@pytest.mark.requires_bash
def test_wire_resolves_symlinked_directives(tmp_path):
    """U8: symlinked DIR stores the canonical physical path (bash matches PS twin)."""
    d = _make_valid_directives(tmp_path)
    link = tmp_path / "linkdir"
    link.symlink_to(d, target_is_directory=True)
    project = tmp_path / "proj"
    project.mkdir()

    r = _run_bash(["--wire", str(link)], cwd=project, project_root=project)
    assert r.returncode == 0, f"stdout={r.stdout} stderr={r.stderr}"
    cfg = json.loads((project / ".adlc" / "init-options.json").read_text())
    assert cfg["team_ai_directives"] == str(d.resolve())


# ── --validate / --wire (powershell twin, runtime only if pwsh exists) ──


PWSH = shutil.which("pwsh") or shutil.which("powershell")


@pytest.mark.skipif(PWSH is None, reason="pwsh not installed")
def test_powershell_wire_matches_bash_contract(tmp_path):
    d = _make_valid_directives(tmp_path)
    project = tmp_path / "proj"
    (project / ".adlc").mkdir(parents=True)
    init = project / ".adlc" / "init-options.json"
    init.write_text(json.dumps({"agent": "opencode"}))

    r = subprocess.run(
        [PWSH, "-NoProfile", "-File", str(PS1), "-Wire", str(d)],
        cwd=project,
        env={"PROJECT_ROOT": str(project), "PATH": "/usr/bin:/bin"},
        capture_output=True,
        text=True,
    )
    assert r.returncode == 0, f"stdout={r.stdout} stderr={r.stderr}"
    cfg = json.loads(init.read_text())
    assert cfg["team_ai_directives"] == str(d.resolve())
    assert cfg["agent"] == "opencode"
