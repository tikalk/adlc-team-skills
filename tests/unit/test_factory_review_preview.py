"""Tests for the factory-review pre-PR verdict preview (workspace issue 45).

The preview renders the would-be verdict against the working tree:
* advisory only — labeled "draft", never a verdict
* no head=<sha> marker, no outcome=, no important=
* no tracker writes, read-only passes reused (listed, not executed)
* missing provenance is requested, no verdict produced

Every test below FAILS on the pre-implementation tree (the preview script
and its graders do not exist yet) and PASSES once implemented.
"""

import json
import os
import re
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).parent.parent.parent
SKILL = ROOT / "skills/factory/factory-review"
PREVIEW_SH = SKILL / "scripts/bash/review-preview.sh"
PREVIEW_PS = SKILL / "scripts/powershell/review-preview.ps1"

PREVIEW_TWINS = [(("bash"), PREVIEW_SH)] + (
    [(("pwsh"), PREVIEW_PS)] if shutil.which("pwsh") else []
)

DRAFT_LABEL = "draft"
MARKER_TOKENS = ("head=", "outcome=", "important=", "factory-review:step=review")


# ── helpers ──────────────────────────────────────────────────────────────


def run_preview(script, cwd, input_text=None):
    """Run one preview twin; return CompletedProcess."""
    if script.suffix == ".sh":
        cmd = ["bash", str(script)]
    else:
        cmd = ["pwsh", "-NoProfile", "-File", str(script)]
    return subprocess.run(
        cmd, input=input_text, capture_output=True, text=True, timeout=30, cwd=cwd
    )


def seed_tree(tmp_path, files):
    """Create a scratch git tree with the given files committed."""
    tree = tmp_path / "tree"
    tree.mkdir()
    subprocess.run(
        ["git", "init", "-q"], cwd=tree, capture_output=True, check=True
    )
    subprocess.run(
        ["git", "config", "user.email", "test@test"],
        cwd=tree,
        capture_output=True,
        check=True,
    )
    subprocess.run(
        ["git", "config", "user.name", "Test"], cwd=tree, capture_output=True, check=True
    )
    for name, content in files.items():
        p = tree / name
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(content, encoding="utf-8")
    subprocess.run(["git", "add", "-A"], cwd=tree, capture_output=True, check=True)
    subprocess.run(
        ["git", "commit", "-q", "-m", "seed"],
        cwd=tree,
        capture_output=True,
        check=True,
    )
    return tree


def run_preview_on_tree(script, tree):
    """Run the preview against a tree path, from a neutral caller cwd."""
    return subprocess.run(
        ["bash", str(script), str(tree)] if script.suffix == ".sh"
        else ["pwsh", "-NoProfile", "-File", str(script), str(tree)],
        capture_output=True, text=True, timeout=30,
    )


# ── A. script exists ─────────────────────────────────────────────────────


def test_preview_bash_script_exists():
    assert PREVIEW_SH.exists(), f"preview bash script missing: {PREVIEW_SH}"


def test_preview_powershell_twin_exists():
    assert PREVIEW_PS.exists(), f"preview pwsh twin missing: {PREVIEW_PS}"


# ── B. draft labeling + non-verdict ─────────────────────────────────────


def test_preview_produces_draft_label(tmp_path):
    tree = seed_tree(tmp_path, {"src/foo.py": "print(1)\n"})
    proc = run_preview_on_tree(PREVIEW_SH, tree)
    assert proc.returncode == 0, proc.stderr
    assert re.search(r"\bdraft\b", proc.stdout, re.IGNORECASE), (
        "preview output must be explicitly labeled draft"
    )


def test_preview_no_verdict_marker(tmp_path):
    tree = seed_tree(tmp_path, {"src/foo.py": "print(1)\n"})
    proc = run_preview_on_tree(PREVIEW_SH, tree)
    combined = proc.stdout + proc.stderr
    for token in MARKER_TOKENS:
        assert token not in combined, (
            f"preview must not carry verdict token {token!r}: {combined!r}"
        )


def test_preview_not_head_bound(tmp_path):
    tree = seed_tree(tmp_path, {"src/foo.py": "print(1)\n"})
    proc = run_preview_on_tree(PREVIEW_SH, tree)
    assert "head=" not in (proc.stdout + proc.stderr), (
        "preview must not bind to a head SHA"
    )


# ── C. read-only, no tracker writes ─────────────────────────────────────


def test_preview_read_only_exits_zero(tmp_path):
    tree = seed_tree(tmp_path, {"src/foo.py": "print(1)\n"})
    proc = run_preview_on_tree(PREVIEW_SH, tree)
    assert proc.returncode == 0, proc.stderr


def test_preview_no_tracker_write_commands(tmp_path):
    tree = seed_tree(tmp_path, {"src/foo.py": "print(1)\n"})
    proc = run_preview_on_tree(PREVIEW_SH, tree)
    combined = proc.stdout + proc.stderr
    for pat in ("glab mr", "glab issue", "gh pr", "gh api", "create_pull_request_review"):
        assert pat not in combined, (
            f"preview must not issue tracker write command {pat!r}: {combined!r}"
        )


def test_preview_does_not_modify_working_tree(tmp_path):
    tree = seed_tree(tmp_path, {"src/foo.py": "print(1)\n"})
    before = subprocess.run(
        ["git", "status", "--porcelain"], cwd=tree, capture_output=True, text=True
    ).stdout
    proc = run_preview_on_tree(PREVIEW_SH, tree)
    assert proc.returncode == 0, proc.stderr
    after = subprocess.run(
        ["git", "status", "--porcelain"], cwd=tree, capture_output=True, text=True
    ).stdout
    assert before == after, "preview must not modify the working tree"


def test_preview_lists_pass_names_as_structural_checks(tmp_path):
    """Preview lists all six pass names as structural checks only.

    The preview does NOT execute the passes; it lists their names with
    "structural check only" annotations. This test asserts the listing is
    present and does not claim execution.
    """
    tree = seed_tree(tmp_path, {"src/foo.py": "print(1)\n"})
    proc = run_preview_on_tree(PREVIEW_SH, tree)
    assert proc.returncode == 0, proc.stderr
    combined = proc.stdout.lower()
    for pass_name in ("bugs", "security", "spec-compliance", "test-integrity", "ci-integrity", "quality"):
        assert pass_name in combined, f"preview must list the {pass_name} pass"
    assert "structural check only" in combined, (
        "preview must describe passes as structural checks only, not executed"
    )
    # Must NOT claim execution
    assert "passes executed" not in combined, "preview must not claim passes executed"
    assert "were executed" not in combined, "preview must not claim passes were executed"
    assert "ran successfully" not in combined, "preview must not claim passes ran successfully"


# ── D. changed-file detection ───────────────────────────────────────────


def test_preview_detects_modified_tracked_file(tmp_path):
    tree = seed_tree(tmp_path, {"src/foo.py": "original\n"})
    (tree / "src" / "foo.py").write_text("modified\n", encoding="utf-8")
    proc = run_preview_on_tree(PREVIEW_SH, tree)
    assert "src/foo.py" in proc.stdout, "modified tracked file must appear in changed files"


def test_preview_detects_staged_file(tmp_path):
    tree = seed_tree(tmp_path, {"src/foo.py": "original\n"})
    (tree / "src" / "foo.py").write_text("staged\n", encoding="utf-8")
    subprocess.run(["git", "add", "src/foo.py"], cwd=tree, capture_output=True, check=True)
    proc = run_preview_on_tree(PREVIEW_SH, tree)
    assert "src/foo.py" in proc.stdout, "staged file must appear in changed files"


def test_preview_detects_unstaged_file(tmp_path):
    tree = seed_tree(tmp_path, {"src/foo.py": "original\n"})
    (tree / "src" / "foo.py").write_text("unstaged\n", encoding="utf-8")
    proc = run_preview_on_tree(PREVIEW_SH, tree)
    assert "src/foo.py" in proc.stdout, "unstaged file must appear in changed files"


def test_preview_detects_untracked_file(tmp_path):
    tree = seed_tree(tmp_path, {"src/foo.py": "print(1)\n"})
    (tree / "src" / "untracked_new.py").write_text("new\n", encoding="utf-8")
    proc = run_preview_on_tree(PREVIEW_SH, tree)
    assert "untracked_new.py" in proc.stdout, "untracked file must appear in changed files"


def test_preview_detects_deleted_file(tmp_path):
    tree = seed_tree(tmp_path, {"src/foo.py": "print(1)\n", "src/bar.py": "print(2)\n"})
    (tree / "src" / "bar.py").unlink()
    proc = run_preview_on_tree(PREVIEW_SH, tree)
    assert "bar.py" in proc.stdout, "deleted file must appear in changed files"


def test_preview_detects_renamed_file(tmp_path):
    tree = seed_tree(tmp_path, {"src/foo.py": "print(1)\n"})
    subprocess.run(["git", "mv", "src/foo.py", "src/renamed.py"], cwd=tree, capture_output=True, check=True)
    proc = run_preview_on_tree(PREVIEW_SH, tree)
    assert "renamed.py" in proc.stdout, "renamed file must appear in changed files"


def test_preview_detects_path_with_spaces(tmp_path):
    tree = seed_tree(tmp_path, {"src/foo.py": "print(1)\n"})
    (tree / "my dir").mkdir(parents=True, exist_ok=True)
    (tree / "my dir" / "file with spaces.py").write_text("spaced\n", encoding="utf-8")
    proc = run_preview_on_tree(PREVIEW_SH, tree)
    assert "file with spaces.py" in proc.stdout, "path with spaces must appear in changed files"


def test_preview_clean_working_tree_shows_none(tmp_path):
    tree = seed_tree(tmp_path, {"src/foo.py": "print(1)\n"})
    proc = run_preview_on_tree(PREVIEW_SH, tree)
    assert "(none)" in proc.stdout, "clean tree must show '(none)' for changed files"


def test_preview_invoked_from_different_caller_directory(tmp_path):
    tree = seed_tree(tmp_path, {"src/foo.py": "print(1)\n"})
    (tree / "src" / "bar.py").write_text("bar\n", encoding="utf-8")
    # Run from a neutral cwd, passing the tree as argument
    neutral = tmp_path / "neutral"
    neutral.mkdir()
    proc = subprocess.run(
        ["bash", str(PREVIEW_SH), str(tree)],
        cwd=str(neutral), capture_output=True, text=True, timeout=30,
    )
    assert proc.returncode == 0, proc.stderr
    assert "bar.py" in proc.stdout, "must detect changes in target tree from different cwd"
    assert str(tree) in proc.stdout, "must report the target tree path"


# ── E. provenance intake ────────────────────────────────────────────────


def test_preview_provenance_missing_requested(tmp_path):
    tree = seed_tree(tmp_path, {"src/foo.py": "print(1)\n"})
    proc = run_preview_on_tree(PREVIEW_SH, tree)
    combined = proc.stdout + proc.stderr
    assert "provenance" in combined.lower(), "preview must mention provenance"
    assert (
        "missing" in combined.lower() or "request" in combined.lower()
    ), "preview must request missing provenance"
    assert "no verdict is produced" in combined.lower(), (
        "preview must state no verdict is produced until provenance is provided"
    )


def test_preview_provenance_present_acknowledged(tmp_path):
    tree = seed_tree(
        tmp_path,
        {
            "src/foo.py": "print(1)\n",
            "PROVENANCE.md": "src/foo.py: implemented by factory-review run abc (agent-authored)\n",
        },
    )
    proc = run_preview_on_tree(PREVIEW_SH, tree)
    assert proc.returncode == 0, proc.stderr
    combined = proc.stdout + proc.stderr
    assert "provenance: detected" in combined.lower(), (
        "preview must acknowledge present provenance"
    )
    assert "provenance file" in combined.lower(), (
        "preview must identify provenance file as source"
    )


def test_preview_provenance_content_reference_detected(tmp_path):
    """File content contains provenance reference but filename does not."""
    tree = seed_tree(tmp_path, {"src/foo.py": "PROVENANCE: src/foo.py implemented by factory-review run abc\n"})
    (tree / "src" / "foo.py").write_text("modified with PROVENANCE reference\n", encoding="utf-8")
    proc = run_preview_on_tree(PREVIEW_SH, tree)
    combined = proc.stdout + proc.stderr
    assert "provenance: detected" in combined.lower(), (
        "preview must detect provenance reference in file content"
    )
    assert "reference in" in combined.lower(), (
        "preview must identify the file containing the reference"
    )


def test_preview_filename_alone_is_not_provenance(tmp_path):
    """Filename containing 'provenance' without content reference is a false positive."""
    tree = seed_tree(tmp_path, {"src/provenance_notes.txt": "random notes about something else\n"})
    (tree / "src" / "provenance_notes.txt").write_text("unrelated content\n", encoding="utf-8")
    proc = run_preview_on_tree(PREVIEW_SH, tree)
    combined = proc.stdout + proc.stderr
    assert "missing" in combined.lower(), (
        "filename match alone must not count as provenance"
    )


def test_preview_empty_provenance_file_is_missing(tmp_path):
    """Empty PROVENANCE.md is not valid provenance."""
    tree = seed_tree(tmp_path, {"src/foo.py": "print(1)\n", "PROVENANCE.md": ""})
    proc = run_preview_on_tree(PREVIEW_SH, tree)
    combined = proc.stdout + proc.stderr
    assert "missing" in combined.lower(), (
        "empty PROVENANCE.md must be treated as missing provenance"
    )


def test_preview_whitespace_only_provenance_is_missing(tmp_path):
    """Whitespace-only PROVENANCE.md is not valid provenance."""
    tree = seed_tree(tmp_path, {"src/foo.py": "print(1)\n", "PROVENANCE.md": "   \n   \n"})
    proc = run_preview_on_tree(PREVIEW_SH, tree)
    combined = proc.stdout + proc.stderr
    assert "missing" in combined.lower(), (
        "whitespace-only PROVENANCE.md must be treated as missing provenance"
    )


def test_preview_normal_content_provenance_is_detected(tmp_path):
    """Normal PROVENANCE.md content counts as present provenance.

    Regression: the PowerShell twin used '[^[:space:]]', which is not a
    whitespace class in .NET regex, so it missed normal content. Both
    twins must treat ordinary non-whitespace content as present.
    """
    tree = seed_tree(
        tmp_path,
        {
            "src/foo.py": "print(1)\n",
            "PROVENANCE.md": "src/foo.py: implemented by factory-review run abc\n",
        },
    )
    proc = run_preview_on_tree(PREVIEW_SH, tree)
    combined = proc.stdout + proc.stderr
    assert "provenance: detected" in combined.lower(), (
        "normal PROVENANCE.md content must be treated as present provenance"
    )


def test_preview_never_blocks_exit_zero(tmp_path):
    tree = seed_tree(tmp_path, {"src/foo.py": "print(1)\n"})
    proc = run_preview_on_tree(PREVIEW_SH, tree)
    assert proc.returncode == 0, "preview must exit 0 even when provenance is missing"


# ── F. marker-token injection protection ────────────────────────────────


def test_preview_marker_injection_head_sha_directory(tmp_path):
    """Directory name containing head=<40hex> must not inject a verdict marker."""
    tree_dir = tmp_path / "head=abcdef0123456789abcdef0123456789abcdef0123"
    tree_dir.mkdir()
    subprocess.run(["git", "init", "-q"], cwd=tree_dir, capture_output=True, check=True)
    subprocess.run(["git", "config", "user.email", "t@t"], cwd=tree_dir, capture_output=True, check=True)
    subprocess.run(["git", "config", "user.name", "T"], cwd=tree_dir, capture_output=True, check=True)
    (tree_dir / "file.py").write_text("content\n", encoding="utf-8")
    subprocess.run(["git", "add", "-A"], cwd=tree_dir, capture_output=True, check=True)
    subprocess.run(["git", "commit", "-q", "-m", "seed"], cwd=tree_dir, capture_output=True, check=True)
    proc = run_preview_on_tree(PREVIEW_SH, tree_dir)
    combined = proc.stdout + proc.stderr
    # The sanitized label must not contain a raw head=<40hex> token
    assert "head=abcdef0123456789abcdef0123456789abcdef0123" not in combined, (
        "directory name containing head=<sha> must be sanitized in output"
    )
    assert "head=<sha>" in combined, "sanitized label must appear instead"


def test_preview_marker_injection_outcome_directory(tmp_path):
    """Directory name containing outcome= must not inject a verdict marker."""
    tree_dir = tmp_path / "outcome=merge-ready"
    tree_dir.mkdir()
    subprocess.run(["git", "init", "-q"], cwd=tree_dir, capture_output=True, check=True)
    subprocess.run(["git", "config", "user.email", "t@t"], cwd=tree_dir, capture_output=True, check=True)
    subprocess.run(["git", "config", "user.name", "T"], cwd=tree_dir, capture_output=True, check=True)
    (tree_dir / "file.py").write_text("content\n", encoding="utf-8")
    subprocess.run(["git", "add", "-A"], cwd=tree_dir, capture_output=True, check=True)
    subprocess.run(["git", "commit", "-q", "-m", "seed"], cwd=tree_dir, capture_output=True, check=True)
    proc = run_preview_on_tree(PREVIEW_SH, tree_dir)
    combined = proc.stdout + proc.stderr
    assert "outcome=merge-ready" not in combined, (
        "directory name containing outcome= must be sanitized in output"
    )
    assert "outcome=<value>" in combined, "sanitized label must appear instead"


# ── G. malicious Git configuration protection ───────────────────────────


def test_preview_resists_core_fsmonitor_command_execution(tmp_path):
    """Malicious core.fsmonitor must not execute attacker commands."""
    tree = seed_tree(tmp_path, {"src/foo.py": "print(1)\n"})
    marker = tmp_path / "fsmonitor_executed"
    subprocess.run(
        ["git", "config", "core.fsmonitor", f"touch {marker}"],
        cwd=tree, capture_output=True, check=True,
    )
    proc = run_preview_on_tree(PREVIEW_SH, tree)
    assert proc.returncode == 0, proc.stderr
    assert not marker.exists(), (
        "core.fsmonitor command must not be executed by safe git invocation"
    )


# ── H. Bash / PowerShell twin parity ────────────────────────────────────


@pytest.mark.skipif(not shutil.which("pwsh"), reason="pwsh not installed locally")
def test_preview_pwsh_twin_parity_provenance_missing(tmp_path):
    """Both twins produce equivalent output when provenance is missing."""
    tree = seed_tree(tmp_path, {"src/foo.py": "print(1)\n"})
    bash_out = run_preview_on_tree(PREVIEW_SH, tree).stdout
    ps_out = subprocess.run(
        ["pwsh", "-NoProfile", "-File", str(PREVIEW_PS), str(tree)],
        capture_output=True, text=True, timeout=30,
    ).stdout
    assert "draft" in bash_out.lower() and "draft" in ps_out.lower()
    assert "missing" in bash_out.lower() and "missing" in ps_out.lower()
    # Both must report no provenance marker tokens
    for token in MARKER_TOKENS:
        assert token not in bash_out, f"bash must not carry {token!r}"
        assert token not in ps_out, f"pwsh must not carry {token!r}"


@pytest.mark.skipif(not shutil.which("pwsh"), reason="pwsh not installed locally")
def test_preview_pwsh_twin_parity_provenance_present(tmp_path):
    """Both twins produce equivalent output when provenance is present."""
    tree = seed_tree(
        tmp_path,
        {
            "src/foo.py": "print(1)\n",
            "PROVENANCE.md": "src/foo.py: implemented by factory-review run abc\n",
        },
    )
    bash_out = run_preview_on_tree(PREVIEW_SH, tree).stdout
    ps_out = subprocess.run(
        ["pwsh", "-NoProfile", "-File", str(PREVIEW_PS), str(tree)],
        capture_output=True, text=True, timeout=30,
    ).stdout
    assert "draft" in bash_out.lower() and "draft" in ps_out.lower()
    assert "provenance: detected" in bash_out.lower() and "provenance: detected" in ps_out.lower()
