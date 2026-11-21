"""Run-context resolution for raw lane runs (SF-SKILL-03).

Review runs and autonomous missions are raw agent runs: the Argo lane starts
the agent directly, adlc-cli never runs, so ADLC_RUN_ID is unset and the
factory-runbook helpers used to no-op ("no run context — skipped"). Agents
then invented run ids of their own (octopus-next!1322 was opened under
`run mission-1517-manual`). The lane sets WORKFLOW_INPUTS on every runner pod;
run-context.sh / run-context.ps1 adopt its run_id. These tests pin the
resolution order, the validation, the twin parity, that the three helpers act
in a raw lane run, and the skill text that tells the agent about it.
"""
import json
import os
import shutil
import subprocess
from pathlib import Path

import pytest

from test_intent_run_helpers import (
    GLAB,
    STEP_ARGS,
    fake_cli,
    git,
    write,
)

ROOT = Path(__file__).parent.parent.parent
RUNBOOK = ROOT / "skills/factory/factory-runbook"
BASH_DIR = RUNBOOK / "scripts/bash"
PS_DIR = RUNBOOK / "scripts/powershell"
SCRIPT = BASH_DIR / "run-context.sh"
PS_SCRIPT = PS_DIR / "run-context.ps1"
MISSION = ROOT / "skills/factory/factory-mission/SKILL.md"
BRIEF = ROOT / "skills/mission/mission-brief/SKILL.md"
RUNBOOK_MD = RUNBOOK / "SKILL.md"
RUN_CONTEXT_MD = RUNBOOK / "references/run-context.md"

LANE_RUN_ID = "94a98df0-f8c9-4ef8-92da-5c2b06e2d2f1"
LANE_INPUTS = json.dumps({
    "issue_ref": "tikalk/engineering/octopus-next#1517",
    "run_id": LANE_RUN_ID,
    "dispatch": "autonomous",
})
CONTEXT_VARS = ("ADLC_RUN_ID", "ADLC_ISSUE_REF", "ADLC_STEP_OUTPUT", "WORKFLOW_INPUTS")

needs_node = pytest.mark.skipif(shutil.which("node") is None, reason="the resolver parses JSON with node")
needs_pwsh = pytest.mark.skipif(shutil.which("pwsh") is None or shutil.which("node") is None,
                                reason="needs pwsh and node (CI runs it)")


def clean_env(extra=None):
    env = {k: v for k, v in os.environ.items() if k not in CONTEXT_VARS}
    env.update(extra or {})
    return env


def resolve(env_extra, *args):
    r = subprocess.run(["bash", str(SCRIPT), *args], capture_output=True, text=True, env=clean_env(env_extra))
    assert r.returncode == 0, r.stderr
    return dict(line.split("=", 1) for line in r.stdout.splitlines())


def resolve_ps(env_extra):
    r = subprocess.run(["pwsh", "-NoProfile", "-File", str(PS_SCRIPT)], capture_output=True, text=True,
                       env=clean_env(env_extra))
    assert r.returncode == 0, r.stderr
    return dict(line.split("=", 1) for line in r.stdout.splitlines())


# ── the resolver ────────────────────────────────────────────────────────────

@pytest.mark.requires_bash
def test_no_context_is_not_a_factory_run():
    assert resolve({}) == {"factory_run": "no", "run_id": "", "issue_ref": "", "source": "none"}


@pytest.mark.requires_bash
def test_adlc_run_id_wins_over_lane_inputs():
    out = resolve({"ADLC_RUN_ID": "7c1446ae", "ADLC_ISSUE_REF": "g/r#3", "WORKFLOW_INPUTS": LANE_INPUTS})
    assert out == {"factory_run": "yes", "run_id": "7c1446ae", "issue_ref": "g/r#3", "source": "adlc"}


@pytest.mark.requires_bash
@needs_node
def test_lane_inputs_are_adopted_in_a_raw_run():
    out = resolve({"WORKFLOW_INPUTS": LANE_INPUTS})
    assert out == {"factory_run": "yes", "run_id": LANE_RUN_ID,
                   "issue_ref": "tikalk/engineering/octopus-next#1517", "source": "lane"}


@pytest.mark.requires_bash
@needs_node
@pytest.mark.parametrize("bad", ["pending", "", "../x", "a b", "-lead", "x\ny"])
def test_placeholder_or_unsafe_run_id_is_ignored(bad):
    out = resolve({"WORKFLOW_INPUTS": json.dumps({"run_id": bad})})
    assert out["factory_run"] == "no" and out["run_id"] == ""


@pytest.mark.requires_bash
@needs_node
def test_review_mr_ref_is_not_an_issue_ref():
    # The review lane passes the MR ref in issue_ref (workflow-template-review.yaml).
    wi = json.dumps({"issue_ref": "tikalk/engineering/octopus-next!1298", "run_id": "d82c9b6f-c5b7"})
    out = resolve({"WORKFLOW_INPUTS": wi})
    assert out["factory_run"] == "yes" and out["run_id"] == "d82c9b6f-c5b7" and out["issue_ref"] == ""


@pytest.mark.requires_bash
@needs_node
@pytest.mark.parametrize("wi", ["issue_ref=x run_id=y", "[]", '"r1"', "null", '{"run_id": 7}'])
def test_malformed_or_non_object_inputs_are_no_context(wi):
    assert resolve({"WORKFLOW_INPUTS": wi})["factory_run"] == "no"


@pytest.mark.requires_bash
def test_extra_arguments_are_a_usage_error():
    r = subprocess.run(["bash", str(SCRIPT), "--json"], capture_output=True, text=True, env=clean_env())
    assert r.returncode == 2 and "usage" in r.stderr


@pytest.mark.requires_bash
@needs_node
def test_sourcing_exports_only_the_resolved_values():
    probe = (f'set -euo pipefail; . "{SCRIPT}"; '
             'printf "%s|%s|%s|%s" "$ADLC_RUN_ID" "$ADLC_ISSUE_REF" "${_adlc_rc_source:-unset}" '
             '"$(declare -F _adlc_rc_resolve || echo gone)"')
    r = subprocess.run(["bash", "-c", probe], capture_output=True, text=True,
                       env=clean_env({"WORKFLOW_INPUTS": LANE_INPUTS}))
    assert r.returncode == 0, r.stderr
    assert r.stdout == f"{LANE_RUN_ID}|tikalk/engineering/octopus-next#1517|unset|gone"


@pytest.mark.requires_bash
def test_sourcing_without_context_sets_nothing():
    probe = f'set -euo pipefail; . "{SCRIPT}"; printf "%s|%s" "${{ADLC_RUN_ID:-none}}" "${{ADLC_ISSUE_REF:-none}}"'
    r = subprocess.run(["bash", "-c", probe], capture_output=True, text=True, env=clean_env())
    assert r.returncode == 0 and r.stdout == "none|none", r.stderr


# ── the PowerShell twin agrees with the bash resolver ──────────────────────

PARITY_CASES = [
    {},
    {"ADLC_RUN_ID": "7c1446ae", "WORKFLOW_INPUTS": LANE_INPUTS},
    {"WORKFLOW_INPUTS": LANE_INPUTS},
    {"WORKFLOW_INPUTS": json.dumps({"issue_ref": "g/r!12", "run_id": "d82c9b6f"})},
    {"WORKFLOW_INPUTS": json.dumps({"issue_ref": "g/../r#1", "run_id": "PENDING"})},
    {"WORKFLOW_INPUTS": json.dumps({"run_id": "pending"})},
    {"WORKFLOW_INPUTS": json.dumps({"run_id": "a b"})},
    {"WORKFLOW_INPUTS": "[]"},
    {"WORKFLOW_INPUTS": "not json"},
    {"ADLC_RUN_ID": "bad id", "WORKFLOW_INPUTS": LANE_INPUTS},
]


@needs_pwsh
@pytest.mark.requires_bash
@pytest.mark.parametrize("case", PARITY_CASES, ids=lambda c: json.dumps(c)[:60])
def test_powershell_twin_resolves_like_bash(case):
    assert resolve_ps(case) == resolve(case)


@needs_pwsh
def test_powershell_dot_source_sets_only_the_resolved_values():
    cmd = (f". '{PS_SCRIPT}'; "
           "Write-Output \"$($env:ADLC_RUN_ID)|$($env:ADLC_ISSUE_REF)|"
           "$([bool](Get-Variable __adlcRc -ErrorAction SilentlyContinue))\"")
    r = subprocess.run(["pwsh", "-NoProfile", "-Command", cmd], capture_output=True, text=True,
                       env=clean_env({"WORKFLOW_INPUTS": LANE_INPUTS}))
    assert r.returncode == 0, r.stderr
    assert r.stdout.strip() == f"{LANE_RUN_ID}|tikalk/engineering/octopus-next#1517|False"


# ── the helpers act in a raw lane run (no ADLC_RUN_ID, only WORKFLOW_INPUTS) ─

RAW_INPUTS = json.dumps({"issue_ref": "g/adlc-workspace#12", "run_id": LANE_RUN_ID, "dispatch": "autonomous"})
CODE_ARGS = ["--orchestrator", "factory-mission", "--step", "plan", "--output-type", "draft",
             "--summary", "one ADR proposal", "--"]


@pytest.fixture
def repo(tmp_path):
    bare = tmp_path / "bare.git"
    subprocess.run(["git", "init", "-q", "--bare", "-b", "main", str(bare)], check=True)
    work = tmp_path / "work"
    work.mkdir()
    git(work, "init", "-q", "-b", "main")
    git(work, "config", "user.email", "bot@t.local")
    git(work, "config", "user.name", "bot")
    git(work, "config", "commit.gpgsign", "false")
    (work / "README.md").write_text("x\n")
    git(work, "add", "-A")
    git(work, "commit", "-q", "-m", "base")
    git(work, "remote", "add", "origin", "https://gl.test/g/adlc-workspace.git")
    git(work, "config", f"url.{bare}.insteadOf", "https://gl.test/g/adlc-workspace.git")
    git(work, "push", "-q", "origin", "main")
    return {"work": work, "bare": bare, "tmp": tmp_path}


def run_helper(interpreter, script, cwd, *args, env=None):
    cmd = ["bash", str(script)] if interpreter == "bash" else ["pwsh", "-NoProfile", "-File", str(script)]
    return subprocess.run([*cmd, *args], cwd=cwd, capture_output=True, text=True, env=clean_env(env))


def raw_lane_publish(repo, interpreter):
    ext = "sh" if interpreter == "bash" else "ps1"
    d = BASH_DIR if interpreter == "bash" else PS_DIR
    w = repo["work"]
    bin_dir = fake_cli(repo["tmp"], "glab", GLAB)
    log = repo["tmp"] / "glab.log"
    env = {"WORKFLOW_INPUTS": RAW_INPUTS, "GITLAB_HOST": "gl.test", "FAKE_LOG": str(log),
           "PATH": f"{bin_dir}{os.pathsep}{os.environ['PATH']}"}

    r = run_helper(interpreter, d / f"run-branch.{ext}", w, "--kind", "code", env=env)
    assert r.returncode == 0, r.stderr
    assert r.stdout.strip() == "factory/mission/adlc-workspace-12"
    assert "no run context" not in r.stderr

    write(w, ".adlc/drafts/adr/ADR-9.md", "a\n")
    r = run_helper(interpreter, d / f"commit-step.{ext}", w, *CODE_ARGS, ".adlc/drafts/adr/ADR-9.md", env=env)
    assert r.returncode == 0, r.stderr
    assert r.stdout.strip() != "sha: none"
    assert f"Run-Id: {LANE_RUN_ID}" in git(w, "log", "-1", "--format=%B")

    r = run_helper(interpreter, d / f"open-mr.{ext}", w, "--kind", "code", env=env)
    assert r.returncode == 0, r.stderr
    assert r.stdout.strip() == "https://gl.test/g/adlc-workspace/-/merge_requests/77"
    bodies = [json.loads(l[len("BODY "):]) for l in log.read_text().splitlines() if l.startswith("BODY ")]
    assert [b["title"] for b in bodies] == [f"Draft: factory: adlc-workspace#12 (run {LANE_RUN_ID})"]
    assert git(repo["bare"], "branch", "--list", "factory/mission/adlc-workspace-12") != ""


@pytest.mark.requires_bash
@pytest.mark.skipif(shutil.which("git") is None or shutil.which("node") is None, reason="needs git and node")
def test_bash_helpers_publish_a_raw_lane_run_under_the_lane_run_id(repo):
    raw_lane_publish(repo, "bash")


@needs_pwsh
def test_powershell_helpers_publish_a_raw_lane_run_under_the_lane_run_id(repo):
    raw_lane_publish(repo, "pwsh")


# ── a review run is a lane run too: the publish helpers stay out of it (SF-FIX-11) ─

# What a review pod has: the lane's run id and a merge-request ref in issue_ref
# (workflow-template-review.yaml). Since SF-SKILL-03 the helpers adopt the lane
# run id, so in a review pod run-branch switched the review checkout to
# factory/intent/run-<uuid> and commit-step / open-mr were live as well.
REVIEW_INPUTS = json.dumps({"issue_ref": "g/adlc-workspace!41", "run_id": LANE_RUN_ID, "dispatch": "autonomous"})


def review_run_is_left_alone(repo, interpreter):
    ext = "sh" if interpreter == "bash" else "ps1"
    d = BASH_DIR if interpreter == "bash" else PS_DIR
    w = repo["work"]
    bin_dir = fake_cli(repo["tmp"], "glab", GLAB)
    log = repo["tmp"] / "glab.log"
    env = {"WORKFLOW_INPUTS": REVIEW_INPUTS, "GITLAB_HOST": "gl.test", "FAKE_LOG": str(log),
           "PATH": f"{bin_dir}{os.pathsep}{os.environ['PATH']}"}
    head = git(w, "rev-parse", "HEAD")

    for kind in ("intent", "code"):
        r = run_helper(interpreter, d / f"run-branch.{ext}", w, "--kind", kind, env=env)
        assert r.returncode == 0, r.stderr
        assert r.stdout.strip() == "" and "skipped" in r.stderr and "review run" in r.stderr
    assert git(w, "branch", "--show-current") == "main"
    assert git(w, "branch", "--list", "factory/*") == ""

    write(w, ".adlc/drafts/adr/ADR-9.md", "a\n")
    r = run_helper(interpreter, d / f"commit-step.{ext}", w, *CODE_ARGS, ".adlc/drafts/adr/ADR-9.md", env=env)
    assert r.returncode == 0, r.stderr
    assert r.stdout.strip() == "sha: none" and "review run" in r.stderr
    assert git(w, "rev-parse", "HEAD") == head

    r = run_helper(interpreter, d / f"open-mr.{ext}", w, "--kind", "code", env=env)
    assert r.returncode == 0, r.stderr
    assert r.stdout.strip() == "" and "skipped" in r.stderr and "review run" in r.stderr
    assert not log.exists(), "no tracker call in a review run"
    assert git(repo["bare"], "branch", "--list", "factory/*") == ""

    # The explicit opt-in still works, and the commit names the real run.
    r = run_helper(interpreter, d / f"commit-step.{ext}", w, *CODE_ARGS[:-1], "--commit", "--",
                   ".adlc/drafts/adr/ADR-9.md", env=env)
    assert r.returncode == 0, r.stderr
    assert r.stdout.strip() != "sha: none"
    assert git(w, "branch", "--show-current") == "main"
    assert f"Run-Id: {LANE_RUN_ID}" in git(w, "log", "-1", "--format=%B")


@pytest.mark.requires_bash
@pytest.mark.skipif(shutil.which("git") is None or shutil.which("node") is None, reason="needs git and node")
def test_bash_helpers_stay_out_of_a_review_run(repo):
    review_run_is_left_alone(repo, "bash")


@needs_pwsh
def test_powershell_helpers_stay_out_of_a_review_run(repo):
    review_run_is_left_alone(repo, "pwsh")


@pytest.mark.requires_bash
@needs_node
@pytest.mark.parametrize("env, source", [
    ({"WORKFLOW_INPUTS": REVIEW_INPUTS}, "lane"),
    ({"WORKFLOW_INPUTS": LANE_INPUTS}, "lane"),
    ({"ADLC_RUN_ID": "7c1446ae", "WORKFLOW_INPUTS": REVIEW_INPUTS}, "adlc"),
    ({}, "none"),
])
def test_sourcing_tells_the_helper_where_the_run_id_came_from(env, source):
    probe = (f'set -euo pipefail; . "{SCRIPT}"; printf "%s|" "$ADLC_RUN_CONTEXT_SOURCE"; '
             'bash -c \'printf "%s" "${ADLC_RUN_CONTEXT_SOURCE:-not-exported}"\'')
    r = subprocess.run(["bash", "-c", probe], capture_output=True, text=True, env=clean_env(env))
    assert r.returncode == 0, r.stderr
    assert r.stdout == f"{source}|not-exported"


@needs_pwsh
def test_powershell_dot_source_tells_the_helper_where_the_run_id_came_from():
    cmd = f". '{PS_SCRIPT}'; Write-Output \"$AdlcRunContextSource|$([bool]$env:AdlcRunContextSource)\""
    r = subprocess.run(["pwsh", "-NoProfile", "-Command", cmd], capture_output=True, text=True,
                       env=clean_env({"WORKFLOW_INPUTS": REVIEW_INPUTS}))
    assert r.returncode == 0, r.stderr
    assert r.stdout.strip() == "lane|False"


def test_run_context_reference_says_the_helpers_skip_a_review_run():
    text = RUN_CONTEXT_MD.read_text(encoding="utf-8")
    assert "In a review run" in text and "no-ops" in text


@pytest.mark.parametrize("helper", ["run-branch", "open-mr", "commit-step"])
def test_every_helper_adopts_the_lane_context_before_its_no_op_check(helper):
    for path, adopt, gate in [
        (BASH_DIR / f"{helper}.sh", '/run-context.sh"', '-n "${ADLC_RUN_ID:-}" ]' if helper == "commit-step"
         else 'if [ -z "${ADLC_RUN_ID:-}" ]; then\n'),
        (PS_DIR / f"{helper}.ps1", "'run-context.ps1')", "$env:ADLC_RUN_ID) -or $force)" if helper == "commit-step"
         else "if (-not $env:ADLC_RUN_ID) {\n"),
    ]:
        text = path.read_text(encoding="utf-8")
        assert adopt in text, f"{path.name} must adopt the run context through run-context"
        assert text.index(adopt) < text.index(gate), f"{path.name}: adopt the run context before the no-op check"


# ── the skill text ──────────────────────────────────────────────────────────

def test_mission_recognises_raw_lane_runs():
    text = MISSION.read_text(encoding="utf-8")
    head = text.index("## In a factory run")
    section = text[head:text.index("## In a local session")]
    assert "factory_run=yes" in section and "raw lane run" in section
    assert "Never set `ADLC_RUN_ID` yourself" in section
    assert "mission-<iid>-manual" in section  # the invented id seen on octopus-next!1322
    assert "(when it is set)" in section  # no ADLC_STEP_OUTPUT in a raw lane run
    local = text[text.index("## In a local session"):text.index("## What this skill does")]
    assert "factory_run=no" in local


def test_mission_brief_does_not_take_a_raw_lane_run_for_a_person():
    text = BRIEF.read_text(encoding="utf-8")
    local = text[text.index("## In a local session"):]
    assert "factory_run=no" in local.split("\n\n", 2)[1]
    assert "never ask there" in local


def test_runbook_names_the_resolver_and_forbids_hand_set_run_ids():
    text = RUNBOOK_MD.read_text(encoding="utf-8")
    assert "scripts/bash/run-context.sh" in text and "WORKFLOW_INPUTS" in text
    assert "never\nset `ADLC_RUN_ID` by hand" in text


def test_run_context_reference_names_both_run_kinds():
    text = RUN_CONTEXT_MD.read_text(encoding="utf-8")
    assert "workflow run" in text and "raw lane run" in text and "WORKFLOW_INPUTS" in text
    assert "Never set\n  `ADLC_RUN_ID` by hand" in text
    assert "scripts/powershell/run-context.ps1" in text
