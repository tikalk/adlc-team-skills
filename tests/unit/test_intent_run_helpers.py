"""Intent run branch, step commits and draft MR helpers (ADR-431-amendment,
ADR-444; adlc-workspace#26).

Contract pinned here (bash helpers in skills/factory/factory-mission/scripts/bash/):

  run-branch.sh   With ADLC_RUN_ID: check out factory/intent/<repo>-<iid> (from
                  ADLC_ISSUE_REF) or factory/intent/run-<run_id> in the project root;
                  reuse a local branch; continue from origin when only the remote
                  has it. Without ADLC_RUN_ID: no-op. Prints the branch.
  commit-step.sh  Acts on ADLC_RUN_ID, `adlc.commit_steps: true` in
                  .adlc/init-options.json, or --commit (ADR-431 §6). Stages only
                  paths inside the ADR-433 allowlist, never .adlc/workflows/**, refuses
                  paths outside the repo; needs a committer identity; one commit
                  with Run-Id/Step/Output-Type/Records trailers, else `sha: none`.
  open-mr.sh      With ADLC_RUN_ID: push the run branch only; reuse an open MR for
                  it, else create one draft MR (squash off) with the issue's
                  milestone and assignees (ADR-432 chain falls back to the runner);
                  merge {"mr_url": ...} into ADLC_STEP_OUTPUT. Prints the URL.
"""

import json
import os
import shutil
import stat
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).parent.parent.parent
SCRIPTS = ROOT / "skills/factory/factory-mission/scripts/bash"
RUN_BRANCH = SCRIPTS / "run-branch.sh"
COMMIT_STEP = SCRIPTS / "commit-step.sh"
OPEN_MR = SCRIPTS / "open-mr.sh"

pytestmark = pytest.mark.skipif(
    shutil.which("bash") is None or shutil.which("git") is None or shutil.which("node") is None,
    reason="needs bash, git and node",
)


def git(cwd, *args, check=True):
    return subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True, check=check).stdout.strip()


def run(script, cwd, *args, env=None):
    full_env = {k: v for k, v in os.environ.items() if not k.startswith("ADLC_")}
    full_env.update(env or {})
    return subprocess.run(["bash", str(script), *args], cwd=cwd, capture_output=True, text=True, env=full_env)


@pytest.fixture
def repo(tmp_path):
    """A workspace clone whose origin is https://gl.test/g/adlc-workspace.git,
    pushing to a local bare repo (offline)."""
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
    # Offline: the real https origin is rewritten to the bare repo for fetch
    # and push; `remote.origin.url` still reads the https URL.
    git(work, "config", f"url.{bare}.insteadOf", "https://gl.test/g/adlc-workspace.git")
    git(work, "push", "-q", "origin", "main")
    return {"work": work, "bare": bare, "tmp": tmp_path}


RUN_ENV = {"ADLC_RUN_ID": "r26", "ADLC_ISSUE_REF": "g/adlc-workspace#12"}


# ── run-branch ─────────────────────────────────────────────────────────────

def test_run_branch_noop_without_run_context(repo):
    r = run(RUN_BRANCH, repo["work"])
    assert r.returncode == 0, r.stderr
    assert r.stdout.strip() == ""
    assert git(repo["work"], "branch", "--show-current") == "main"


def test_run_branch_creates_issue_branch_in_project_root(repo):
    r = run(RUN_BRANCH, repo["work"], env=RUN_ENV)
    assert r.returncode == 0, r.stderr
    assert r.stdout.strip() == "factory/intent/adlc-workspace-12"
    assert git(repo["work"], "branch", "--show-current") == "factory/intent/adlc-workspace-12"


def test_run_branch_without_issue_uses_run_id(repo):
    r = run(RUN_BRANCH, repo["work"], env={"ADLC_RUN_ID": "r26"})
    assert r.returncode == 0, r.stderr
    assert r.stdout.strip() == "factory/intent/run-r26"


def test_run_branch_reuses_local_branch(repo):
    run(RUN_BRANCH, repo["work"], env=RUN_ENV)
    (repo["work"] / "x.txt").write_text("1\n")
    git(repo["work"], "add", "-A")
    git(repo["work"], "commit", "-q", "-m", "on branch")
    git(repo["work"], "switch", "-q", "main")
    r = run(RUN_BRANCH, repo["work"], env=RUN_ENV)
    assert r.returncode == 0, r.stderr
    assert git(repo["work"], "log", "-1", "--format=%s") == "on branch"


def test_run_branch_continues_from_origin(repo, tmp_path):
    other = tmp_path / "other"
    subprocess.run(["git", "clone", "-q", str(repo["bare"]), str(other)], check=True)
    # ("origin" of `other` is the bare repo itself.)
    git(other, "config", "user.email", "o@t.local")
    git(other, "config", "user.name", "o")
    git(other, "switch", "-q", "-c", "factory/intent/adlc-workspace-12")
    (other / "y.txt").write_text("2\n")
    git(other, "add", "-A")
    git(other, "commit", "-q", "-m", "from another pod")
    git(other, "push", "-q", "origin", "factory/intent/adlc-workspace-12")
    r = run(RUN_BRANCH, repo["work"], env=RUN_ENV)
    assert r.returncode == 0, r.stderr
    assert git(repo["work"], "log", "-1", "--format=%s") == "from another pod"


def test_run_branch_continues_from_origin_in_a_single_branch_clone(repo, tmp_path):
    # The runner clones the workspace with `git clone --branch main
    # --single-branch`: its fetch refspec covers only main, and
    # `git switch --track origin/<run branch>` failed with "cannot set up
    # tracking information" (adlc-workspace#12 M9 pilot, run 4ead8524).
    other = tmp_path / "other"
    subprocess.run(["git", "clone", "-q", str(repo["bare"]), str(other)], check=True)
    git(other, "config", "user.email", "o@t.local")
    git(other, "config", "user.name", "o")
    git(other, "switch", "-q", "-c", "factory/intent/adlc-workspace-12")
    (other / "y.txt").write_text("2\n")
    git(other, "add", "-A")
    git(other, "commit", "-q", "-m", "from another pod")
    git(other, "push", "-q", "origin", "factory/intent/adlc-workspace-12")
    pod = tmp_path / "pod"
    subprocess.run(["git", "clone", "-q", "--branch", "main", "--single-branch", str(repo["bare"]), str(pod)], check=True)
    assert git(pod, "config", "--get-all", "remote.origin.fetch") == "+refs/heads/main:refs/remotes/origin/main"
    git(pod, "config", "remote.origin.url", "https://gl.test/g/adlc-workspace.git")
    git(pod, "config", f"url.{repo['bare']}.insteadOf", "https://gl.test/g/adlc-workspace.git")
    r = run(RUN_BRANCH, pod, env=RUN_ENV)
    assert r.returncode == 0, r.stderr
    assert r.stdout.strip() == "factory/intent/adlc-workspace-12"
    assert git(pod, "rev-parse", "--abbrev-ref", "HEAD") == "factory/intent/adlc-workspace-12"
    assert git(pod, "log", "-1", "--format=%s") == "from another pod"
    # A second call (the orchestrator's own) is an idempotent no-op.
    r2 = run(RUN_BRANCH, pod, env=RUN_ENV)
    assert r2.returncode == 0, r2.stderr
    assert git(pod, "log", "-1", "--format=%s") == "from another pod"


def _push_from_other_pod(repo, tmp_path, msg):
    other = tmp_path / "other"
    if not other.exists():
        subprocess.run(["git", "clone", "-q", str(repo["bare"]), str(other)], check=True)
        git(other, "config", "user.email", "o@t.local")
        git(other, "config", "user.name", "o")
        git(other, "switch", "-q", "factory/intent/adlc-workspace-12")
    (other / f"{msg}.txt").write_text("x\n")
    git(other, "add", "-A")
    git(other, "commit", "-q", "-m", msg)
    git(other, "push", "-q", "origin", "factory/intent/adlc-workspace-12")


def test_run_branch_fast_forwards_a_stale_local_branch_from_origin(repo, tmp_path):
    run(RUN_BRANCH, repo["work"], env=RUN_ENV)
    git(repo["work"], "push", "-q", "origin", "factory/intent/adlc-workspace-12")
    git(repo["work"], "switch", "-q", "main")
    _push_from_other_pod(repo, tmp_path, "newer on origin")
    r = run(RUN_BRANCH, repo["work"], env=RUN_ENV)
    assert r.returncode == 0, r.stderr
    assert git(repo["work"], "log", "-1", "--format=%s") == "newer on origin"


def test_run_branch_halts_when_local_and_origin_diverged(repo, tmp_path):
    run(RUN_BRANCH, repo["work"], env=RUN_ENV)
    git(repo["work"], "push", "-q", "origin", "factory/intent/adlc-workspace-12")
    _push_from_other_pod(repo, tmp_path, "remote side")
    (repo["work"] / "local.txt").write_text("l\n")
    git(repo["work"], "add", "-A")
    git(repo["work"], "commit", "-q", "-m", "local side")
    git(repo["work"], "switch", "-q", "main")
    r = run(RUN_BRANCH, repo["work"], env=RUN_ENV)
    assert r.returncode != 0
    assert "diverged" in r.stderr
    assert git(repo["work"], "branch", "--show-current") == "main"


@pytest.mark.parametrize("ref", ["g/../evil#1", "g//x#1", "/g/x#1", "g/.x#1", "g/-x#1", "x#1", "g/x#1a"])
def test_issue_ref_rule_is_shared_by_run_branch_and_open_mr(repo, ref):
    r = run(RUN_BRANCH, repo["work"], env={"ADLC_RUN_ID": "r26", "ADLC_ISSUE_REF": ref})
    assert r.returncode != 0, ref
    git(repo["work"], "switch", "-q", "-c", "factory/intent/run-r26")
    env, log, out = open_mr_env(repo, {"ADLC_ISSUE_REF": ref})
    r = run(OPEN_MR, repo["work"], env=env)
    assert r.returncode != 0, ref
    assert "invalid ADLC_ISSUE_REF" in r.stderr


def test_run_branch_rejects_unsafe_issue_ref(repo):
    r = run(RUN_BRANCH, repo["work"], env={"ADLC_RUN_ID": "r26", "ADLC_ISSUE_REF": "g/../evil#1"})
    assert r.returncode != 0
    assert git(repo["work"], "branch", "--show-current") == "main"


# ── commit-step ────────────────────────────────────────────────────────────

def write(work, rel, text):
    p = work / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text)


STEP_ARGS = ["--orchestrator", "factory-product", "--step", "specify", "--output-type", "draft",
             "--summary", "two PDR drafts", "--records", "PDR-127,PDR-128", "--"]


def test_commit_step_commits_with_trailers(repo):
    w = repo["work"]
    write(w, ".adlc/drafts/pdr/PDR-127.md", "a\n")
    write(w, ".adlc/drafts/pdr/PDR-128.md", "b\n")
    r = run(COMMIT_STEP, w, *STEP_ARGS, ".adlc/drafts/pdr/PDR-127.md", ".adlc/drafts/pdr/PDR-128.md", env=RUN_ENV)
    assert r.returncode == 0, r.stderr
    sha = git(w, "rev-parse", "HEAD")
    assert r.stdout.strip() == f"sha: {sha}"
    msg = git(w, "log", "-1", "--format=%B")
    assert msg.splitlines()[0] == "docs(adlc): factory-product specify — two PDR drafts"
    trailers = git(w, "log", "-1", "--format=%(trailers:only)").splitlines()
    assert trailers == ["Run-Id: r26", "Step: specify", "Output-Type: draft", "Records: PDR-127,PDR-128"]
    assert sorted(git(w, "show", "--name-only", "--format=", "HEAD").splitlines()) == [
        ".adlc/drafts/pdr/PDR-127.md", ".adlc/drafts/pdr/PDR-128.md"]


def test_commit_step_only_commits_its_paths(repo):
    w = repo["work"]
    write(w, ".adlc/drafts/pdr/PDR-1.md", "a\n")
    write(w, "docs/adlc/memory/adr/ADR-9.md", "staged elsewhere\n")
    git(w, "add", "docs/adlc/memory/adr/ADR-9.md")
    r = run(COMMIT_STEP, w, *STEP_ARGS, ".adlc/drafts/pdr/PDR-1.md", env=RUN_ENV)
    assert r.returncode == 0, r.stderr
    assert git(w, "show", "--name-only", "--format=", "HEAD").splitlines() == [".adlc/drafts/pdr/PDR-1.md"]
    assert "docs/adlc/memory/adr/ADR-9.md" in git(w, "diff", "--cached", "--name-only")


def test_commit_step_sha_none_when_unchanged(repo):
    w = repo["work"]
    write(w, ".adlc/drafts/pdr/PDR-1.md", "a\n")
    run(COMMIT_STEP, w, *STEP_ARGS, ".adlc/drafts/pdr/PDR-1.md", env=RUN_ENV)
    head = git(w, "rev-parse", "HEAD")
    r = run(COMMIT_STEP, w, *STEP_ARGS, ".adlc/drafts/pdr/PDR-1.md", env=RUN_ENV)
    assert r.returncode == 0, r.stderr
    assert r.stdout.strip() == "sha: none"
    assert git(w, "rev-parse", "HEAD") == head


def test_commit_step_noop_without_run_context_or_opt_in(repo):
    w = repo["work"]
    write(w, ".adlc/drafts/pdr/PDR-1.md", "a\n")
    head = git(w, "rev-parse", "HEAD")
    r = run(COMMIT_STEP, w, *STEP_ARGS, ".adlc/drafts/pdr/PDR-1.md")
    assert r.returncode == 0, r.stderr
    assert r.stdout.strip() == "sha: none"
    assert git(w, "rev-parse", "HEAD") == head
    assert git(w, "status", "--porcelain") == "?? .adlc/"


@pytest.mark.parametrize("opt_in", ["flag", "init-options"])
def test_commit_step_interactive_opt_in(repo, opt_in):
    w = repo["work"]
    write(w, ".adlc/drafts/pdr/PDR-1.md", "a\n")
    args = list(STEP_ARGS)
    if opt_in == "flag":
        args.insert(0, "--commit")
    else:
        write(w, ".adlc/init-options.json", json.dumps({"agent": "opencode", "adlc": {"commit_steps": True}}))
    r = run(COMMIT_STEP, w, *args, ".adlc/drafts/pdr/PDR-1.md")
    assert r.returncode == 0, r.stderr
    assert r.stdout.startswith("sha: ") and r.stdout.strip() != "sha: none"
    assert "Run-Id: interactive" in git(w, "log", "-1", "--format=%B")


@pytest.mark.parametrize("path", [
    ".adlc/workflows/runs/r26/state.json",
    "src/app.js",
    "../outside.md",
    "docs/adlc/memory/../../src/app.js",
])
def test_commit_step_refuses_paths_outside_the_allowlist(repo, path):
    w = repo["work"]
    write(w, ".adlc/workflows/runs/r26/state.json", "{}\n")
    write(w, "src/app.js", "x\n")
    head = git(w, "rev-parse", "HEAD")
    r = run(COMMIT_STEP, w, *STEP_ARGS, path, env=RUN_ENV)
    assert r.returncode != 0
    assert "allowlist" in r.stderr or "outside" in r.stderr
    assert git(w, "rev-parse", "HEAD") == head
    assert git(w, "diff", "--cached", "--name-only") == ""


def test_commit_step_fails_without_committer_identity(repo, tmp_path):
    w = repo["work"]
    git(w, "config", "--unset", "user.email")
    git(w, "config", "--unset", "user.name")
    write(w, ".adlc/drafts/pdr/PDR-1.md", "a\n")
    env = dict(RUN_ENV, HOME=str(tmp_path), XDG_CONFIG_HOME=str(tmp_path), GIT_CONFIG_NOSYSTEM="1",
               GIT_COMMITTER_NAME="", GIT_COMMITTER_EMAIL="", EMAIL="")
    r = run(COMMIT_STEP, w, *STEP_ARGS, ".adlc/drafts/pdr/PDR-1.md", env=env)
    assert r.returncode != 0
    assert "committer identity" in r.stderr


def test_commit_step_rejects_a_multiline_summary_and_bad_output_type(repo):
    w = repo["work"]
    write(w, ".adlc/drafts/pdr/PDR-1.md", "a\n")
    bad = list(STEP_ARGS)
    bad[bad.index("draft")] = "anything"
    assert run(COMMIT_STEP, w, *bad, ".adlc/drafts/pdr/PDR-1.md", env=RUN_ENV).returncode != 0
    ml = list(STEP_ARGS)
    ml[ml.index("two PDR drafts")] = "line one\nSigned-off-by: someone"
    r = run(COMMIT_STEP, w, *ml, ".adlc/drafts/pdr/PDR-1.md", env=RUN_ENV)
    assert r.returncode == 0, r.stderr
    assert git(w, "log", "-1", "--format=%s") == "docs(adlc): factory-product specify — line one Signed-off-by: someone"
    assert "Signed-off-by" not in git(w, "log", "-1", "--format=%(trailers:only)")


# ── open-mr ────────────────────────────────────────────────────────────────

def fake_cli(tmp, name, script):
    bin_dir = tmp / f"bin-{name}"
    bin_dir.mkdir(exist_ok=True)
    p = bin_dir / name
    p.write_text("#!/usr/bin/env bash\n" + script)
    p.chmod(p.stat().st_mode | stat.S_IEXEC)
    return bin_dir


GLAB = r'''
echo "$*" >> "$FAKE_LOG"
case "$*" in
  *"merge_requests?source_branch="*) echo "${FAKE_EXISTING:-[]}" ;;
  *"-X POST"*"merge_requests"*) echo '{"web_url":"https://gl.test/g/adlc-workspace/-/merge_requests/77"}' ;;
  *"issues/12"*) echo '{"milestone":{"id":407},"assignees":[{"id":5}]}' ;;
  *"personal_access_tokens/self"*) echo "${FAKE_SCOPES:-{\"scopes\":[\"api\",\"write_repository\"]}}" ;;
  *" user"*) echo '{"id":99,"username":"runner-bot"}' ;;
  *"projects/g%2Fadlc-workspace"*) echo '{"default_branch":"main"}' ;;
  *) echo '{}' ;;
esac
'''


def open_mr_env(repo, extra=None, glab=GLAB):
    bin_dir = fake_cli(repo["tmp"], "glab", glab)
    log = repo["tmp"] / "glab.log"
    out = repo["tmp"] / "steps" / "intent.output.json"
    env = dict(RUN_ENV, PATH=f"{bin_dir}:{os.environ['PATH']}", FAKE_LOG=str(log),
               ADLC_STEP_OUTPUT=str(out), GITLAB_HOST="gl.test")
    env.update(extra or {})
    return env, log, out


def on_run_branch(repo):
    run(RUN_BRANCH, repo["work"], env=RUN_ENV)
    write(repo["work"], ".adlc/drafts/pdr/PDR-1.md", "a\n")
    run(COMMIT_STEP, repo["work"], *STEP_ARGS, ".adlc/drafts/pdr/PDR-1.md", env=RUN_ENV)


def test_open_mr_noop_without_run_context(repo):
    env, log, out = open_mr_env(repo)
    for k in ("ADLC_RUN_ID",):
        env.pop(k)
    r = run(OPEN_MR, repo["work"], env=env)
    assert r.returncode == 0, r.stderr
    assert r.stdout.strip() == ""
    assert not log.exists()


def test_open_mr_creates_a_draft_mr_with_issue_ownership(repo):
    on_run_branch(repo)
    env, log, out = open_mr_env(repo)
    r = run(OPEN_MR, repo["work"], env=env)
    assert r.returncode == 0, r.stderr
    url = "https://gl.test/g/adlc-workspace/-/merge_requests/77"
    assert r.stdout.strip() == url
    # Only the run branch was pushed.
    assert git(repo["bare"], "branch", "--list", "factory/intent/adlc-workspace-12") != ""
    calls = log.read_text()
    post = next(l for l in calls.splitlines() if "-X POST" in l)
    assert "source_branch=factory/intent/adlc-workspace-12" in post
    assert "target_branch=main" in post
    assert "title=Draft: factory: adlc-workspace#12 records (run r26)" in post
    assert "squash=false" in post
    assert "milestone_id=407" in post
    assert "assignee_ids[]=5" in post
    assert json.loads(out.read_text()) == {"mr_url": url}


def test_open_mr_reuses_an_open_mr_and_keeps_other_output_fields(repo):
    on_run_branch(repo)
    existing = '[{"web_url":"https://gl.test/g/adlc-workspace/-/merge_requests/70"}]'
    env, log, out = open_mr_env(repo, {"FAKE_EXISTING": existing})
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps({"conclusion": "two PDRs"}))
    r = run(OPEN_MR, repo["work"], env=env)
    assert r.returncode == 0, r.stderr
    assert r.stdout.strip() == "https://gl.test/g/adlc-workspace/-/merge_requests/70"
    assert "-X POST" not in log.read_text()
    assert json.loads(out.read_text()) == {"conclusion": "two PDRs", "mr_url": "https://gl.test/g/adlc-workspace/-/merge_requests/70"}


def test_open_mr_assignee_falls_back_to_the_runner(repo):
    on_run_branch(repo)
    glab = GLAB.replace('{"milestone":{"id":407},"assignees":[{"id":5}]}', '{"milestone":null,"assignees":[]}')
    env, log, out = open_mr_env(repo, glab=glab)
    r = run(OPEN_MR, repo["work"], env=env)
    assert r.returncode == 0, r.stderr
    post = next(l for l in log.read_text().splitlines() if "-X POST" in l)
    assert "assignee_ids[]=99" in post
    assert "milestone_id" not in post


def test_open_mr_refuses_outside_a_run_branch(repo):
    env, log, out = open_mr_env(repo)
    r = run(OPEN_MR, repo["work"], env=env)  # still on main
    assert r.returncode != 0
    assert "run branch" in r.stderr
    assert git(repo["bare"], "branch", "--list", "main") != ""
    assert not out.exists()


def test_open_mr_blocks_when_the_tracker_refuses(repo):
    on_run_branch(repo)
    glab = GLAB.replace(
        '*"-X POST"*"merge_requests"*) echo \'{"web_url":"https://gl.test/g/adlc-workspace/-/merge_requests/77"}\' ;;',
        '*"-X POST"*"merge_requests"*) echo "403 Forbidden: insufficient_scope" >&2; exit 1 ;;')
    env, log, out = open_mr_env(repo, glab=glab)
    r = run(OPEN_MR, repo["work"], env=env)
    assert r.returncode != 0
    assert "insufficient_scope" in r.stderr
    assert not out.exists()


def test_open_mr_refuses_a_non_intent_factory_branch(repo):
    git(repo["work"], "switch", "-q", "-c", "factory/mission/adlc-workspace-12")
    env, log, out = open_mr_env(repo)
    r = run(OPEN_MR, repo["work"], env=env)
    assert r.returncode != 0
    assert "factory/intent/" in r.stderr
    assert git(repo["bare"], "branch", "--list", "factory/mission/adlc-workspace-12") == ""


@pytest.mark.parametrize("scopes", ['{"scopes":["read_api","write_repository"]}', '{"message":"404 Not Found"}'])
def test_open_mr_preflights_token_scope_before_pushing(repo, scopes):
    on_run_branch(repo)
    env, log, out = open_mr_env(repo, {"FAKE_SCOPES": scopes})
    r = run(OPEN_MR, repo["work"], env=env)
    assert r.returncode != 0
    assert "scope" in r.stderr
    # Blocked before any mutation: nothing pushed, no MR, no output.
    assert git(repo["bare"], "branch", "--list", "factory/intent/adlc-workspace-12") == ""
    assert "-X POST" not in log.read_text()
    assert not out.exists()


def test_open_mr_tracker_refusal_after_preflight_writes_nothing(repo):
    on_run_branch(repo)
    glab = GLAB.replace(
        '*"-X POST"*"merge_requests"*) echo \'{"web_url":"https://gl.test/g/adlc-workspace/-/merge_requests/77"}\' ;;',
        '*"-X POST"*"merge_requests"*) echo "403 Forbidden" >&2; exit 1 ;;')
    env, log, out = open_mr_env(repo, glab=glab)
    r = run(OPEN_MR, repo["work"], env=env)
    assert r.returncode != 0
    assert not out.exists()


GH = r'''
echo "$*" >> "$FAKE_LOG"
case "$*" in
  *"-i user"*) printf 'HTTP/2.0 200 OK\r\nX-Oauth-Scopes: %s\r\n\r\n{"login":"runner-bot"}\n' "${FAKE_GH_SCOPES-repo, read:org}" ;;
  *) echo '[]' ;;
esac
'''


def test_open_mr_github_preflight_blocks_without_repo_scope(repo):
    git(repo["work"], "remote", "set-url", "origin", "https://github.com/g/adlc-workspace.git")
    git(repo["work"], "config", f"url.{repo['bare']}.insteadOf", "https://github.com/g/adlc-workspace.git")
    on_run_branch(repo)
    bin_dir = fake_cli(repo["tmp"], "gh", GH)
    env, log, out = open_mr_env(repo, {"ISSUE_PROVIDER": "github", "FAKE_GH_SCOPES": "read:org",
                                       "PATH": f"{bin_dir}:{os.environ['PATH']}"})
    r = run(OPEN_MR, repo["work"], env=env)
    assert r.returncode != 0
    assert "scope" in r.stderr
    assert git(repo["bare"], "branch", "--list", "factory/intent/adlc-workspace-12") == ""


# ── empty runs and the always-call rule ────────────────────────────────────

def test_open_mr_skips_an_empty_run(repo):
    # Run branch with no commits beyond the base: nothing to review, so no
    # push, no tracker call, no MR, and no mr_url (the gate shows no link).
    run(RUN_BRANCH, repo["work"], env=RUN_ENV)
    env, log, out = open_mr_env(repo)
    r = run(OPEN_MR, repo["work"], env=env)
    assert r.returncode == 0, r.stderr
    assert r.stdout.strip() == ""
    assert "no commits" in r.stderr
    assert not log.exists()
    assert git(repo["bare"], "branch", "--list", "factory/intent/adlc-workspace-12") == ""
    assert not out.exists()


def test_open_mr_reuses_the_mr_when_a_redispatch_adds_nothing(repo, tmp_path):
    # A re-dispatch continues the pushed branch; it has commits beyond the base
    # even if this run committed nothing, so the existing MR is reused.
    on_run_branch(repo)
    git(repo["work"], "push", "-q", "origin", "factory/intent/adlc-workspace-12")
    existing = '[{"web_url":"https://gl.test/g/adlc-workspace/-/merge_requests/70"}]'
    env, log, out = open_mr_env(repo, {"FAKE_EXISTING": existing})
    r = run(OPEN_MR, repo["work"], env=env)
    assert r.returncode == 0, r.stderr
    assert r.stdout.strip().endswith("/merge_requests/70")


@pytest.mark.parametrize("skill", ["factory-product", "factory-architect"])
def test_orchestrators_always_call_open_mr_and_leave_approval_to_the_gate(skill):
    text = (ROOT / f"skills/factory/{skill}/SKILL.md").read_text()
    assert "**Before you return, always:**" in text
    assert "even when nothing was committed" in text
    assert "do not ask for approval yourself" in text


# ── deletions inside the allowlist ─────────────────────────────────────────

def test_commit_step_commits_a_promoted_drafts_deletion(repo):
    # A promotion moves .adlc/drafts/pdr/X.md to docs/adlc/memory/pdr/X.md. The
    # agent passes the new path only; the old draft's deletion must still be
    # committed, or the engine's gate refuses the "uncommitted draft".
    w = repo["work"]
    write(w, ".adlc/drafts/pdr/PDR-7.md", "draft\n")
    git(w, "add", "-A")
    git(w, "commit", "-q", "-m", "draft")
    (w / ".adlc/drafts/pdr/PDR-7.md").unlink()
    write(w, "docs/adlc/memory/pdr/PDR-7.md", "accepted\n")
    r = run(COMMIT_STEP, w, *STEP_ARGS, "docs/adlc/memory/pdr/PDR-7.md", env=RUN_ENV)
    assert r.returncode == 0, r.stderr
    assert git(w, "status", "--short") == ""
    changed = git(w, "show", "--name-status", "--format=", "HEAD").splitlines()
    assert "D\t.adlc/drafts/pdr/PDR-7.md" in changed
    assert "A\tdocs/adlc/memory/pdr/PDR-7.md" in changed


def test_commit_step_leaves_deletions_outside_the_allowlist(repo):
    w = repo["work"]
    (w / "README.md").unlink()
    write(w, ".adlc/drafts/pdr/PDR-8.md", "d\n")
    r = run(COMMIT_STEP, w, *STEP_ARGS, ".adlc/drafts/pdr/PDR-8.md", env=RUN_ENV)
    assert r.returncode == 0, r.stderr
    assert "README.md" not in git(w, "show", "--name-only", "--format=", "HEAD")
    assert git(w, "status", "--short") == "D README.md"


def test_commit_step_commits_a_deletion_alone(repo):
    # A step whose only change is removing a draft still makes its commit.
    w = repo["work"]
    write(w, ".adlc/drafts/adr/ADR-9.md", "x\n")
    git(w, "add", "-A")
    git(w, "commit", "-q", "-m", "draft")
    (w / ".adlc/drafts/adr/ADR-9.md").unlink()
    r = run(COMMIT_STEP, w, *STEP_ARGS, ".adlc/drafts/adr/ADR-9.md", env=RUN_ENV)
    assert r.returncode == 0, r.stderr
    assert r.stdout.startswith("sha: ") and r.stdout.strip() != "sha: none"
    assert git(w, "status", "--short") == ""


@pytest.mark.parametrize("skill", ["factory-product", "factory-architect"])
def test_orchestrators_pass_moved_and_deleted_paths(skill):
    text = (ROOT / f"skills/factory/{skill}/SKILL.md").read_text()
    assert "every path the step wrote, moved or deleted" in text


def test_factory_mission_checklist_takes_the_issue_and_reports_the_mr():
    # adlc-workspace#12 M9 pilot, run 84412db5: the engine's execute step ran
    # factory-mission without --issue; the skill asked for a mission and
    # returned, and the completion gate had nothing to link.
    text = (ROOT / "skills/factory/factory-mission/SKILL.md").read_text()
    head = "## In a factory run — read this first"
    assert head in text
    assert text.index(head) < text.index("## What this skill does")
    block = text[text.index(head):text.index("## What this skill does")]
    for needle in ("--issue <ref>", "ADLC_ISSUE_REF", "ADLC_STEP_OUTPUT", "mr_url", "conclusion", "Never ask a question"):
        assert needle in block, needle


@pytest.mark.parametrize("skill", ["factory-product", "factory-architect"])
def test_factory_run_checklist_comes_first(skill):
    # Drill run b664753d: the architecture orchestrator had the rules but read
    # them too late; they now open the skill.
    text = (ROOT / f"skills/factory/{skill}/SKILL.md").read_text()
    head = "## In a factory run — read this first"
    assert head in text
    assert text.index(head) < text.index("## What this skill does")
    block = text[text.index(head):text.index("## What this skill does")]
    for needle in ("run-branch.sh", "commit-step.sh", "open-mr.sh", "Never ask for approval", "conclusion"):
        assert needle in block, needle
