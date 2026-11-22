"""Deterministic merge-risk scorer twins (Task 2 of the merge-risk plan).

Goldens for the weighted scorer: Score = sum(score*weight)/sum(weights), weights
Impact 2x, Verification 2x, Rollback 1.5x, Error detection 1x, Alignment 1x;
mapping poor=1/decent=2/good=3; bands high score<1.5 / medium 1.5-<2.25 /
low score>=2.25 (lower score = higher risk; integer cutoffs num<=22 /
23..33 / num>=34 on num=(4sv+2sa+4si+3sr+2se), score=num/15).
Numeric score stays internal — only the band is printed.

TDD RED step: scripts do not exist yet, so every case FAILS here.
"""
import shutil
import subprocess
from pathlib import Path

import pytest

REVIEW = Path(__file__).parent.parent.parent / "skills/factory/factory-review"
BASH = REVIEW / "scripts/bash/merge-risk.sh"
PS = REVIEW / "scripts/powershell/merge-risk.ps1"

needs_bash = pytest.mark.skipif(shutil.which("bash") is None, reason="needs bash")
needs_pwsh = pytest.mark.skipif(shutil.which("pwsh") is None, reason="needs pwsh")

CASES = [
    # (name, argv-classes, expected band)
    ("all-good", ["good"] * 5, "low"),                       # score 3.0
    ("all-poor", ["poor"] * 5, "high"),                       # score 1.0
    ("all-decent", ["decent"] * 5, "medium"),                 # score 2.0
    ("impact-poor-rest-good", ["good", "good", "poor", "good", "good"], "low"),
    # num = 12+6+4+9+6 = 37 -> 37/15 = 2.4667 -> low (a lone 2x poor cannot sink four goods)
    ("two-heavy-poor", ["poor", "good", "poor", "good", "good"], "medium"),
    # num = 4+6+4+9+6 = 29 -> 29/15 = 1.9333 -> medium (both 2x weights bite)
    ("three-poor", ["poor", "good", "poor", "poor", "good"], "medium"),
    # num = 4+6+4+3+6 = 23 -> 23/15 = 1.5333 -> medium (just above the 1.5 floor)
    ("three-poor-one-decent", ["poor", "decent", "poor", "poor", "good"], "high"),
    # num = 4+4+4+3+6 = 21 -> 21/15 = 1.4 -> high (below the 1.5 floor)
    # Boundary goldens: 22.5/33.75 are unattainable integers, so these pin
    # both sides of each cutoff (high<=22 / 23..33 medium / low>=34).
    ("cutoff-22-high", ["poor", "poor", "poor", "decent", "good"], "high"),
    # num: sv=1,sa=1,si=1,sr=2,se=3 -> 4+2+4+6+6 = 22 -> 1.4667 -> high (cutoff floor).
    ("cutoff-23-medium", ["poor", "poor", "poor", "good", "decent"], "medium"),
    # num: sv=1,sa=1,si=1,sr=3,se=2 -> 4+2+4+9+4 = 23 -> 1.5333 -> medium (just above the 1.5 floor).
    ("cutoff-33-medium", ["poor", "poor", "good", "good", "good"], "medium"),
    # num = 4+2+12+9+6 = 33 -> 33/15 = 2.2 -> medium (just below the 2.25 ceiling).
    ("cutoff-34-low", ["poor", "good", "good", "decent", "good"], "low"),
    # num = 4+6+12+6+6 = 34 -> 34/15 = 2.2667 -> low (cutoff ceiling).
]

FLAGS = ["--verification", "--alignment", "--impact", "--rollback", "--error-detection"]


def argv(classes):
    out = []
    for flag, cls in zip(FLAGS, classes):
        out += [flag, cls]
    return out


def run_bash(classes):
    return subprocess.run(["bash", str(BASH), *argv(classes)], capture_output=True, text=True)


def run_ps(classes):
    return subprocess.run(["pwsh", "-NoProfile", "-File", str(PS), *argv(classes)],
                          capture_output=True, text=True)


@needs_bash
@pytest.mark.parametrize("name, classes, band", CASES, ids=[c[0] for c in CASES])
def test_bash_scorer_goldens(name, classes, band):
    r = run_bash(classes)
    assert r.returncode == 0, r.stderr
    assert f"Merge risk: {band}" in r.stdout, r.stdout


@needs_pwsh
@pytest.mark.parametrize("name, classes, band", CASES, ids=[c[0] for c in CASES])
def test_pwsh_scorer_matches_bash(name, classes, band):
    a, b = run_bash(classes), run_ps(classes)
    assert a.returncode == 0 and b.returncode == 0, (a.stderr, b.stderr)
    assert f"Merge risk: {band}" in b.stdout, b.stdout
    assert [l for l in a.stdout.splitlines() if l.startswith("Merge risk:")] == \
           [l for l in b.stdout.splitlines() if l.startswith("Merge risk:")]


@needs_bash
def test_bash_scorer_is_deterministic():
    first = run_bash(["good", "decent", "poor", "good", "decent"])
    second = run_bash(["good", "decent", "poor", "good", "decent"])
    assert first.returncode == 0 and first.stdout == second.stdout


@needs_bash
def test_bash_scorer_rejects_bad_class():
    r = subprocess.run(["bash", str(BASH), "--verification", "excellent",
                        "--alignment", "good", "--impact", "good",
                        "--rollback", "good", "--error-detection", "good"],
                       capture_output=True, text=True)
    assert r.returncode == 2


@needs_bash
def test_bash_scorer_rejects_missing_value():
    # Regression: `${2:-}` + `shift 2` on a missing value never advanced the
    # loop (exit 124 under timeout). `req` fails closed instead.
    r = subprocess.run(["bash", str(BASH), "--verification"],
                       capture_output=True, text=True, timeout=10)
    assert r.returncode == 2


@needs_pwsh
def test_pwsh_scorer_rejects_bad_class():
    r = run_ps(["excellent", "good", "good", "good", "good"])
    assert r.returncode == 2


@needs_pwsh
def test_pwsh_scorer_rejects_missing_value():
    r = subprocess.run(["pwsh", "-NoProfile", "-File", str(PS), "--verification"],
                       capture_output=True, text=True, timeout=30)
    assert r.returncode == 2
