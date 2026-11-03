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
# A shell step runs its helpers through the workflow's own directory, which
# the engine exports as ADLC_WORKFLOW_DIR: never through an install path.
RUN_HELPERS_RE = re.compile(r'"\$\{ADLC_WORKFLOW_DIR[^}]*\}/scripts/bash/run-helpers\.sh"\s+([\w-]+)((?:\s+[\w.-]+)+)')
INSTALL_PATH_RE = re.compile(r"\.(agents|claude|devin|augment|pi|qwen|junie|goose|kilocode|kiro|qoder|codebuddy|bob|tabnine)/(agent/)?skills/")

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
def test_no_shell_step_hardcodes_an_install_path(path):
    # Skills install per agent (.agents/skills, .claude/skills, ...); a shell
    # step that names one runs in only that layout.
    for step in all_steps(load(path)):
        run = step.get("run")
        if isinstance(run, str):
            assert not INSTALL_PATH_RE.search(run), f"{step.get('id')}: install path in {run!r}; use $ADLC_WORKFLOW_DIR"


@pytest.mark.parametrize("path", WORKFLOWS, ids=lambda p: str(p.relative_to(SKILLS)))
def test_every_helper_a_shell_step_runs_exists(path):
    for step in all_steps(load(path)):
        run = step.get("run")
        if not isinstance(run, str):
            continue
        calls = RUN_HELPERS_RE.findall(run)
        if "run-helpers.sh" in run:
            assert calls, f"{step.get('id')}: run-helpers.sh must be called through ADLC_WORKFLOW_DIR: {run!r}"
        for _label, names in calls:
            base = path.parent / "scripts"
            skill = path.parent.name
            for name in names.split():
                assert (base / "bash" / name).is_file(), f"{step.get('id')}: {skill}/scripts/bash/{name} missing"
                twin = base / "powershell" / (Path(name).stem + ".ps1")
                assert twin.is_file(), f"{step.get('id')}: PowerShell twin {twin.relative_to(ROOT)} missing"


def test_factory_layout():
    doc = load(FACTORY)
    assert doc["workflow"]["id"] == "factory"
    steps = doc["steps"]
    assert [s["id"] for s in steps] == [
        "run-branch", "intent", "publish-intent", "gate-product", "run-branch-architecture",
        "gate-architecture", "execute", "gate-completion", "sweep",
    ]
    by_id = {s["id"]: s for s in steps}
    assert by_id["intent"]["command"] == "factory-intent"
    assert by_id["execute"]["command"] == "factory-mission"
    assert by_id["execute"]["input"]["args"] == "--issue {{ inputs.issue_ref }}"
    # run-branch-architecture: a run parked at gate-product can resume in a
    # fresh clone on the base branch; gate-architecture diffs the working tree.
    for sid in ("run-branch", "publish-intent", "run-branch-architecture"):
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
# cannot drift apart. Three keys differ by design and are not compared:
# link (the factory links its publish step's MR), on_reject (the factory
# aborts, a standalone intent run retries its lane), and since (the factory's
# gate-architecture follows one merged intent step that wrote the ADRs before
# gate-product, hence run_start; a standalone run gates after its own steps).

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


# ── the shell steps work in any install layout ──────────────────────────────

def install_copy(tmp_path, skills_dir, helpers):
    """A copy of factory-runbook's runner under <skills_dir>, with stub helpers."""
    skill = tmp_path / skills_dir / "factory-runbook"
    bash_dir = skill / "scripts" / "bash"
    bash_dir.mkdir(parents=True)
    shutil.copy(RUN_HELPERS, bash_dir / "run-helpers.sh")
    log = tmp_path / "ran.txt"
    for name in helpers:
        helper(bash_dir, name, f'echo "{name}" >> "{log}"')
    return skill, log


SHELL_STEPS = [(s["id"], s["run"]) for s in load(FACTORY)["steps"] if s.get("type") == "shell"]


@needs_bash
@pytest.mark.parametrize("skills_dir", [".agents/skills", ".claude/skills"])
@pytest.mark.parametrize("step_id,run_line", SHELL_STEPS, ids=[i for i, _ in SHELL_STEPS])
def test_shell_step_finds_its_helpers_in_any_layout(tmp_path, skills_dir, step_id, run_line):
    skill, log = install_copy(tmp_path, skills_dir, ["run-branch.sh", "open-mr.sh"])
    r = subprocess.run(["sh", "-c", run_line], cwd=tmp_path, capture_output=True, text=True,
                       env={**os.environ, "ADLC_WORKFLOW_DIR": str(skill)})
    assert r.returncode == 0, r.stderr
    expected = RUN_HELPERS_RE.search(run_line).group(2).split()
    assert log.read_text(encoding="utf-8").split() == expected


@needs_bash
@pytest.mark.parametrize("step_id,run_line", SHELL_STEPS, ids=[i for i, _ in SHELL_STEPS])
def test_shell_step_without_workflow_dir_fails_with_a_reason(tmp_path, step_id, run_line):
    env = {k: v for k, v in os.environ.items() if k != "ADLC_WORKFLOW_DIR"}
    r = subprocess.run(["sh", "-c", run_line], cwd=tmp_path, capture_output=True, text=True, env=env)
    assert r.returncode != 0
    assert "run this workflow by path" in r.stderr


# ── run-helpers.ps1 behaviour (the twin is tested, not just present) ────────

PWSH = shutil.which("pwsh")
needs_pwsh = pytest.mark.skipif(PWSH is None, reason="pwsh not available")
RUN_HELPERS_PS1 = RUNBOOK / "scripts" / "powershell" / "run-helpers.ps1"


def ps_copy(tmp_path):
    ps_dir = tmp_path / "scripts" / "powershell"
    ps_dir.mkdir(parents=True)
    runner = ps_dir / "run-helpers.ps1"
    shutil.copy(RUN_HELPERS_PS1, runner)
    return ps_dir, runner


def ps_run(runner, *args):
    return subprocess.run([PWSH, "-NoProfile", "-File", str(runner), *args], capture_output=True, text=True)


@needs_pwsh
def test_ps_runner_fails_closed_on_a_missing_helper(tmp_path):
    ps_dir, runner = ps_copy(tmp_path)
    (ps_dir / "run-branch.ps1").write_text("Write-Output ran-branch\n", encoding="utf-8")
    r = ps_run(runner, "publish", "run-branch.sh", "open-mr.sh")
    assert r.returncode == 1
    assert "ran-branch" in r.stdout
    assert "publish: open-mr.ps1 not found" in r.stderr


@needs_pwsh
def test_ps_runner_returns_a_helpers_exit_code_and_stops(tmp_path):
    ps_dir, runner = ps_copy(tmp_path)
    (ps_dir / "open-mr.ps1").write_text("[Console]::Error.WriteLine('refused'); exit 2\n", encoding="utf-8")
    (ps_dir / "after.ps1").write_text("Write-Output should-not-run\n", encoding="utf-8")
    r = ps_run(runner, "publish", "open-mr.sh", "after.ps1")
    assert r.returncode == 2
    assert "should-not-run" not in r.stdout


@needs_pwsh
def test_ps_runner_refuses_paths(tmp_path):
    _, runner = ps_copy(tmp_path)
    r = ps_run(runner, "publish", "../x.ps1")
    assert r.returncode == 2
    assert "invalid helper name" in r.stderr
