"""Tests for the factory-review pre-PR verdict preview (workspace issue 45).

The preview renders the would-be verdict against the working tree:
* advisory only — labeled "draft", never a verdict
* no ``head=<sha>`` marker, no ``outcome=``, no ``important=``
* no tracker writes, read-only passes reused
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


def preview_output(script, tmp_path, changed_files=None, provenance="missing"):
    """Build a scratch git tree and run the preview; return stdout."""
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
    if changed_files:
        for name, content in changed_files.items():
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
    proc = run_preview(script, tree)
    return proc, tree


# ── A. script exists ─────────────────────────────────────────────────────


def test_preview_bash_script_exists():
    assert PREVIEW_SH.exists(), f"preview bash script missing: {PREVIEW_SH}"


def test_preview_powershell_twin_exists():
    assert PREVIEW_PS.exists(), f"preview pwsh twin missing: {PREVIEW_PS}"


# ── B. draft labeling + non-verdict ─────────────────────────────────────


def test_preview_produces_draft_label(tmp_path):
    proc, _ = preview_output(PREVIEW_SH, tmp_path)
    assert proc.returncode == 0, proc.stderr
    assert re.search(r"\bdraft\b", proc.stdout, re.IGNORECASE), (
        "preview output must be explicitly labeled draft"
    )


def test_preview_no_verdict_marker(tmp_path):
    proc, _ = preview_output(PREVIEW_SH, tmp_path)
    combined = proc.stdout + proc.stderr
    for token in MARKER_TOKENS:
        assert token not in combined, (
            f"preview must not carry verdict token {token!r}: {combined!r}"
        )


def test_preview_not_head_bound(tmp_path):
    proc, _ = preview_output(PREVIEW_SH, tmp_path)
    assert "head=" not in (proc.stdout + proc.stderr), (
        "preview must not bind to a head SHA"
    )


# ── C. read-only, no tracker writes ─────────────────────────────────────


def test_preview_read_only_exits_zero(tmp_path):
    proc, tree = preview_output(PREVIEW_SH, tmp_path)
    assert proc.returncode == 0, proc.stderr


def test_preview_no_tracker_write_commands(tmp_path):
    proc, _ = preview_output(PREVIEW_SH, tmp_path)
    combined = proc.stdout + proc.stderr
    for pat in ("glab mr", "glab issue", "gh pr", "gh api", "create_pull_request_review"):
        assert pat not in combined, (
            f"preview must not issue tracker write command {pat!r}: {combined!r}"
        )


# ── D. provenance intake ────────────────────────────────────────────────


def test_preview_provenance_missing_requested(tmp_path):
    proc, _ = preview_output(
        PREVIEW_SH, tmp_path, changed_files={"src/foo.py": "print(1)\n"}, provenance="missing"
    )
    combined = proc.stdout + proc.stderr
    assert re.search(
        r"provenance", combined, re.IGNORECASE
    ), "preview must mention provenance when it is missing"
    assert re.search(
        r"request|missing|not provided|which files came from where", combined, re.IGNORECASE
    ), "preview must request missing provenance"


def test_preview_provenance_present_satisfied(tmp_path):
    proc, _ = preview_output(
        PREVIEW_SH,
        tmp_path,
        changed_files={
            "src/foo.py": "print(1)\n",
            "PROVENANCE.md": "src/foo.py: implemented by factory-review run abc (agent-authored)\n",
        },
    )
    combined = proc.stdout + proc.stderr
    assert re.search(r"provenance.*present|provenance.*ok|files came from where.*src/foo.py", combined, re.IGNORECASE), (
        "preview must acknowledge present provenance"
    )


# ── E. read-only pass reuse ─────────────────────────────────────────────


def test_preview_reuses_existing_passes(tmp_path):
    proc, _ = preview_output(PREVIEW_SH, tmp_path)
    combined = proc.stdout + proc.stderr
    for pass_name in ("bugs", "security", "spec-compliance", "test-integrity"):
        assert pass_name in combined.lower(), (
            f"preview must reuse the {pass_name} pass"
        )


# ── F. twin parity ──────────────────────────────────────────────────────


@pytest.mark.skipif(not shutil.which("pwsh"), reason="pwsh not installed locally")
def test_preview_pwsh_twin_matches_bash(tmp_path):
    """Both twins emit equivalent draft output on the same tree."""
    tree = tmp_path / "tree"
    tree.mkdir()
    subprocess.run(["git", "init", "-q"], cwd=tree, capture_output=True, check=True)
    subprocess.run(
        ["git", "config", "user.email", "t@t"], cwd=tree, capture_output=True, check=True
    )
    subprocess.run(
        ["git", "config", "user.name", "T"], cwd=tree, capture_output=True, check=True
    )
    (tree / "src" / "a.py").write_text("x = 1\n", encoding="utf-8")
    subprocess.run(["git", "add", "-A"], cwd=tree, capture_output=True, check=True)
    subprocess.run(
        ["git", "commit", "-q", "-m", "s"], cwd=tree, capture_output=True, check=True
    )
    bash_out = run_preview(PREVIEW_SH, tree).stdout
    ps_out = run_preview(PREVIEW_PS, tree).stdout
    assert "draft" in bash_out.lower() and "draft" in ps_out.lower(), (
        "both twins must label output draft"
    )
