"""Unit tests for the shared clarify ASCII generator (bash + pwsh parity)."""

import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASH_GEN = ROOT / "skills/authoring/scripts/bash/render-decision-map.sh"
PWSH_GEN = ROOT / "skills/authoring/scripts/powershell/render-decision-map.ps1"

FIXTURE = {
    "id": "PDR-001",
    "title": "Missing metric",
    "what_why": "PDR-001 lacks a success metric.",
    "boundaries": "record",
    "reach": "record=pdr.md index",
    "options": ["A|Add metric|+|Measurable.|-|Needs baseline.|*|?"],
    "if_undecided": "Halt PDR-001.",
}


def run_generator(shell, **kwargs):
    if shell == "bash":
        script = (
            f'source "{BASH_GEN}" && render_decision_map '
            f'"{kwargs["id"]}" "{kwargs["title"]}" "{kwargs["what_why"]}" '
            f'"{kwargs["boundaries"]}" "{kwargs["reach"]}" '
            + " ".join(f'"{o}"' for o in kwargs["options"])
            + f' "{kwargs["if_undecided"]}"'
        )
        out = subprocess.run(["bash", "-c", script], capture_output=True, text=True, check=True)
        return out.stdout
    if shell == "pwsh":
        opt_list = ", ".join(f"'{o}'" for o in kwargs["options"])
        script = (
            f". '{PWSH_GEN}'; "
            f"Render-DecisionMap -Id '{kwargs['id']}' -Title '{kwargs['title']}' "
            f"-WhatWhy '{kwargs['what_why']}' -Boundaries '{kwargs['boundaries']}' "
            f"-Reach '{kwargs['reach']}' -Options @({opt_list}) "
            f"-IfUndecided '{kwargs['if_undecided']}'"
        )
        out = subprocess.run(["pwsh", "-NoProfile", "-Command", script],
                             capture_output=True, text=True, check=True)
        return out.stdout.replace("\r\n", "\n")
    raise ValueError(f"unknown shell: {shell}")


def test_generator_emits_pinned_boxes():
    out = run_generator("bash", **FIXTURE)
    assert out.startswith("+---")
    assert "DECISION MAP: PDR-001" in out
    assert "?" in out  # undrawn slot preserved
    assert max(len(l) for l in out.splitlines()) <= 75


def test_bash_pwsh_parity():
    if shutil.which("pwsh") is None:
        import pytest
        pytest.skip("pwsh not installed")
    bash_out = run_generator("bash", **FIXTURE)
    pwsh_out = run_generator("pwsh", **FIXTURE)
    assert bash_out.splitlines() == pwsh_out.splitlines()


def test_status_box_stays_compact():
    script = (
        f'source "{BASH_GEN}" && render_status_box '
        f'"{FIXTURE["id"]}" "{FIXTURE["title"]}" "{FIXTURE["what_why"]}"'
    )
    out = subprocess.run(["bash", "-c", script], capture_output=True, text=True, check=True).stdout
    assert "CLARIFICATION: PDR-001" in out
    assert max(len(l) for l in out.splitlines()) <= 75
