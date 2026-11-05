"""test_team_boot_counts.py — RED→GREEN regression tests for team-boot counting.

Covers:
- ChDR scope counts a record once (file-preferred with index-only fallback).
  Fixture: 13-line chdr.md with one `| ChDR-006 |` row + matching
  `ChDR-006-*.md` file. Buggy Bash reports 14 (13 from BRE `\\|` +
  1 file); buggy sum reports 2. Correct: exactly 1.
- ChDR index-only fallback: row without individual files counts one;
  headings/separators/footer contribute zero.
- Pending CDRs support directives repos whose `.git` is a gitfile
  (submodule): local proposed CDR + 2 branch drafts = 3 total.
"""

from pathlib import Path
import json
import re
import shutil
import subprocess

import pytest

ROOT = Path(__file__).parent.parent.parent
BOOT_SH_PATH = ROOT / "skills/team/team-boot/scripts/bash/boot.sh"
BOOT_PS1_PATH = ROOT / "skills/team/team-boot/scripts/powershell/boot.ps1"

CHDR_INDEX_13_LINES = """# Change Decision Records

> Promoted from `.adlc/drafts/chdr/` via clarify → publish. Accepted ChDRs live here.

## ChDR Index

| ID | Title | Status | Date | Type |
|----|-------|--------|------|------|
| ChDR-006 | The skill-side remote lane was abandoned twice | Accepted | 2026-10-24 | abandoned |

---

*Individual ChDR files: ChDR-*.md in this directory*
"""


def _write_directives(directives: Path):
    directives.mkdir(parents=True, exist_ok=True)
    (directives / "context_modules").mkdir(parents=True, exist_ok=True)
    (directives / "context_modules" / "constitution.md").write_text("1. Test Principle\n")
    (directives / "CDR.md").write_text("# CDR\n\n| CDR-2026-001 | Rule | test |\n")
    (directives / ".skills.json").write_text(
        json.dumps({"default": [], "external": {}, "blocked": []})
    )
    (directives / ".mcp.json").write_text(json.dumps({"mcpServers": {}}))


def _write_project(project: Path, directives: Path):
    project.mkdir(parents=True, exist_ok=True)
    (project / ".adlc").mkdir(parents=True, exist_ok=True)
    (project / ".adlc" / "init-options.json").write_text(
        json.dumps({"team_ai_directives": str(directives)})
    )


def _write_chdr_fixture(project: Path, with_record_file: bool):
    chdr_dir = project / "docs" / "adlc" / "memory" / "chdr"
    chdr_dir.mkdir(parents=True, exist_ok=True)
    (chdr_dir / "chdr.md").write_text(CHDR_INDEX_13_LINES)
    if with_record_file:
        (chdr_dir / "ChDR-006-skill-side-remote-lane-abandoned.md").write_text(
            "# ChDR-006\n\nAccepted record.\n"
        )


def _scope_chdr_count(stdout: str) -> int:
    m = re.search(r"(\d+)\s+ChDRs", stdout)
    assert m, f"no ChDR scope count in output:\n{stdout[-2000:]}"
    return int(m.group(1))


def _run_boot_sh(project: Path) -> str:
    result = subprocess.run(
        ["bash", str(BOOT_SH_PATH)],
        cwd=project,
        capture_output=True,
        text=True,
        timeout=15,
    )
    assert result.returncode == 0, f"boot.sh failed:\n{result.stderr}"
    return result.stdout


def _run_boot_ps1(project: Path) -> str | None:
    if shutil.which("pwsh") is None:
        pytest.skip("pwsh not installed")
    result = subprocess.run(
        ["pwsh", "-NoProfile", "-File", str(BOOT_PS1_PATH)],
        cwd=project,
        capture_output=True,
        text=True,
        timeout=30,
    )
    assert result.returncode == 0, f"boot.ps1 failed:\n{result.stderr}"
    return result.stdout


@pytest.mark.requires_bash
def test_chdr_scope_counts_record_once(tmp_path):
    """One index row + one matching record file = exactly 1 ChDR."""
    directives = tmp_path / "directives"
    project = tmp_path / "project"
    _write_directives(directives)
    _write_project(project, directives)
    _write_chdr_fixture(project, with_record_file=True)

    stdout = _run_boot_sh(project)
    assert _scope_chdr_count(stdout) == 1, (
        "ChDR double-count or BRE regex bug: expected exactly 1 "
        f"(13-line index + 1 record file must not sum)"
    )


@pytest.mark.requires_bash
def test_chdr_scope_uses_index_only_as_fallback(tmp_path):
    """Index row without individual files counts one; chrome counts zero."""
    directives = tmp_path / "directives"
    project = tmp_path / "project"
    _write_directives(directives)
    _write_project(project, directives)
    _write_chdr_fixture(project, with_record_file=False)

    stdout = _run_boot_sh(project)
    assert _scope_chdr_count(stdout) == 1


def test_chdr_scope_counts_record_once_pwsh(tmp_path):
    """PowerShell parity: one row + one file = exactly 1 ChDR."""
    directives = tmp_path / "directives"
    project = tmp_path / "project"
    _write_directives(directives)
    _write_project(project, directives)
    _write_chdr_fixture(project, with_record_file=True)

    stdout = _run_boot_ps1(project)
    assert _scope_chdr_count(stdout) == 1


def test_chdr_scope_uses_index_only_as_fallback_pwsh(tmp_path):
    """PowerShell parity: index-only fixture counts exactly 1."""
    directives = tmp_path / "directives"
    project = tmp_path / "project"
    _write_directives(directives)
    _write_project(project, directives)
    _write_chdr_fixture(project, with_record_file=False)

    stdout = _run_boot_ps1(project)
    assert _scope_chdr_count(stdout) == 1


def _git(cwd: Path, *args: str):
    result = subprocess.run(
        ["git", *args],
        cwd=cwd,
        capture_output=True,
        text=True,
        timeout=15,
    )
    assert result.returncode == 0, f"git {' '.join(args)} failed:\n{result.stderr}"
    return result


@pytest.mark.requires_bash
def test_pending_cdrs_supports_gitfile_directives_repo(tmp_path):
    """Directives repo with `.git` as a gitfile (submodule) still contributes
    its `adlc` branch CDR drafts to the pending total."""
    directives = tmp_path / "directives"
    project = tmp_path / "project"
    _write_directives(directives)
    _write_project(project, directives)

    # Local proposed CDR draft (counts 1).
    local_cdr = project / ".adlc" / "drafts" / "cdr"
    local_cdr.mkdir(parents=True, exist_ok=True)
    (local_cdr / "CDR-local-proposed.md").write_text(
        "---\nstatus: proposed\n---\n\n# local\n"
    )

    # Real git repo holding the adlc branch with 2 CDR drafts.
    real_repo = tmp_path / "real_git"
    real_repo.mkdir()
    _git(real_repo, "init")
    _git(real_repo, "config", "user.name", "Test User")
    _git(real_repo, "config", "user.email", "test@example.com")
    _git(real_repo, "config", "commit.gpgsign", "false")
    (real_repo / "README.md").write_text("# real\n")
    _git(real_repo, "add", "README.md")
    _git(real_repo, "commit", "-m", "init")
    _git(real_repo, "checkout", "-b", "adlc")
    (real_repo / "drafts" / "cdr").mkdir(parents=True, exist_ok=True)
    (real_repo / "drafts" / "cdr" / "CDR-900.md").write_text("# 900\n")
    (real_repo / "drafts" / "cdr" / "CDR-901.md").write_text("# 901\n")
    _git(real_repo, "add", "drafts/cdr/CDR-900.md", "drafts/cdr/CDR-901.md")
    _git(real_repo, "commit", "-m", "branch drafts")

    # Turn directives into a gitfile consumer (submodule shape): `.git` is a
    # file, not a directory. `[ -d .git ]` misses it; `[ -e .git ]` finds it.
    gitdir = real_repo / ".git"
    (directives / ".git").write_text(f"gitdir: {gitdir}\n")

    stdout = _run_boot_sh(project)
    m = re.search(r"\|\s*—\s*\|\s*(\d+)\s+CDR draft\(s\)", stdout)
    assert m, f"no CDR pending row in output:\n{stdout[-3000:]}"
    assert int(m.group(1)) == 3, (
        f"expected 1 local + 2 branch = 3 CDR drafts, got {m.group(1)}"
    )
