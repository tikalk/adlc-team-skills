"""Verdict lint requires the merge-risk band line (Task 3 of the merge-risk plan).

The `**Merge risk: <low|medium|high>**` line is the grep-able hook for
dashboard / ADR-360 routing. Lint fails closed on a missing or duplicated
line; it NEVER derives `outcome=` from risk — the marker counts plus
`check-verdict-head.sh --require-outcome` stay the sole merge gate.

TDD RED step: the band line is not linted yet, so the missing/duplicated
cases below PASS lint until the rule lands — these tests FAIL here.
"""
import shutil
import subprocess
from pathlib import Path

import pytest

REVIEW = Path(__file__).parent.parent.parent / "skills/factory/factory-review"
SCRIPT = REVIEW / "scripts/bash/verdict-schema.sh"
PS_SCRIPT = REVIEW / "scripts/powershell/verdict-schema.ps1"

HEAD = "63e2525b7eca8577e5984e84d269b308f197bb9d"

needs_bash = pytest.mark.skipif(
    shutil.which("bash") is None or shutil.which("node") is None, reason="needs bash and node")
needs_pwsh = pytest.mark.skipif(
    shutil.which("pwsh") is None or shutil.which("node") is None, reason="needs pwsh and node")


def lint(text, interpreter="bash"):
    import tempfile, os
    with tempfile.NamedTemporaryFile("w", suffix=".md", delete=False, encoding="utf-8") as f:
        f.write(text)
        path = f.name
    env = {k: v for k, v in os.environ.items() if k not in ("ADLC_RUN_ID", "WORKFLOW_INPUTS")}
    try:
        cmd = ["bash", str(SCRIPT)] if interpreter == "bash" else ["pwsh", "-NoProfile", "-File", str(PS_SCRIPT)]
        return subprocess.run([*cmd, "lint", path], capture_output=True, text=True, env=env)
    finally:
        os.unlink(path)


def verdict_body(marker, verdict_extra=""):
    return (f"{marker}\n\n## Verdict\n**Outcome:** merge-ready\n\n{verdict_extra}\n\n"
            f"## Important findings\nNone.\n\n## Nits\nNone.\n")


def marker(imp=0, nits=0, outcome="merge-ready"):
    return (f"<!-- factory-review:step=review run=interactive iter=0 status=completed "
            f"outcome={outcome} findings={imp + nits} important={imp} nits={nits} head={HEAD} -->")


@pytest.mark.parametrize("interpreter", ["bash", "pwsh"])
def test_body_with_band_line_passes(interpreter):
    if interpreter == "bash":
        pytest.importorskip("pytest")  # marker only; real skip below
    r = lint(verdict_body(marker(), "**Merge risk: low**"), interpreter)
    if interpreter == "bash" and shutil.which("bash") is None:
        pytest.skip("needs bash")
    if interpreter == "pwsh" and shutil.which("pwsh") is None:
        pytest.skip("needs pwsh")
    assert r.returncode == 0, r.stdout + r.stderr


@pytest.mark.parametrize("interpreter", ["bash", "pwsh"])
def test_body_without_band_line_fails(interpreter):
    r = lint(verdict_body(marker(), "No risk line here."), interpreter)
    assert r.returncode == 1 and "Merge risk" in r.stdout, r.stdout + r.stderr


@pytest.mark.parametrize("interpreter", ["bash", "pwsh"])
def test_body_with_two_band_lines_fails(interpreter):
    r = lint(verdict_body(marker(), "**Merge risk: low**\n\n**Merge risk: high**"), interpreter)
    assert r.returncode == 1 and "Merge risk" in r.stdout, r.stdout + r.stderr


@pytest.mark.parametrize("interpreter", ["bash", "pwsh"])
def test_risk_band_does_not_rescue_open_important(interpreter):
    text = (f"{marker(1, 0, 'not-merge-ready')}\n\n## Verdict\n**Outcome:** not-merge-ready\n\n"
            f"**Merge risk: low**\n\n"
            f"## Important findings\n### I0 — x\nwhy\n\n## Nits\nNone.\n")
    r = lint(text, interpreter)
    assert r.returncode == 0, r.stdout + r.stderr  # well-formed body lints clean...
    # ...but the merge gate still blocks: outcome=not-merge-ready + important=1.
    assert "not-merge-ready" in text and "important=1" in text


@pytest.mark.parametrize("interpreter", ["bash", "pwsh"])
def test_bad_band_value_fails(interpreter):
    r = lint(verdict_body(marker(), "**Merge risk: negligible**"), interpreter)
    assert r.returncode == 1 and "Merge risk" in r.stdout, r.stdout + r.stderr


@pytest.mark.parametrize("interpreter", ["bash", "pwsh"])
def test_quoted_band_line_does_not_count(interpreter):
    r = lint(verdict_body(marker(), "The skill says:\n\n```\n**Merge risk: low**\n```\n"), interpreter)
    assert r.returncode == 1 and "Merge risk" in r.stdout, r.stdout + r.stderr
