"""A workspace mission whose change belongs to a child repo publishes there
(adlc-workspace#168).

Evidence: #151 run 1b997ae3 targeted tikalk/adlc-team-skills. The lane ran
run-branch.sh only in the workspace root, the agent edited the submodule at the
workspace's stale pin (e7f8edf, 241 commits behind) and pushed that, and the
only MR was a workspace pointer bump (adlc-workspace!166) to a commit that is
not on the child's main. No PR opened in the child repo, so no CI ran.

Contract pinned here: the runbook helpers act on the repository they run in.
Run from inside the child checkout, run-branch.sh --kind code cuts the mission
branch from the child's origin default branch (0 behind, whatever the pin),
and open-mr.sh --kind code opens the PR in the child repo and writes it as
mr_url. The pointer change alone is no reason for a workspace MR: with no
commits on the workspace run branch, open-mr.sh opens nothing there.
The factory-mission rule that sends the run into the child repo is checked
at the end.
"""
import json
import os
import shutil
import stat
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).parent.parent.parent
SCRIPTS = ROOT / "skills/factory/factory-runbook/scripts/bash"
RUN_BRANCH = SCRIPTS / "run-branch.sh"
OPEN_MR = SCRIPTS / "open-mr.sh"
MISSION = ROOT / "skills/factory/factory-mission/SKILL.md"

CHILD_URL = "https://github.com/g/adlc-team-skills.git"
WS_URL = "https://gl.test/g/adlc-workspace.git"
RUN_ENV = {"ADLC_RUN_ID": "1b997ae3", "ADLC_ISSUE_REF": "g/adlc-workspace#151"}
BRANCH = "factory/mission/adlc-workspace-151"

pytestmark = pytest.mark.skipif(
    shutil.which("bash") is None or shutil.which("git") is None or shutil.which("node") is None,
    reason="needs bash, git and node",
)

GH = r'''
echo "$*" >> "$FAKE_LOG"
case "$*" in
  *"-i user"*) printf 'HTTP/2.0 200 OK\r\nX-Oauth-Scopes: repo, read:org\r\n\r\n{"login":"runner-bot"}\n' ;;
  *"-X POST"*"/pulls"*) echo '{"html_url":"https://github.com/g/adlc-team-skills/pull/7","number":7}' ;;
  *"-X POST"*"/assignees"*|*"-X PATCH"*) echo '{}' ;;
  *"/pulls?head="*) echo '[]' ;;
  *" user") echo '{"login":"runner-bot"}' ;;
  *"repos/g/adlc-team-skills") echo '{"default_branch":"main"}' ;;
  *) echo '{}' ;;
esac
'''
GLAB = r'''
echo "$*" >> "$FAKE_LOG"
echo '{}'
'''


def git(cwd, *args, check=True):
    return subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True, check=check).stdout.strip()


def run(script, cwd, *args, env=None):
    full_env = {k: v for k, v in os.environ.items()
                if not k.startswith("ADLC_") and k != "WORKFLOW_INPUTS"}
    full_env.update(env or {})
    return subprocess.run(["bash", str(script), *args], cwd=cwd, capture_output=True, text=True, env=full_env)


def fake_cli(tmp, name, script):
    bin_dir = tmp / f"bin-{name}"
    bin_dir.mkdir(exist_ok=True)
    p = bin_dir / name
    p.write_text("#!/usr/bin/env bash\n" + script)
    p.chmod(p.stat().st_mode | stat.S_IEXEC)
    return bin_dir


def ident(path):
    git(path, "config", "user.email", "t@example.test")
    git(path, "config", "user.name", "t")


@pytest.fixture
def world(tmp_path):
    """A workspace whose child-repo pin is behind the child's main, and a
    runner-pod clone of it with the submodule checked out at that pin. The
    https origins read as on the reference deployment and resolve to local
    bare repos (offline)."""
    child_bare = tmp_path / "child.git"
    ws_bare = tmp_path / "ws.git"
    for b in (child_bare, ws_bare):
        subprocess.run(["git", "init", "-q", "--bare", "-b", "main", str(b)], check=True)
    redirect = ["-c", f"url.{child_bare}.insteadOf={CHILD_URL}",
                "-c", f"url.{ws_bare}.insteadOf={WS_URL}", "-c", "protocol.file.allow=always"]

    seed = tmp_path / "child-seed"
    subprocess.run(["git", "init", "-q", "-b", "main", str(seed)], check=True)
    ident(seed)
    (seed / "SKILL.md").write_text("v1\n")
    git(seed, "add", "-A")
    git(seed, "commit", "-q", "-m", "pin")
    pin = git(seed, "rev-parse", "HEAD")
    git(seed, "remote", "add", "origin", str(child_bare))
    git(seed, "push", "-q", "origin", "main")

    ws_seed = tmp_path / "ws-seed"
    subprocess.run(["git", "init", "-q", "-b", "main", str(ws_seed)], check=True)
    ident(ws_seed)
    git(ws_seed, *redirect, "submodule", "add", "-q", CHILD_URL, "adlc-team-skills")
    git(ws_seed, "commit", "-q", "-m", "workspace pins the child")
    git(ws_seed, "remote", "add", "origin", str(ws_bare))
    git(ws_seed, "push", "-q", "origin", "main")

    # The child's main moves on after the pin (team-skills was 241 ahead).
    for i in (2, 3):
        (seed / "SKILL.md").write_text(f"v{i}\n")
        git(seed, "commit", "-q", "-am", f"main moves on {i}")
    git(seed, "push", "-q", "origin", "main")
    child_main = git(seed, "rev-parse", "HEAD")

    pod = tmp_path / "workspace"
    subprocess.run(["git", *redirect, "clone", "-q", "--branch", "main", "--single-branch", WS_URL, str(pod)],
                   check=True, capture_output=True)
    git(pod, "config", f"url.{ws_bare}.insteadOf", WS_URL)
    git(pod, *redirect, "submodule", "update", "--init", "-q")
    child = pod / "adlc-team-skills"
    git(child, "config", f"url.{child_bare}.insteadOf", CHILD_URL)
    ident(pod)
    ident(child)
    assert git(child, "rev-parse", "HEAD") == pin  # the stale pin, as in #151
    return {"tmp": tmp_path, "pod": pod, "child": child, "pin": pin, "child_main": child_main,
            "child_bare": child_bare}


def publish_env(world):
    gh = fake_cli(world["tmp"], "gh", GH)
    glab = fake_cli(world["tmp"], "glab", GLAB)
    out = world["tmp"] / "steps" / "execute.output.json"
    env = dict(RUN_ENV, PATH=f"{gh}:{glab}:{os.environ['PATH']}", FAKE_LOG=str(world["tmp"] / "cli.log"),
               ADLC_STEP_OUTPUT=str(out), GITLAB_HOST="gl.test", ISSUE_PROVIDER="gitlab")
    return env, out


def test_the_child_mission_branch_starts_from_the_childs_main_not_the_pin(world):
    child = world["child"]
    r = run(RUN_BRANCH, child, "--kind", "code", env=RUN_ENV)
    assert r.returncode == 0, r.stderr
    assert git(child, "branch", "--show-current") == BRANCH
    assert git(child, "rev-parse", "HEAD") == world["child_main"]
    assert git(child, "rev-list", "--count", "HEAD..origin/main") == "0"  # 0 behind


def test_fail_before_fix_shape_a_branch_cut_at_the_pin_is_behind(world):
    # What #151 pushed: a branch from the checked-out pin, behind the child's main.
    child = world["child"]
    git(child, "switch", "-q", "-c", BRANCH)
    git(child, "fetch", "-q", "origin", "main")
    assert git(child, "rev-list", "--count", "HEAD..origin/main") == "2"


def test_the_code_pr_opens_in_the_child_repo_and_is_the_runs_mr_url(world):
    child = world["child"]
    assert run(RUN_BRANCH, child, "--kind", "code", env=RUN_ENV).returncode == 0
    (child / "SKILL.md").write_text("v3 + the mission's change\n")
    git(child, "commit", "-q", "-am", "feat: the mission's change")
    env, out = publish_env(world)
    r = run(OPEN_MR, child, "--kind", "code", env=env)
    assert r.returncode == 0, r.stderr
    assert r.stdout.strip() == "https://github.com/g/adlc-team-skills/pull/7"
    assert json.loads(out.read_text())["mr_url"] == "https://github.com/g/adlc-team-skills/pull/7"
    calls = (world["tmp"] / "cli.log").read_text()
    create = next(l for l in calls.splitlines() if "-X POST" in l and "/pulls" in l)
    assert "repos/g/adlc-team-skills/pulls" in create
    # The child's run branch reached the child's origin, on top of its main.
    pushed = git(world["child_bare"], "rev-parse", f"refs/heads/{BRANCH}")
    assert subprocess.run(["git", "merge-base", "--is-ancestor", world["child_main"], pushed],
                          cwd=world["child_bare"]).returncode == 0


def test_a_pointer_change_alone_opens_no_workspace_mr(world):
    pod, child = world["pod"], world["child"]
    assert run(RUN_BRANCH, pod, "--kind", "code", env=RUN_ENV).returncode == 0
    assert run(RUN_BRANCH, child, "--kind", "code", env=RUN_ENV).returncode == 0
    (child / "SKILL.md").write_text("changed\n")
    git(child, "commit", "-q", "-am", "feat: change")
    assert git(pod, "status", "--porcelain") != ""  # the submodule pointer moved
    env, out = publish_env(world)
    r = run(OPEN_MR, pod, "--kind", "code", env=env)
    assert r.returncode == 0, r.stderr
    assert r.stdout.strip() == ""
    assert not out.exists() or "mr_url" not in json.loads(out.read_text() or "{}")


def mission_text():
    return " ".join(MISSION.read_text().split())


def test_factory_mission_publishes_a_child_repo_change_from_inside_the_child():
    t = mission_text()
    assert "**A change in a child repository is published there.**" in t
    for needle in ("git config -f .gitmodules", "from inside the child checkout, run the `factory-runbook` publish procedure's **Start** step",
                   "publish from the same directory", "before you edit", "never the workspace's pinned commit"):
        assert needle in t, needle


def test_factory_mission_opens_no_workspace_pointer_mr():
    t = mission_text()
    assert "Do not commit the submodule pointer in the workspace" in t
    assert "mr_url` is the child repository's PR/MR" in t
