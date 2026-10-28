"""Framework-lane detection + run-level framework knob (M11 E6; ADR-468 rule 2, PDR-149).

Contract pinned here (bash helper in skills/factory/factory-mission/scripts/bash/):

  detect-framework.sh  Offline lane resolver. Precedence:
                       1. `framework:` override line in the run's mission.yml
                          (unknown value fails closed, exit 2).
                       2. Repo usage evidence — framework-native artifact
                          fingerprints dated by `git log` per fingerprint
                          (never mtimes; fresh --single-branch clones reset
                          them); multi-match → latest wins, conflict logged.
                       3. Installed packs in .agents/skills/ (distinctive skill
                          names); multi with no usage → latest install wins.
                       4. Embedded default — strictly the zero-evidence fallback.
                       Detection only observes (never installs, never mutates
                       the repo). Prints `<lane> <evidence>` on stdout where
                       evidence is `override | usage:<fp> | installed:<pack> |
                       default`. Conflict detail (multi-match losers) goes to
                       stderr as `conflict:` lines.

  Fingerprints (ADR-468 §decision.1 lane grammar):
    speckit     specs/ + .specify/
    superpowers docs/superpowers/plans/
    addy        CONSTRAINTS.md + references checklists
    matt        spec issues via /to-spec (docs .md mentioning /to-spec)
"""

import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).parent.parent.parent
SCRIPTS = ROOT / "skills/factory/factory-mission/scripts/bash"
DETECT = SCRIPTS / "detect-framework.sh"

pytestmark = pytest.mark.skipif(
    shutil.which("bash") is None or shutil.which("git") is None,
    reason="needs bash and git",
)


def git(cwd, *args):
    subprocess.run(["git", *args], cwd=cwd, capture_output=True, check=True)


def run(cwd, *args, env=None):
    import os

    full_env = {k: v for k, v in os.environ.items() if not k.startswith("ADLC_")}
    full_env.update(env or {})
    return subprocess.run(["bash", str(DETECT), *args], cwd=cwd, capture_output=True, text=True, env=full_env)


@pytest.fixture
def repo(tmp_path):
    """Empty git repo with committer identity (no framework evidence)."""
    work = tmp_path / "work"
    work.mkdir()
    git(work, "init", "-q", "-b", "main")
    git(work, "config", "user.email", "bot@t.local")
    git(work, "config", "user.name", "bot")
    git(work, "config", "commit.gpgsign", "false")
    (work / "README.md").write_text("x\n")
    git(work, "add", "-A")
    git(work, "commit", "-q", "-m", "base")
    return work


def commit_all(work, message, date):
    env = {"GIT_AUTHOR_DATE": date, "GIT_COMMITTER_DATE": date}
    import os

    full = dict(os.environ)
    full.update(env)
    subprocess.run(["git", "add", "-A"], cwd=work, check=True)
    subprocess.run(["git", "commit", "-q", "-m", message], cwd=work, check=True, env=full)


# ── precedence ─────────────────────────────────────────────────────────────

def test_zero_evidence_resolves_embedded_default(repo):
    result = run(repo)
    assert result.returncode == 0, f"aborted: {result.stderr}"
    assert result.stdout.strip().split() == ["embedded", "default"]


def test_usage_beats_installation(repo):
    (repo / ".agents/skills/addy-agent-skills").mkdir(parents=True)
    (repo / ".agents/skills/addy-agent-skills/SKILL.md").write_text("# addy\n")
    (repo / "CONSTRAINTS.md").write_text("# constraints\n")
    commit_all(repo, "addy usage + install", "2026-01-02T00:00:00+00:00")
    result = run(repo)
    assert result.returncode == 0, f"aborted: {result.stderr}"
    lane, evidence = result.stdout.strip().split(None, 1)
    assert lane == "addy"
    assert evidence.startswith("usage:")


def test_latest_usage_wins_and_conflict_logged(repo):
    (repo / "specs").mkdir()
    (repo / "specs/spec.md").write_text("s\n")
    (repo / ".specify").mkdir()
    (repo / ".specify/x.md").write_text("x\n")
    commit_all(repo, "speckit usage", "2026-01-01T00:00:00+00:00")
    (repo / "CONSTRAINTS.md").write_text("# c\n")
    (repo / "references").mkdir()
    (repo / "references/checklist.md").write_text("c\n")
    commit_all(repo, "addy usage", "2026-02-01T00:00:00+00:00")
    result = run(repo)
    assert result.returncode == 0, f"aborted: {result.stderr}"
    lane, _ = result.stdout.strip().split(None, 1)
    assert lane == "addy"
    assert "conflict:" in result.stderr


def test_override_wins_over_usage(repo):
    (repo / "CONSTRAINTS.md").write_text("# c\n")
    commit_all(repo, "addy usage", "2026-01-01T00:00:00+00:00")
    mission = repo / "mission.yml"
    mission.write_text("workflow:\n  framework: speckit\n")
    result = run(repo, "--mission", str(mission))
    assert result.returncode == 0, f"aborted: {result.stderr}"
    assert result.stdout.strip().split() == ["speckit", "override"]


def test_unknown_framework_fails_closed(repo):
    mission = repo / "mission.yml"
    mission.write_text("workflow:\n  framework: brandnew\n")
    result = run(repo, "--mission", str(mission))
    assert result.returncode == 2
    assert "unknown framework" in result.stderr.lower()


def test_installed_pack_resolves_when_no_usage(repo):
    (repo / ".agents/skills/addy-agent-skills").mkdir(parents=True)
    (repo / ".agents/skills/addy-agent-skills/SKILL.md").write_text("# addy\n")
    commit_all(repo, "install addy pack", "2026-01-01T00:00:00+00:00")
    result = run(repo)
    assert result.returncode == 0, f"aborted: {result.stderr}"
    lane, evidence = result.stdout.strip().split(None, 1)
    assert lane == "addy"
    assert evidence.startswith("installed:")


def test_usage_dated_by_git_log_not_mtime(repo):
    """A fresh --single-branch-style checkout resets mtimes: touch an older
    fingerprint newer on disk and the git-dated (older-commit) winner must
    still lose to the newer commit."""
    (repo / "specs").mkdir()
    (repo / "specs/spec.md").write_text("s\n")
    (repo / ".specify").mkdir()
    (repo / ".specify/x.md").write_text("x\n")
    commit_all(repo, "speckit usage", "2026-02-01T00:00:00+00:00")
    (repo / "CONSTRAINTS.md").write_text("# c\n")
    (repo / "references").mkdir()
    (repo / "references/checklist.md").write_text("c\n")
    commit_all(repo, "addy usage", "2026-01-01T00:00:00+00:00")
    import time

    time.sleep(1.1)
    (repo / "CONSTRAINTS.md").write_text("# c touched\n")
    result = run(repo)
    assert result.returncode == 0, f"aborted: {result.stderr}"
    assert result.stdout.strip().split(None, 1)[0] == "speckit"
