"""Factory workflow contract: shipped workflows match the skills in this repo.

The CLI's bundled copy of the factory workflow drifted from these skills
twice (the publish helpers moved to factory-runbook; factory-intent replaced
factory-product / factory-architect), and its publish
steps were silently skipped. The workflow now ships with factory-runbook,
and this suite pins:

- every shipped workflow*.yml: each `command:` is a skill in this repo, and
  each helper a shell step runs through run-helpers.sh exists (bash and
  PowerShell twin);
- the factory workflow layout (one factory-intent step, two intent gates,
  gate-architecture `since: run_start`, both linking the publish step);
- run-helpers.sh fails closed on a missing helper.
"""

import os
import re
import shutil
import stat
import subprocess
from pathlib import Path

import pytest
import yaml

ROOT = Path(__file__).parent.parent.parent
SKILLS = ROOT / "skills"
RUNBOOK = SKILLS / "factory" / "factory-runbook"
FACTORY = RUNBOOK / "workflow.yml"
RUN_HELPERS = RUNBOOK / "scripts" / "bash" / "run-helpers.sh"
RUN_HELPERS_RE = re.compile(r"\.agents/skills/([\w-]+)/scripts/bash/run-helpers\.sh\s+([\w-]+)((?:\s+[\w.-]+)+)")

WORKFLOWS = sorted(SKILLS.glob("**/workflow*.yml"))
SKILL_NAMES = {p.parent.name for p in SKILLS.glob("*/*/SKILL.md")}


def walk(steps):
    """Every step, including those nested in control steps."""
    for step in steps or []:
        if not isinstance(step, dict):
            continue
        yield step
        for value in step.values():
            if isinstance(value, list) and value and isinstance(value[0], dict):
                yield from walk(value)
            elif isinstance(value, dict):
                for nested in value.values():
                    if isinstance(nested, list) and nested and isinstance(nested[0], dict):
                        yield from walk(nested)


def load(path):
    return yaml.safe_load(path.read_text(encoding="utf-8"))


def all_steps(doc):
    return list(walk(doc.get("steps") or (doc.get("workflow") or {}).get("steps")))


def test_workflows_are_found():
    assert FACTORY in WORKFLOWS, "skills/factory/factory-runbook/workflow.yml must exist"
    assert len(WORKFLOWS) >= 2


@pytest.mark.parametrize("path", WORKFLOWS, ids=lambda p: str(p.relative_to(SKILLS)))
def test_every_command_is_a_skill_in_this_repo(path):
    missing = [s["command"] for s in all_steps(load(path)) if s.get("command") and s["command"] not in SKILL_NAMES]
    assert not missing, f"{path.relative_to(ROOT)} runs commands with no skill here: {missing}"


@pytest.mark.parametrize("path", WORKFLOWS, ids=lambda p: str(p.relative_to(SKILLS)))
def test_no_removed_orchestrators(path):
    commands = {s.get("command") for s in all_steps(load(path))}
    assert not commands & {"factory-product", "factory-architect"}, "replaced by factory-intent"


@pytest.mark.parametrize("path", WORKFLOWS, ids=lambda p: str(p.relative_to(SKILLS)))
def test_every_helper_a_shell_step_runs_exists(path):
    for step in all_steps(load(path)):
        run = step.get("run")
        if not isinstance(run, str):
            continue
        calls = RUN_HELPERS_RE.findall(run)
        if "run-helpers.sh" in run:
            assert calls, f"{step.get('id')}: unparseable run-helpers call: {run!r}"
        for skill, _label, names in calls:
            base = SKILLS / "factory" / skill / "scripts"
            for name in names.split():
                assert (base / "bash" / name).is_file(), f"{step.get('id')}: {skill}/scripts/bash/{name} missing"
                twin = base / "powershell" / (Path(name).stem + ".ps1")
                assert twin.is_file(), f"{step.get('id')}: PowerShell twin {twin.relative_to(ROOT)} missing"


def test_factory_layout():
    doc = load(FACTORY)
    assert doc["workflow"]["id"] == "factory"
    steps = doc["steps"]
    assert [s["id"] for s in steps] == [
        "run-branch", "intent", "publish-intent", "gate-product", "gate-architecture",
        "execute", "gate-completion", "sweep",
    ]
    by_id = {s["id"]: s for s in steps}
    assert by_id["intent"]["command"] == "factory-intent"
    assert by_id["execute"]["command"] == "factory-mission"
    assert by_id["execute"]["input"]["args"] == "--issue {{ inputs.issue_ref }}"
    for sid in ("run-branch", "publish-intent"):
        assert by_id[sid]["type"] == "shell"
        assert "run-helpers.sh" in by_id[sid]["run"], f"{sid} runs its helpers through run-helpers.sh"
    assert "node -e" not in FACTORY.read_text(encoding="utf-8"), "no inline runner"


def test_factory_intent_gates():
    by_id = {s["id"]: s for s in load(FACTORY)["steps"]}
    product, architecture = by_id["gate-product"], by_id["gate-architecture"]
    assert product["context"]["records"] == [".adlc/drafts/pdr/*.md"]
    assert architecture["context"]["records"] == [".adlc/drafts/adr/*.md"]
    # The one intent step writes the ADRs before gate-product is approved;
    # since last_approved would hide them from the architecture gate.
    assert product["context"]["since"] == "last_approved"
    assert architecture["context"]["since"] == "run_start"
    for gate in (product, architecture):
        assert gate["context"]["link"] == "{{ steps.publish-intent.output.mr_url }}"
        assert gate["verdict_input"] == "verdict"
        assert gate["on_reject"] == "abort"
    completion = by_id["gate-completion"]
    assert completion["context"]["link"] == "{{ steps.execute.output.mr_url | default(inputs.mr_url) }}"


def test_factory_declares_runner_inputs():
    inputs = load(FACTORY)["inputs"]
    for name in ("verdict", "mr_url", "issue_ref", "dispatch"):
        assert name in inputs, f"factory must declare input {name} (undeclared inputs are dropped)"


# ── run-helpers.sh behaviour ────────────────────────────────────────────────

BASH = shutil.which("bash")
needs_bash = pytest.mark.skipif(BASH is None, reason="bash not available")


def copy_runner(tmp_path):
    bash_dir = tmp_path / "scripts" / "bash"
    bash_dir.mkdir(parents=True)
    runner = bash_dir / "run-helpers.sh"
    shutil.copy(RUN_HELPERS, runner)
    return bash_dir, runner


def helper(bash_dir, name, body):
    p = bash_dir / name
    p.write_text("#!/usr/bin/env bash\n" + body + "\n", encoding="utf-8")
    p.chmod(p.stat().st_mode | stat.S_IEXEC)


def run(runner, *args, env=None):
    return subprocess.run([BASH, str(runner), *args], capture_output=True, text=True, env={**os.environ, **(env or {})})


@needs_bash
def test_runner_fails_closed_on_a_missing_helper(tmp_path):
    bash_dir, runner = copy_runner(tmp_path)
    helper(bash_dir, "run-branch.sh", "echo ran-branch")
    r = run(runner, "publish", "run-branch.sh", "open-mr.sh")
    assert r.returncode == 1
    assert "ran-branch" in r.stdout, "helpers before the missing one still run"
    assert "publish: open-mr.sh not found" in r.stderr


@needs_bash
def test_runner_runs_helpers_in_order_with_the_environment(tmp_path):
    bash_dir, runner = copy_runner(tmp_path)
    out = tmp_path / "order.txt"
    helper(bash_dir, "a.sh", f'echo "a $ADLC_RUN_ID" >> "{out}"')
    helper(bash_dir, "b.sh", f'echo "b $ADLC_RUN_ID" >> "{out}"')
    r = run(runner, "publish", "a.sh", "b.sh", env={"ADLC_RUN_ID": "r1"})
    assert r.returncode == 0, r.stderr
    assert out.read_text(encoding="utf-8").splitlines() == ["a r1", "b r1"]


@needs_bash
def test_runner_returns_a_helpers_exit_code_and_stops(tmp_path):
    bash_dir, runner = copy_runner(tmp_path)
    helper(bash_dir, "open-mr.sh", "echo 'open-mr: not on an intent run branch' >&2; exit 2")
    helper(bash_dir, "after.sh", "echo should-not-run")
    r = run(runner, "publish", "open-mr.sh", "after.sh")
    assert r.returncode == 2
    assert "not on an intent run branch" in r.stderr
    assert "should-not-run" not in r.stdout


@needs_bash
@pytest.mark.parametrize("bad", ["../run-branch.sh", "sub/x.sh", ".hidden.sh"])
def test_runner_refuses_paths_outside_its_directory(tmp_path, bad):
    _, runner = copy_runner(tmp_path)
    r = run(runner, "publish", bad)
    assert r.returncode == 2
    assert "invalid helper name" in r.stderr


@needs_bash
def test_runner_usage(tmp_path):
    _, runner = copy_runner(tmp_path)
    assert run(runner, "publish").returncode == 2


# ── the factory's intent gates match factory-intent's own gates ─────────────
# In a factory run the factory-intent skill runs inside one `intent` step and
# never asks; the factory's gate-product / gate-architecture are its approval.
# Run alone, factory-intent's workflows gate with their own steps. Both must
# approve the same records with the same answers, so the two definitions
# cannot drift apart. (link and on_reject differ by design: the factory links
# its publish step's MR and aborts; a standalone intent run retries its lane.)

INTENT = SKILLS / "factory" / "factory-intent"
LANE_GLOB = {"product": ".adlc/drafts/pdr/*.md", "architecture": ".adlc/drafts/adr/*.md"}


def intent_gates():
    """(workflow file, gate id, lane, gate) for every gate factory-intent ships."""
    found = []
    for path in sorted(INTENT.glob("workflow*.yml")):
        for step in all_steps(load(path)):
            if step.get("type") != "gate":
                continue
            records = (step.get("context") or {}).get("records") or []
            lanes = [lane for lane, glob in LANE_GLOB.items() if glob in records]
            assert len(lanes) == 1, f"{path.name}:{step['id']} must gate exactly one lane, got {records}"
            found.append((path.name, step["id"], lanes[0], step))
    return found


def test_factory_intent_ships_a_gate_per_lane():
    lanes = {lane for _f, _id, lane, _g in intent_gates()}
    assert lanes == {"product", "architecture"}


@pytest.mark.parametrize("lane,factory_gate", [("product", "gate-product"), ("architecture", "gate-architecture")])
def test_factory_intent_gate_matches_factory_intent(lane, factory_gate):
    outer = {s["id"]: s for s in load(FACTORY)["steps"]}[factory_gate]
    for name, gate_id, gate_lane, gate in intent_gates():
        if gate_lane != lane:
            continue
        where = f"{name}:{gate_id} vs factory {factory_gate}"
        assert gate["context"]["records"] == outer["context"]["records"], f"{where}: record scope differs"
        assert gate["options"] == outer["options"], f"{where}: answer options differ"
