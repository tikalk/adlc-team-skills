"""Preview renders the draft merge-risk section (Task 5 of the merge-risk plan).

Caller-supplied risk evidence renders verbatim as an advisory draft
(`**Merge risk: <band> (draft)**` + the five rows); without evidence every
row reports `unverified: reviewer procedure not invoked` — honest output,
same pattern as the six passes. The preview NEVER carries a head marker,
outcome= or important= (existing envelope tests pin that).

TDD RED step: the scripts render no risk section today, so these FAIL here.
"""
import re
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).parent.parent.parent
SKILL = ROOT / "skills/factory/factory-review"
PREVIEW_SH = SKILL / "scripts/bash/review-preview.sh"
PREVIEW_PS = SKILL / "scripts/powershell/review-preview.ps1"

ROWS = ["Verification", "Alignment", "Impact", "Rollback cost", "Error detection"]

needs_bash = pytest.mark.skipif(shutil.which("bash") is None, reason="needs bash")
needs_pwsh = pytest.mark.skipif(shutil.which("pwsh") is None, reason="needs pwsh")
needs_pwsh_node = pytest.mark.skipif(
    shutil.which("pwsh") is None, reason="needs pwsh")


def seed_tree(tmp_path, files):
    tree = tmp_path / "tree"
    tree.mkdir()
    subprocess.run(["git", "init", "-q"], cwd=tree, capture_output=True, check=True)
    subprocess.run(["git", "config", "user.email", "t@t"], cwd=tree, capture_output=True, check=True)
    subprocess.run(["git", "config", "user.name", "T"], cwd=tree, capture_output=True, check=True)
    for name, content in files.items():
        p = tree / name
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(content, encoding="utf-8")
    subprocess.run(["git", "add", "-A"], cwd=tree, capture_output=True, check=True)
    subprocess.run(["git", "commit", "-q", "-m", "seed"], cwd=tree, capture_output=True, check=True)
    return tree


def risk_evidence(tmp_path):
    rows = "\n".join(f"risk: {r} | good | src/x.py:1" for r in ROWS)
    f = tmp_path / "risk-evidence.md"
    f.write_text(f"merge-risk: low\n\n{rows}\n", encoding="utf-8")
    return f


@needs_bash
def test_preview_renders_supplied_risk_draft(tmp_path):
    tree = seed_tree(tmp_path, {"src/foo.py": "print(1)\n"})
    ev = risk_evidence(tmp_path)
    r = subprocess.run(["bash", str(PREVIEW_SH), str(tree), "--evidence-file", str(ev)],
                       capture_output=True, text=True, timeout=30)
    assert r.returncode == 0, r.stderr
    assert "**Merge risk: low (draft)**" in r.stdout, r.stdout
    for row in ROWS:
        assert row in r.stdout, f"risk draft missing row {row}"


@needs_bash
def test_preview_without_evidence_reports_five_unverified_risk_rows(tmp_path):
    tree = seed_tree(tmp_path, {"src/foo.py": "print(1)\n"})
    r = subprocess.run(["bash", str(PREVIEW_SH), str(tree)],
                       capture_output=True, text=True, timeout=30)
    assert r.returncode == 0, r.stderr
    low = r.stdout.lower()
    assert "merge risk" in low, "preview must name the merge-risk section"
    for row in ROWS:
        assert row.lower() in low, f"risk section missing row {row}"
    assert low.count("unverified") >= 5, "each of the five rows must be unverified without evidence"


@needs_bash
def test_preview_risk_draft_never_carries_outcome_or_head(tmp_path):
    tree = seed_tree(tmp_path, {"src/foo.py": "print(1)\n"})
    ev = risk_evidence(tmp_path)
    r = subprocess.run(["bash", str(PREVIEW_SH), str(tree), "--evidence-file", str(ev)],
                       capture_output=True, text=True, timeout=30)
    assert r.returncode == 0, r.stderr
    assert "outcome=" not in r.stdout and "head=" not in r.stdout, \
        "risk draft must not inject verdict tokens (sanitizer)"


@needs_pwsh
def test_preview_pwsh_parity_on_risk_draft(tmp_path):
    tree = seed_tree(tmp_path, {"src/foo.py": "print(1)\n"})
    ev = risk_evidence(tmp_path)
    a = subprocess.run(["bash", str(PREVIEW_SH), str(tree), "--evidence-file", str(ev)],
                       capture_output=True, text=True, timeout=30)
    b = subprocess.run(["pwsh", "-NoProfile", "-File", str(PREVIEW_PS), str(tree),
                        "-EvidenceFile", str(ev)],
                       capture_output=True, text=True, timeout=30)
    assert a.returncode == 0 and b.returncode == 0, (a.stderr, b.stderr)
    for needle in ["**Merge risk: low (draft)**", *ROWS]:
        assert needle in b.stdout, f"pwsh preview missing {needle}"
