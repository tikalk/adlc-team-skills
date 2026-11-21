"""A factory mission on a branch other than the default branch (SF-FIX-23).

Until now a mission always cut its work branch from origin's default branch
and opened its merge request into it: `run-branch.sh` asked origin for HEAD,
`open-mr.sh` asked the tracker for `default_branch`. So every end-to-end test
of the factory put a real merge request against `main` of a real project, a
past failure could not be replayed from its commit, and a skills fix could not
be tried before it reached `main`.

The Argo lane can now dispatch a mission against a test branch (issue label
`target-branch::<branch>`): the pod clones that branch and carries
`ADLC_TARGET_BRANCH` (and `WORKFLOW_INPUTS.target_branch`). These tests pin
what the helpers do with it, for both twins (bash always, PowerShell where
pwsh exists — CI runs it):

  target-branch   one resolver: ADLC_TARGET_BRANCH, else
                  WORKFLOW_INPUTS.target_branch; a set target is validated; an
                  invalid one is an error, never "no target".
  run-branch      a new run branch starts from origin/<target>; an existing
                  intent branch is caught up with origin/<target>.
  open-mr         the MR/PR goes INTO the target, on GitLab and GitHub; the
                  empty-run check uses origin/<target>; an open MR/PR that
                  targets another branch is never reused.
  both            a target that is invalid or missing on origin stops the
                  helper with exit 2 — it never falls back to the default
                  branch; without a target the behaviour is what it was.
"""
import json
import os
import shutil
import subprocess
from pathlib import Path

import pytest

from test_intent_run_helpers import (
    GH_FULL,
    GLAB,
    STEP_ARGS,
    fake_cli,
    git,
    posted_body,
    write,
)

ROOT = Path(__file__).parent.parent.parent
RUNBOOK = ROOT / "skills/factory/factory-runbook"
BASH_DIR = RUNBOOK / "scripts/bash"
PS_DIR = RUNBOOK / "scripts/powershell"

TARGET = "factory-test/replay-1"
ORIGIN = "https://gl.test/g/adlc-workspace.git"
RUN_ENV = {"ADLC_RUN_ID": "r26", "ADLC_ISSUE_REF": "g/adlc-workspace#12"}
MISSION = "factory/mission/adlc-workspace-12"
INTENT = "factory/intent/adlc-workspace-12"

pytestmark = pytest.mark.skipif(
    shutil.which("bash") is None or shutil.which("git") is None or shutil.which("node") is None,
    reason="needs bash, git and node",
)
needs_pwsh = pytest.mark.skipif(shutil.which("pwsh") is None, reason="needs pwsh (CI runs it)")


@pytest.fixture(params=["bash", pytest.param("pwsh", marks=needs_pwsh)])
def shell(request):
    return request.param


def helper(shell, name, cwd, *args, env=None):
    """Run one factory-runbook helper with the given twin. ADLC_* and the
    lane's WORKFLOW_INPUTS are the run context: a test run inside a runner pod
    must not inherit the pod's own."""
    full_env = {k: v for k, v in os.environ.items()
                if not k.startswith("ADLC_") and k != "WORKFLOW_INPUTS"}
    full_env.update(env or {})
    if shell == "bash":
        cmd = ["bash", str(BASH_DIR / f"{name}.sh"), *args]
    else:
        cmd = ["pwsh", "-NoProfile", "-File", str(PS_DIR / f"{name}.ps1"), *args]
    return subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, env=full_env)


def commit(work, rel, text, msg):
    write(work, rel, text)
    git(work, "add", "-A")
    git(work, "commit", "-q", "-m", msg)
    return git(work, "rev-parse", "HEAD")


@pytest.fixture
def world(tmp_path):
    """origin as a real test would leave it: `main` has moved on since the old
    commit; the test branch was cut FROM that old commit and carries one commit
    of its own (say, the skills pin under test). `pod` is the runner's clone:
    `git clone --branch <target> --single-branch`, so it knows nothing of main."""
    bare = tmp_path / "bare.git"
    subprocess.run(["git", "init", "-q", "--bare", "-b", "main", str(bare)], check=True)
    seed = tmp_path / "seed"
    seed.mkdir()
    git(seed, "init", "-q", "-b", "main")
    git(seed, "config", "user.email", "seed@t.local")
    git(seed, "config", "user.name", "seed")
    git(seed, "config", "commit.gpgsign", "false")
    old = commit(seed, "README.md", "old\n", "the old commit")
    git(seed, "remote", "add", "origin", str(bare))
    git(seed, "push", "-q", "origin", "main")
    git(seed, "switch", "-q", "-c", TARGET)
    target_tip = commit(seed, "pin.txt", "skills under test\n", "test branch: pin")
    git(seed, "push", "-q", "origin", TARGET)
    git(seed, "switch", "-q", "main")
    main_tip = commit(seed, "main-only.txt", "later\n", "main moved on")
    git(seed, "push", "-q", "origin", "main")
    w = {"bare": bare, "seed": seed, "tmp": tmp_path, "old": old,
         "target_tip": target_tip, "main_tip": main_tip}
    w["pod"] = clone(w, TARGET, "pod")
    return w


def clone(world, branch, name, url=ORIGIN):
    """A runner-pod clone of `branch` whose origin reads as the https URL but
    fetches and pushes the local bare repo (offline)."""
    path = world["tmp"] / name
    subprocess.run(["git", "clone", "-q", "--branch", branch, "--single-branch",
                    str(world["bare"]), str(path)], check=True)
    git(path, "config", "user.email", "bot@t.local")
    git(path, "config", "user.name", "bot")
    git(path, "config", "commit.gpgsign", "false")
    git(path, "remote", "set-url", "origin", url)
    git(path, "config", f"url.{world['bare']}.insteadOf", url)
    return path


def target_env(extra=None):
    env = dict(RUN_ENV, ADLC_TARGET_BRANCH=TARGET)
    env.update(extra or {})
    return env


def has_file(work, rel, rev="HEAD"):
    return subprocess.run(["git", "cat-file", "-e", f"{rev}:{rel}"], cwd=work,
                          capture_output=True).returncode == 0


# ── the resolver ────────────────────────────────────────────────────────────

def resolve(shell, tmp_path, env):
    r = helper(shell, "target-branch", tmp_path, env=env)
    lines = dict(l.split("=", 1) for l in r.stdout.splitlines() if "=" in l)
    return r, lines


def test_no_target_is_an_answer_not_an_error(shell, tmp_path):
    for env in ({}, {"ADLC_TARGET_BRANCH": ""},
                {"WORKFLOW_INPUTS": json.dumps({"issue_ref": "g/x#1", "run_id": "u", "dispatch": "supervised"})},
                {"ADLC_TARGET_BRANCH": "", "WORKFLOW_INPUTS": json.dumps({"target_branch": ""})},
                {"WORKFLOW_INPUTS": "not json"}, {"WORKFLOW_INPUTS": "[1]"}):
        r, lines = resolve(shell, tmp_path, env)
        assert r.returncode == 0, (env, r.stderr)
        assert lines == {"target_branch": "", "source": "none"}, env


def test_target_from_the_environment(shell, tmp_path):
    r, lines = resolve(shell, tmp_path, {"ADLC_TARGET_BRANCH": TARGET})
    assert r.returncode == 0, r.stderr
    assert lines == {"target_branch": TARGET, "source": "env"}


def test_target_from_the_lane_inputs(shell, tmp_path):
    inputs = json.dumps({"issue_ref": "g/x#1", "run_id": "u", "dispatch": "autonomous", "target_branch": TARGET})
    for env in ({"WORKFLOW_INPUTS": inputs}, {"WORKFLOW_INPUTS": inputs, "ADLC_TARGET_BRANCH": ""}):
        r, lines = resolve(shell, tmp_path, env)
        assert r.returncode == 0, r.stderr
        assert lines == {"target_branch": TARGET, "source": "lane"}


def test_both_sources_agreeing_is_fine(shell, tmp_path):
    r, lines = resolve(shell, tmp_path, {"ADLC_TARGET_BRANCH": TARGET,
                                         "WORKFLOW_INPUTS": json.dumps({"target_branch": TARGET})})
    assert r.returncode == 0, r.stderr
    assert lines == {"target_branch": TARGET, "source": "env"}


def test_sources_that_disagree_are_an_error(shell, tmp_path):
    r, lines = resolve(shell, tmp_path, {"ADLC_TARGET_BRANCH": TARGET,
                                         "WORKFLOW_INPUTS": json.dumps({"target_branch": "factory-test/other"})})
    assert r.returncode == 2
    assert "different branches" in r.stderr and r.stdout.strip() == ""


BAD_NAMES = ["../x", "a..b", "factory-test/x.lock", "factory-test/a.lock/b", "factory-test/", "factory-test/x.",
             "-x", ".x", "/x", "factory-test//x", "factory-test/.x", "factory-test/a b", "factory-test/a~b",
             "factory-test/a:b", "factory-test/a^b", "factory-test/a?b", "factory-test/a*b", "factory-test/a[b",
             "factory-test/a\\b", "factory-test/a@{b", "factory-test/$(touch PWNED)", "factory-test/x;touch PWNED",
             "factory-test/x\ny", " ", "factory-test/" + "x" * 200]


@pytest.mark.parametrize("bad", BAD_NAMES)
def test_an_invalid_target_is_an_error_never_no_target(shell, tmp_path, bad):
    for env in ({"ADLC_TARGET_BRANCH": bad}, {"WORKFLOW_INPUTS": json.dumps({"target_branch": bad})}):
        r, lines = resolve(shell, tmp_path, env)
        assert r.returncode == 2, (env, r.stdout)
        assert "invalid target branch" in r.stderr and "refusing to fall back to the default branch" in r.stderr
        assert r.stdout.strip() == "", "nothing a caller could mistake for an answer"
        assert bad.strip() == "" or bad not in r.stderr, "the bad value is not echoed"
        assert not (tmp_path / "PWNED").exists(), "the value is data, never code"


def test_the_longest_plain_name_is_accepted(shell, tmp_path):
    name = "factory-test/" + "x" * 188  # 201 characters
    r, lines = resolve(shell, tmp_path, {"ADLC_TARGET_BRANCH": name})
    assert r.returncode == 0 and lines["target_branch"] == name


@pytest.mark.parametrize("value", [5, None, ["factory-test/x"], {"a": 1}, True])
def test_a_lane_target_that_is_not_a_string_is_an_error(shell, tmp_path, value):
    r, lines = resolve(shell, tmp_path, {"WORKFLOW_INPUTS": json.dumps({"target_branch": value})})
    assert r.returncode == 2
    assert "not a string" in r.stderr and "refusing to fall back" in r.stderr


def test_resolver_takes_no_arguments(shell, tmp_path):
    r = helper(shell, "target-branch", tmp_path, "--x")
    assert r.returncode == 2 and "usage" in r.stderr


def test_resolver_parity_between_the_twins(tmp_path):
    if shutil.which("pwsh") is None:
        pytest.skip("needs pwsh (CI runs it)")
    cases = [{}, {"ADLC_TARGET_BRANCH": TARGET}, {"ADLC_TARGET_BRANCH": "a..b"},
             {"WORKFLOW_INPUTS": json.dumps({"target_branch": TARGET})},
             {"WORKFLOW_INPUTS": json.dumps({"target_branch": 7})}]
    for env in cases:
        a = helper("bash", "target-branch", tmp_path, env=env)
        b = helper("pwsh", "target-branch", tmp_path, env=env)
        assert (a.returncode, a.stdout.split(), a.stderr.strip()) == (b.returncode, b.stdout.split(), b.stderr.strip()), env


# ── run-branch ──────────────────────────────────────────────────────────────

def test_a_new_code_branch_starts_from_the_target_not_the_default(shell, world):
    pod = world["pod"]
    r = helper(shell, "run-branch", pod, "--kind", "code", env=target_env())
    assert r.returncode == 0, r.stderr
    assert r.stdout.strip() == MISSION
    assert git(pod, "branch", "--show-current") == MISSION
    assert git(pod, "rev-parse", "HEAD") == world["target_tip"]
    assert has_file(pod, "pin.txt"), "the test branch's own commit is in"
    assert not has_file(pod, "main-only.txt"), "nothing that landed on main after the old commit"


def test_fail_before_fix_shape_without_the_target_the_branch_comes_from_main(shell, world):
    # The same pod without a target: what every mission did before, and still
    # does — the code branch is cut from origin's default branch.
    pod = world["pod"]
    r = helper(shell, "run-branch", pod, "--kind", "code", env=RUN_ENV)
    assert r.returncode == 0, r.stderr
    assert git(pod, "rev-parse", "HEAD") == world["main_tip"]
    assert has_file(pod, "main-only.txt") and not has_file(pod, "pin.txt")


def test_a_raw_lane_run_reads_the_target_from_workflow_inputs(shell, world):
    # Autonomous missions are raw agent runs: no ADLC_RUN_ID, only the lane's
    # WORKFLOW_INPUTS (and here not even ADLC_TARGET_BRANCH).
    inputs = json.dumps({"issue_ref": "g/adlc-workspace#12", "run_id": "94a98df0-f8c9-4ef8-92da-5c2b06e2d2f1",
                         "dispatch": "autonomous", "target_branch": TARGET})
    pod = world["pod"]
    r = helper(shell, "run-branch", pod, "--kind", "code", env={"WORKFLOW_INPUTS": inputs})
    assert r.returncode == 0, r.stderr
    assert r.stdout.strip() == MISSION
    assert git(pod, "rev-parse", "HEAD") == world["target_tip"]


def test_the_code_branch_leaves_the_intent_drafts_behind_on_a_target_run(shell, world):
    pod = world["pod"]
    assert helper(shell, "run-branch", pod, env=target_env()).returncode == 0
    write(pod, ".adlc/drafts/pdr/PDR-1.md", "draft\n")
    r = helper(shell, "commit-step", pod, *STEP_ARGS, ".adlc/drafts/pdr/PDR-1.md", env=target_env())
    assert r.returncode == 0, r.stderr
    r = helper(shell, "run-branch", pod, "--kind", "code", env=target_env())
    assert r.returncode == 0, r.stderr
    assert git(pod, "rev-parse", "HEAD") == world["target_tip"]
    assert not has_file(pod, ".adlc/drafts/pdr/PDR-1.md")


def test_a_new_intent_branch_starts_from_the_target_whatever_is_checked_out(shell, world):
    work = clone(world, "main", "on-main")  # HEAD is main, the run targets the test branch
    r = helper(shell, "run-branch", work, env=target_env())
    assert r.returncode == 0, r.stderr
    assert r.stdout.strip() == INTENT
    assert git(work, "rev-parse", "HEAD") == world["target_tip"]
    assert not has_file(work, "main-only.txt")


def advance(world, branch, rel, text, msg):
    seed = world["seed"]
    git(seed, "switch", "-q", branch)
    sha = commit(seed, rel, text, msg)
    git(seed, "push", "-q", "origin", branch)
    return sha


def test_an_existing_intent_branch_is_caught_up_with_the_target_not_the_default(shell, world):
    pod = world["pod"]
    assert helper(shell, "run-branch", pod, env=target_env()).returncode == 0
    before = commit(pod, "docs/adlc/intent/adlc-workspace-12.md", "captured\n", "capture")
    git(pod, "push", "-q", "origin", f"refs/heads/{INTENT}:refs/heads/{INTENT}")
    new_target = advance(world, TARGET, "target-later.txt", "t\n", "test branch moved on")
    advance(world, "main", "main-later.txt", "m\n", "main moved on again")
    pod2 = clone(world, TARGET, "pod2")  # the next pod of the same issue
    r = helper(shell, "run-branch", pod2, env=target_env())
    assert r.returncode == 0, r.stderr
    assert git(pod2, "rev-parse", "HEAD^1") == before and git(pod2, "rev-parse", "HEAD^2") == new_target
    assert has_file(pod2, "target-later.txt")
    assert not has_file(pod2, "main-later.txt") and not has_file(pod2, "main-only.txt"), \
        "main is never merged into a test branch's run"


def test_a_code_branch_already_on_origin_is_continued(shell, world):
    pod = world["pod"]
    assert helper(shell, "run-branch", pod, "--kind", "code", env=target_env()).returncode == 0
    head = commit(pod, "src.txt", "c\n", "code")
    git(pod, "push", "-q", "origin", f"refs/heads/{MISSION}:refs/heads/{MISSION}")
    pod2 = clone(world, TARGET, "pod2")  # a resumed or re-dispatched run
    r = helper(shell, "run-branch", pod2, "--kind", "code", env=target_env())
    assert r.returncode == 0, r.stderr
    assert git(pod2, "rev-parse", "HEAD") == head


@pytest.mark.parametrize("kind", [[], ["--kind", "code"]])
def test_run_branch_stops_when_the_target_is_not_on_origin(shell, world, kind):
    pod = world["pod"]
    before = git(pod, "rev-parse", "HEAD")
    r = helper(shell, "run-branch", pod, *kind, env=target_env({"ADLC_TARGET_BRANCH": "factory-test/missing"}))
    assert r.returncode == 2
    assert "factory-test/missing" in r.stderr and "was not found on origin" in r.stderr
    assert "refusing to fall back to the default branch" in r.stderr
    assert r.stdout.strip() == ""
    assert git(pod, "branch", "--show-current") == TARGET and git(pod, "rev-parse", "HEAD") == before
    assert git(pod, "branch", "--list", "factory/*") == "", "no run branch was created"


@pytest.mark.parametrize("env", [{"ADLC_TARGET_BRANCH": "a..b"},
                                 {"ADLC_TARGET_BRANCH": TARGET,
                                  "WORKFLOW_INPUTS": json.dumps({"target_branch": "factory-test/other"})},
                                 {"WORKFLOW_INPUTS": json.dumps({"target_branch": 5})}])
def test_run_branch_stops_on_a_target_it_cannot_trust(shell, world, env):
    pod = world["pod"]
    r = helper(shell, "run-branch", pod, "--kind", "code", env=dict(RUN_ENV, **env))
    assert r.returncode == 2, r.stdout
    assert "run-branch: " in r.stderr and "refusing" in r.stderr
    assert git(pod, "branch", "--list", "factory/*") == ""


def test_a_stray_target_does_nothing_outside_a_factory_run(shell, world):
    # No run context: the helpers stay no-ops, even with a broken value around.
    pod = world["pod"]
    for name in ("run-branch", "open-mr"):
        r = helper(shell, name, pod, env={"ADLC_TARGET_BRANCH": "a..b"})
        assert r.returncode == 0, r.stderr
        assert "skipped" in r.stderr and r.stdout.strip() == ""
    # A review run (a lane run id, an MR ref, no issue) stays a no-op too.
    review = {"WORKFLOW_INPUTS": json.dumps({"issue_ref": "g/adlc-workspace!7", "run_id": "u-1", "dispatch": "x"}),
              "ADLC_TARGET_BRANCH": "a..b"}
    for name in ("run-branch", "open-mr"):
        r = helper(shell, name, pod, env=review)
        assert r.returncode == 0 and "review run" in r.stderr


# ── without a target: exactly as before ─────────────────────────────────────

GIT_SHIM = r'''
printf '%s\n' "$*" >> "$GIT_SHIM_LOG"
exec "$REAL_GIT" "$@"
'''


def traced(shell, world, name, pod_name, env, *args, extra_path=""):
    """Run a helper in a fresh pod clone with every git call recorded."""
    pod = clone(world, "main", pod_name)
    bin_dir = fake_cli(world["tmp"], "git", GIT_SHIM)
    log = world["tmp"] / f"{pod_name}.git.log"
    full = dict(env, PATH=f"{bin_dir}:{extra_path}{os.environ['PATH']}", GIT_SHIM_LOG=str(log),
                REAL_GIT=shutil.which("git"))
    r = helper(shell, name, pod, *args, env=full)
    calls = log.read_text() if log.exists() else ""
    return r, calls.replace(str(pod), "POD"), pod


@pytest.mark.parametrize("kind", [[], ["--kind", "code"]])
def test_an_empty_target_is_the_same_as_none_for_run_branch(shell, world, kind):
    # The lane sets ADLC_TARGET_BRANCH="" on every mission pod that has no
    # target. The helper must make the very same git calls as without it.
    lane = {"WORKFLOW_INPUTS": json.dumps({"issue_ref": "g/adlc-workspace#12", "run_id": "u-1",
                                           "dispatch": "supervised"})}
    absent, absent_calls, pod_a = traced(shell, world, "run-branch", "absent", dict(RUN_ENV, **lane), *kind)
    empty, empty_calls, pod_b = traced(shell, world, "run-branch", "empty",
                                       dict(RUN_ENV, ADLC_TARGET_BRANCH="", **lane), *kind)
    assert absent.returncode == 0 and empty.returncode == 0, (absent.stderr, empty.stderr)
    assert (absent.stdout, absent.stderr) == (empty.stdout, empty.stderr)
    assert git(pod_a, "rev-parse", "HEAD") == git(pod_b, "rev-parse", "HEAD") == world["main_tip"]
    # The only extra call is the resolver's; with no target it runs no git at all.
    assert empty_calls == absent_calls
    assert TARGET not in absent_calls


# ── open-mr ─────────────────────────────────────────────────────────────────

def glab_env(world, extra=None, glab=GLAB):
    bin_dir = fake_cli(world["tmp"], "glab", glab)
    log = world["tmp"] / "glab.log"
    out = world["tmp"] / "steps" / "mission.output.json"
    env = target_env({"PATH": f"{bin_dir}:{os.environ['PATH']}", "FAKE_LOG": str(log),
                      "ADLC_STEP_OUTPUT": str(out), "GITLAB_HOST": "gl.test"})
    env.update(extra or {})
    return env, log, out


def on_code_branch(shell, world, pod=None, env=None):
    pod = pod or world["pod"]
    r = helper(shell, "run-branch", pod, "--kind", "code", env=env or target_env())
    assert r.returncode == 0, r.stderr
    return commit(pod, "src.txt", "the fix\n", "mission: the fix")


def test_open_mr_opens_the_merge_request_into_the_target(shell, world):
    pod = world["pod"]
    head = on_code_branch(shell, world)
    env, log, out = glab_env(world)
    r = helper(shell, "open-mr", pod, "--kind", "code", env=env)
    assert r.returncode == 0, r.stderr
    url = "https://gl.test/g/adlc-workspace/-/merge_requests/77"
    assert r.stdout.strip() == url
    body = posted_body(log)
    assert body["source_branch"] == MISSION
    assert body["target_branch"] == TARGET, "into the test branch, not into main"
    assert f"Target branch: `{TARGET}`" in body["description"]
    assert git(world["bare"], "rev-parse", MISSION) == head, "only the run branch was pushed"
    assert git(world["bare"], "rev-parse", "main") == world["main_tip"]
    assert git(world["bare"], "rev-parse", TARGET) == world["target_tip"]
    calls = [l for l in log.read_text().splitlines() if not l.startswith("BODY ")]
    assert not [l for l in calls if l.rstrip().endswith("projects/g%2Fadlc-workspace")], \
        "the project's default branch is never asked for"
    assert json.loads(out.read_text()) == {"mr_url": url}


def test_open_mr_without_a_target_still_asks_for_the_default_branch(shell, world):
    # Same pod shape, no target (ADLC_TARGET_BRANCH empty, as the lane sets it).
    pod = clone(world, "main", "main-pod")
    on_code_branch(shell, world, pod=pod, env=RUN_ENV)
    env, log, out = glab_env(world, {"ADLC_TARGET_BRANCH": ""})
    r = helper(shell, "open-mr", pod, "--kind", "code", env=env)
    assert r.returncode == 0, r.stderr
    body = posted_body(log)
    assert body["target_branch"] == "main"
    assert "Target branch" not in body["description"]
    calls = [l for l in log.read_text().splitlines() if not l.startswith("BODY ")]
    assert [l for l in calls if l.rstrip().endswith("projects/g%2Fadlc-workspace")], "default_branch lookup, as before"


def test_open_mr_opens_the_github_pull_request_into_the_target(shell, world):
    url = "https://github.com/g/adlc-workspace.git"
    pod = clone(world, TARGET, "gh-pod", url=url)
    on_code_branch(shell, world, pod=pod)
    gh_bin = fake_cli(world["tmp"], "gh", GH_FULL)
    env, _, out = glab_env(world, {"ISSUE_PROVIDER": "github"})
    gh_log = world["tmp"] / "gh.log"
    env.update(PATH=f"{gh_bin}:{env['PATH']}", FAKE_LOG=str(gh_log))
    r = helper(shell, "open-mr", pod, "--kind", "code", env=env)
    assert r.returncode == 0, r.stderr
    calls = gh_log.read_text()
    create = next(l for l in calls.splitlines() if "-X POST" in l and "/pulls" in l)
    assert f"base={TARGET}" in create and f"head={MISSION}" in create
    assert f"Target branch: `{TARGET}`" in create
    assert not [l for l in calls.splitlines() if l.rstrip().endswith("repos/g/adlc-workspace")], \
        "the repository's default branch is never asked for"
    assert json.loads(out.read_text())["mr_url"].endswith("/pull/9")


def test_an_empty_run_is_measured_against_the_target(shell, world):
    # The run branch equals the test branch's tip: nothing to review, though
    # it differs from main in both directions.
    pod = world["pod"]
    assert helper(shell, "run-branch", pod, "--kind", "code", env=target_env()).returncode == 0
    env, log, out = glab_env(world)
    r = helper(shell, "open-mr", pod, "--kind", "code", env=env)
    assert r.returncode == 0, r.stderr
    assert r.stdout.strip() == ""
    assert f"beyond origin/{TARGET}" in r.stderr and "no MR opened" in r.stderr
    assert not log.exists() and not out.exists()
    assert git(world["bare"], "branch", "--list", MISSION) == "", "nothing was pushed"


OWN = '{"web_url":"https://gl.test/g/adlc-workspace/-/merge_requests/70","source_project_id":1,"target_project_id":1,"target_branch":"%s"}'


def test_open_mr_reuses_an_open_mr_that_targets_the_target(shell, world):
    pod = world["pod"]
    head = on_code_branch(shell, world)
    env, log, out = glab_env(world, {"FAKE_EXISTING": "[%s]" % (OWN % TARGET)})
    r = helper(shell, "open-mr", pod, "--kind", "code", env=env)
    assert r.returncode == 0, r.stderr
    assert r.stdout.strip().endswith("/merge_requests/70")
    assert git(world["bare"], "rev-parse", MISSION) == head
    assert "-X POST" not in log.read_text()


@pytest.mark.parametrize("existing", [OWN % "main", OWN.replace(',"target_branch":"%s"', "")])
def test_open_mr_never_reuses_an_open_mr_that_goes_elsewhere(shell, world, existing):
    # An earlier run of the same issue against main left its MR open: a
    # target-branch run must not push into it.
    pod = world["pod"]
    on_code_branch(shell, world)
    env, log, out = glab_env(world, {"FAKE_EXISTING": f"[{existing}]"})
    r = helper(shell, "open-mr", pod, "--kind", "code", env=env)
    assert r.returncode == 2
    assert "merge_requests/70" in r.stderr and f"not this run's target branch '{TARGET}'" in r.stderr
    assert "nothing was pushed" in r.stderr
    assert git(world["bare"], "branch", "--list", MISSION) == ""
    assert "-X POST" not in log.read_text() and not out.exists()


def test_open_mr_never_reuses_a_github_pr_that_goes_elsewhere(shell, world):
    url = "https://github.com/g/adlc-workspace.git"
    pod = clone(world, TARGET, "gh-pod", url=url)
    on_code_branch(shell, world, pod=pod)
    gh = GH_FULL.replace('''*"/pulls?head="*) echo '[]' ;;''',
                         '''*"/pulls?head="*) echo '[{"html_url":"https://github.com/g/adlc-workspace/pull/4","base":{"ref":"main"}}]' ;;''')
    assert gh != GH_FULL
    gh_bin = fake_cli(world["tmp"], "gh", gh)
    env, _, out = glab_env(world, {"ISSUE_PROVIDER": "github"})
    gh_log = world["tmp"] / "gh.log"
    env.update(PATH=f"{gh_bin}:{env['PATH']}", FAKE_LOG=str(gh_log))
    r = helper(shell, "open-mr", pod, "--kind", "code", env=env)
    assert r.returncode == 2
    assert "pull/4" in r.stderr and "targets 'main'" in r.stderr
    assert git(world["bare"], "branch", "--list", MISSION) == ""
    assert "-X POST" not in gh_log.read_text()


def test_open_mr_stops_before_any_tracker_call_when_the_target_is_gone(shell, world):
    # The test branch was deleted while the mission ran.
    pod = world["pod"]
    on_code_branch(shell, world)
    git(world["bare"], "branch", "-D", TARGET)
    env, log, out = glab_env(world)
    r = helper(shell, "open-mr", pod, "--kind", "code", env=env)
    assert r.returncode == 2
    assert "was not found on origin" in r.stderr and "refusing to fall back to the default branch" in r.stderr
    assert "nothing was pushed" in r.stderr
    assert not log.exists(), "no tracker call"
    assert git(world["bare"], "branch", "--list", MISSION) == "" and not out.exists()


def test_open_mr_stops_on_a_target_it_cannot_trust(shell, world):
    pod = world["pod"]
    on_code_branch(shell, world)
    env, log, out = glab_env(world, {"ADLC_TARGET_BRANCH": "factory-test/x.lock"})
    r = helper(shell, "open-mr", pod, "--kind", "code", env=env)
    assert r.returncode == 2
    assert "open-mr: invalid target branch" in r.stderr
    assert not log.exists() and git(world["bare"], "branch", "--list", MISSION) == ""


# ── the helpers are told about by the skill text ────────────────────────────

def test_the_twins_and_the_reference_are_installed_with_the_runbook():
    assert (BASH_DIR / "target-branch.sh").is_file() and (PS_DIR / "target-branch.ps1").is_file()
    assert os.access(BASH_DIR / "target-branch.sh", os.X_OK)


def test_no_eval_and_no_force_in_the_changed_helpers():
    for name in ("target-branch.sh", "run-branch.sh", "open-mr.sh"):
        code = [l for l in (BASH_DIR / name).read_text().splitlines() if not l.lstrip().startswith("#")]
        assert not [l for l in code if "eval " in l], name
        assert not [l for l in code if "git push" in l and ("--force" in l or " -f " in l or "+refs" in l)], name


def test_the_skill_text_names_the_target_branch_rule():
    runbook = (RUNBOOK / "SKILL.md").read_text()
    assert "target-branch.sh" in runbook and "ADLC_TARGET_BRANCH" in runbook
    assert "never falls back to the default branch" in runbook
    ctx = (RUNBOOK / "references/run-context.md").read_text()
    assert "ADLC_TARGET_BRANCH" in ctx and "target-branch.sh" in ctx and "WORKFLOW_INPUTS.target_branch" in ctx
    tracker = (RUNBOOK / "references/tracker-integration.md").read_text()
    assert "target-branch::" in tracker and "ADLC_TARGET_BRANCH" in tracker
    for skill in ("factory-mission", "factory-intent"):
        text = (ROOT / "skills/factory" / skill / "SKILL.md").read_text()
        assert "target branch" in text.lower() and "ADLC_TARGET_BRANCH" in text, skill
    review = (ROOT / "skills/factory/factory-review/SKILL.md").read_text()
    assert "target branch" in review.lower()
