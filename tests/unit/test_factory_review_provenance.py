"""Provenance intake gating for factory-review pre-PR preview (workspace issue 45).

Provenance ("which files came from where" + AI-contribution-policy compliance)
joins evidence intake. When provenance is missing, the preview requests it and
produces no verdict. When present, the preview acknowledges it.

A textual provenance reference is detected but NOT validated as complete or
compliant — the format of formal provenance is governed by the owner sign-off
path and is not defined here.

These tests FAIL on the pre-implementation tree and PASS once implemented.
"""

import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).parent.parent.parent
PREVIEW_SH = ROOT / "skills/factory/factory-review/scripts/bash/review-preview.sh"


def run_preview(tree, input_text=None):
    return subprocess.run(
        ["bash", str(PREVIEW_SH), str(tree)],
        input=input_text,
        capture_output=True,
        text=True,
        timeout=30,
    )


def seed_tree(tmp_path, files):
    tree = tmp_path / "tree"
    tree.mkdir()
    subprocess.run(["git", "init", "-q"], cwd=tree, capture_output=True, check=True)
    subprocess.run(
        ["git", "config", "user.email", "t@t"], cwd=tree, capture_output=True, check=True
    )
    subprocess.run(
        ["git", "config", "user.name", "T"], cwd=tree, capture_output=True, check=True
    )
    for name, content in files.items():
        p = tree / name
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(content, encoding="utf-8")
    subprocess.run(["git", "add", "-A"], cwd=tree, capture_output=True, check=True)
    subprocess.run(
        ["git", "commit", "-q", "-m", "seed"], cwd=tree, capture_output=True, check=True
    )
    return tree


def test_provenance_missing_requests_and_no_verdict(tmp_path):
    tree = seed_tree(tmp_path, {"src/foo.py": "print(1)\n"})
    proc = run_preview(tree)
    assert proc.returncode == 0, proc.stderr
    combined = proc.stdout + proc.stderr
    assert "provenance" in combined.lower(), "preview must mention provenance"
    assert (
        "missing" in combined.lower() or "request" in combined.lower()
    ), "preview must request missing provenance"
    assert "no verdict is produced" in combined.lower(), (
        "preview must state no verdict is produced until provenance is provided"
    )


def test_provenance_present_acknowledged(tmp_path):
    tree = seed_tree(
        tmp_path,
        {
            "src/foo.py": "print(1)\n",
            "PROVENANCE.md": "src/foo.py: implemented by factory-review run abc (agent-authored)\n",
        },
    )
    proc = run_preview(tree)
    assert proc.returncode == 0, proc.stderr
    combined = proc.stdout + proc.stderr
    assert "provenance: detected" in combined.lower(), (
        "preview must acknowledge present provenance"
    )
    assert "provenance file" in combined.lower(), (
        "preview must identify provenance file as source"
    )


def test_provenance_content_reference_detected(tmp_path):
    """File content contains provenance reference but filename does not."""
    tree = seed_tree(tmp_path, {"src/foo.py": "print(1)\n"})
    (tree / "src" / "foo.py").write_text("modified with PROVENANCE reference\n", encoding="utf-8")
    proc = run_preview(tree)
    combined = proc.stdout + proc.stderr
    assert "provenance: detected" in combined.lower(), (
        "preview must detect provenance reference in file content"
    )


def test_provenance_filename_alone_is_not_provenance(tmp_path):
    """Filename containing 'provenance' without content reference is a false positive."""
    tree = seed_tree(tmp_path, {"src/provenance_notes.txt": "random notes about something else\n"})
    (tree / "src" / "provenance_notes.txt").write_text("unrelated content\n", encoding="utf-8")
    proc = run_preview(tree)
    combined = proc.stdout + proc.stderr
    assert "missing" in combined.lower(), (
        "filename match alone must not count as provenance"
    )


def test_provenance_empty_file_is_missing(tmp_path):
    """Empty PROVENANCE.md is not valid provenance."""
    tree = seed_tree(tmp_path, {"src/foo.py": "print(1)\n", "PROVENANCE.md": ""})
    proc = run_preview(tree)
    combined = proc.stdout + proc.stderr
    assert "missing" in combined.lower(), (
        "empty PROVENANCE.md must be treated as missing provenance"
    )


def test_provenance_whitespace_only_is_missing(tmp_path):
    """Whitespace-only PROVENANCE.md is not valid provenance."""
    tree = seed_tree(tmp_path, {"src/foo.py": "print(1)\n", "PROVENANCE.md": "   \n   \n"})
    proc = run_preview(tree)
    combined = proc.stdout + proc.stderr
    assert "missing" in combined.lower(), (
        "whitespace-only PROVENANCE.md must be treated as missing provenance"
    )


def test_provenance_never_blocks_exit_zero(tmp_path):
    tree = seed_tree(tmp_path, {"src/foo.py": "print(1)\n"})
    proc = run_preview(tree)
    assert proc.returncode == 0, "preview must exit 0 even when provenance is missing"
