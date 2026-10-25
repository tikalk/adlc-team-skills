"""Script layout contract tests (the layout normalization).

Pins the rule that every skill script lives under scripts/bash/ or
scripts/powershell/ — no strays at skill roots, no scripts directly under
scripts/, no python runtime scripts (the skill-scripts twin rule). Also pins:

- every SKILL.md scripts: frontmatter entry points at a file that exists
  (team-init and team-levelup declared ps: twins that did not exist — on
  Windows the dispatcher selects the declared ps variant, the existence
  check then fails, and the skill silently cannot run)
- every powershell script has a bash twin and vice versa (the two documented
  exemptions carry their header notes in the scripts themselves)
- regression pins for the three latent bash bugs the move surfaced:
  bare --next-cdr/--index aborted on unbound globals, team-init.sh died at
  its helpers-not-found check (path one level short since before the move),
  and score-confidence.sh aborted when a CDR had no confidence entry
  (pipefail + set -e killed the pipeline before the documented 1.0 default)

Twin parity for the levelup helpers (signal-gate, next-cdr) runs BOTH twins
and fails on disagreement — skipped where pwsh is absent (CI runs it).
"""

import re
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).parent.parent.parent
SKILLS = ROOT / "skills"
LEVELUP = SKILLS / "team/team-levelup/scripts"

# bash solos with a documented exemption header in the script itself
TWIN_EXEMPT_BASH = {
    "factory/factory-review/scripts/bash/check-verdict-head.sh",
    "product/product-implement/scripts/bash/migrate-pdr-frontmatter.sh",
}


# ── layout: every script under scripts/bash/ or scripts/powershell/ ────────

def test_every_bash_script_lives_under_scripts_bash():
    strays = [str(p.relative_to(SKILLS)) for p in SKILLS.rglob("*.sh") if p.parent.name != "bash"]
    assert not strays, f"scripts outside scripts/bash/: {strays}"


def test_every_powershell_script_lives_under_scripts_powershell():
    strays = [str(p.relative_to(SKILLS)) for p in SKILLS.rglob("*.ps1") if p.parent.name != "powershell"]
    assert not strays, f"scripts outside scripts/powershell/: {strays}"


def test_no_python_runtime_scripts():
    """No .py under any scripts/ subtree (the skill-scripts twin rule);
    test-side python (pytest suite, evals graders) is out of scope."""
    strays = [str(p.relative_to(SKILLS)) for p in SKILLS.rglob("*.py")]
    assert not strays, f"python runtime scripts in skills/: {strays}"


# ── twin inventory ──────────────────────────────────────────────────────────

def _twin_map(pattern, twin_dir, twin_suffix):
    result = {}
    for p in sorted(SKILLS.rglob(pattern)):
        rel = p.relative_to(SKILLS)
        twin = p.parent.parent / twin_dir / (p.stem + twin_suffix)
        result[str(rel)] = twin
    return result


def test_every_bash_script_has_a_powershell_twin():
    for rel, twin in _twin_map("*.sh", "powershell", ".ps1").items():
        if rel in TWIN_EXEMPT_BASH:
            continue
        assert twin.exists(), f"{rel}: no powershell twin at {twin.relative_to(SKILLS)}"


def test_every_powershell_script_has_a_bash_twin():
    for rel, twin in _twin_map("*.ps1", "bash", ".sh").items():
        assert twin.exists(), f"{rel}: no bash twin at {twin.relative_to(SKILLS)}"


# ── frontmatter declarations point at real files ───────────────────────────

def _frontmatter_scripts(skill_md):
    text = skill_md.read_text(encoding="utf-8")
    m = re.match(r"^---\n(.*?)\n---\n", text, re.DOTALL)
    if not m:
        return {}
    entries = {}
    in_scripts = False
    for line in m.group(1).splitlines():
        if re.match(r"^\S", line):
            in_scripts = line.startswith("scripts:")
            continue
        if in_scripts:
            em = re.match(r"^\s+(sh|ps|py):\s*(\S+)", line)
            if em:
                entries[em.group(1)] = em.group(2)
    return entries


def test_declared_frontmatter_scripts_exist():
    """A declared scripts: entry that points at a missing file is a lie the
    dispatcher believes: it selects the declared variant, the existence
    check fails, and the skill cannot run on that platform."""
    declared = 0
    for skill_md in sorted(SKILLS.glob("*/**/SKILL.md")):
        for variant, target in _frontmatter_scripts(skill_md).items():
            path = skill_md.parent / target
            assert path.exists(), (
                f"{skill_md.relative_to(ROOT)}: declared {variant}: {target} does not exist"
            )
            declared += 1
    assert declared >= 6, "frontmatter parser found too few scripts: entries — check the scripts: blocks"


# ── regression: team-init helpers path resolves ─────────────────────────────

def test_team_init_helpers_path_resolves():
    """team-init.sh died at its helpers-not-found check on main: the relative
    path was one level short and resolved inside team-init/."""
    for script, helpers in [
        (SKILLS / "team/team-init/scripts/bash/team-init.sh",
         "../../../team-levelup/scripts/bash/helpers.sh"),
        (SKILLS / "team/team-init/scripts/powershell/team-init.ps1",
         "../../../team-levelup/scripts/powershell/helpers.ps1"),
    ]:
        assert script.exists(), f"{script} missing"
        resolved = (script.parent / helpers).resolve()
        assert resolved.is_file(), f"{script.name}: helpers path {helpers} does not resolve"


# ── regression: score-confidence survives a missing confidence entry ───────

def test_score_confidence_missing_entry_uses_default(tmp_path):
    """A CDR id with no entry in the confidence file must take the documented
    1.0 default (success_rate 1.0 > 0.8 → ×1.2), not abort the script."""
    cdr = tmp_path / "CDR-042.md"
    cdr.write_text(
        "### Target Module: `src/x.py`\n"
        "### Context Type: Rule\n"
        "### Descriptor: something\n",
        encoding="utf-8",
    )
    scores = tmp_path / "scores.json"
    scores.write_text('{"CDR-001": { "success_rate": 0.75 }}\n', encoding="utf-8")
    result = subprocess.run(
        ["bash", str(LEVELUP / "bash/score-confidence.sh"), "--calculate", str(cdr), str(scores)],
        capture_output=True, text=True,
    )
    # Rule base 0.60 + src/ evidence 0.10 = 0.70, default multiplier 1.2 → 0.84
    assert result.returncode == 0, f"aborted: {result.stderr}"
    assert result.stdout.strip() == "0.84 HIGH"


def test_score_confidence_matched_entry(tmp_path):
    cdr = tmp_path / "CDR-001.md"
    cdr.write_text(
        "### Target Module: `src/x.py`\n"
        "### Context Type: Rule\n"
        "### Descriptor: something\n",
        encoding="utf-8",
    )
    scores = tmp_path / "scores.json"
    scores.write_text('{"CDR-001": { "success_rate": 0.75 }}\n', encoding="utf-8")
    result = subprocess.run(
        ["bash", str(LEVELUP / "bash/score-confidence.sh"), "--calculate", str(cdr), str(scores)],
        capture_output=True, text=True,
    )
    # 0.75 is neither >0.8 nor <0.5 → multiplier 1.0 → 0.70 MEDIUM
    assert result.returncode == 0, f"aborted: {result.stderr}"
    assert result.stdout.strip() == "0.70 MEDIUM"


# ── levelup sandbox: bare --next-cdr + twin parity ──────────────────────────

@pytest.fixture()
def levelup_sandbox(tmp_path):
    """Project repo + directives repo with an adlc orphan branch (CDR-007 is
    the highest number, so the next CDR is 008)."""
    project = tmp_path / "project"
    project.mkdir()
    directives = tmp_path / "directives"
    directives.mkdir()

    def git(repo, *args):
        subprocess.run(["git", *args], cwd=repo, capture_output=True, check=True)

    for repo in (project, directives):
        git(repo, "init", "-q")
        git(repo, "config", "user.name", "Test User")
        git(repo, "config", "user.email", "test@example.com")
        git(repo, "config", "commit.gpgsign", "false")

    (project / "README.md").write_text("p\n", encoding="utf-8")
    git(project, "add", "-A")
    git(project, "commit", "-qm", "init")
    (project / ".adlc").mkdir()
    (project / ".adlc/init-options.json").write_text(
        f'{{"team_ai_directives": "{directives}"}}', encoding="utf-8"
    )

    (directives / "README.md").write_text("d\n", encoding="utf-8")
    git(directives, "add", "-A")
    git(directives, "commit", "-qm", "init")
    git(directives, "checkout", "-q", "--orphan", "adlc")
    git(directives, "rm", "-qrf", ".")
    (directives / "drafts/cdr").mkdir(parents=True)
    (directives / "drafts/cdr/CDR-007.md").write_text(
        "### Target Module: `src/b.py`\n### Context Type: Example\n", encoding="utf-8"
    )
    git(directives, "add", "-A")
    git(directives, "commit", "-qm", "cdrs")
    return project, directives


def test_helpers_bare_next_cdr_resolves_paths(levelup_sandbox):
    """Bare --next-cdr used to abort: the CLI entry read $TEAM_AI_DIRECTIVES
    before any resolve call and set -u killed the script."""
    project, _ = levelup_sandbox
    result = subprocess.run(
        ["bash", str(LEVELUP / "bash/helpers.sh"), "--next-cdr"],
        cwd=project, capture_output=True, text=True,
    )
    assert result.returncode == 0, f"aborted: {result.stderr}"
    assert result.stdout.strip() == "008"


requires_pwsh = pytest.mark.skipif(
    shutil.which("pwsh") is None or shutil.which("git") is None,
    reason="pwsh/git not installed (CI runs the twin)",
)


@requires_pwsh
def test_helpers_signal_gate_twin_parity(tmp_path):
    """signal-gate: both twins agree on PASS, on every skip reason, and on a
    missing file (bash grep on a missing file fires only 'no evidence')."""
    good = tmp_path / "good.md"
    good.write_text("Evidence: src/foo.py commit abc\n", encoding="utf-8")
    bad = tmp_path / "bad.md"
    bad.write_text("project-specific, duplicate of X, low value\n", encoding="utf-8")
    for target in (good, bad, tmp_path / "no-such.md"):
        outs = {}
        for name, script in [
            ("sh", LEVELUP / "bash/helpers.sh"),
            ("ps", LEVELUP / "powershell/helpers.ps1"),
        ]:
            cmd = ["bash", str(script)] if name == "sh" else ["pwsh", "-NoProfile", "-File", str(script)]
            result = subprocess.run(
                [*cmd, "--signal-gate", str(target)], capture_output=True, text=True,
            )
            outs[name] = (result.returncode, result.stdout.strip())
        assert outs["sh"] == outs["ps"], f"{target.name}: twins diverge: {outs}"


@requires_pwsh
def test_helpers_next_cdr_twin_parity(levelup_sandbox):
    project, _ = levelup_sandbox
    outs = {}
    for name, script in [
        ("sh", LEVELUP / "bash/helpers.sh"),
        ("ps", LEVELUP / "powershell/helpers.ps1"),
    ]:
        cmd = ["bash", str(script)] if name == "sh" else ["pwsh", "-NoProfile", "-File", str(script)]
        result = subprocess.run(
            [*cmd, "--next-cdr"], cwd=project, capture_output=True, text=True,
        )
        outs[name] = (result.returncode, result.stdout.strip())
    assert outs["sh"] == outs["ps"], f"twins diverge: {outs}"
    assert outs["sh"][1] == "008"
