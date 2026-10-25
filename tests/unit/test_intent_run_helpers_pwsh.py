"""PowerShell twins of the intent run helpers (CDR-022: bash + powershell
twin pairs, never python; the twin contract for adlc-team-skills #81).

Mirrors test_intent_run_helpers.py against scripts/powershell/*.ps1 so both
twins are pinned to the same contract (run-branch / commit-step / open-mr,
ADR-431-amendment, ADR-444; adlc-workspace#26). Shared helpers (repo fixture
logic, fake tracker CLI, STEP_ARGS) are imported from the bash module; only
the interpreter differs. Skipped when pwsh is not installed (CI runs it).
"""

import os
import shutil
import subprocess
from pathlib import Path

import pytest

from test_intent_run_helpers import (
    GLAB,
    RUN_ENV,
    STEP_ARGS,
    fake_cli,
    git,
    write,
)

ROOT = Path(__file__).parent.parent.parent
SCRIPTS = ROOT / "skills/factory/factory-mission/scripts"
BASH = SCRIPTS / "bash"
PS = SCRIPTS / "powershell"

pytestmark = pytest.mark.skipif(
    shutil.which("pwsh") is None or shutil.which("git") is None or shutil.which("node") is None,
    reason="needs pwsh, git and node (bash twins are covered by test_intent_run_helpers)",
)


@pytest.fixture
def repo(tmp_path):
    """Same offline workspace clone as the bash module (origin rewritten to a
    local bare repo via insteadOf, so fetch/push never leave the machine)."""
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


def run(script, cwd, *args, env=None):
    full_env = {k: v for k, v in os.environ.items() if not k.startswith("ADLC_")}
    full_env.update(env or {})
    return subprocess.run(["pwsh", "-NoProfile", "-File", str(script), *args],
                          cwd=cwd, capture_output=True, text=True, env=full_env)


# ── twin inventory (CDR-022, scoped to factory-mission) ────────────────────

def test_every_bash_helper_has_a_powershell_twin_and_vice_versa():
    bash = {p.name[:-3] for p in BASH.glob("*.sh")}
    ps = {p.name[:-4] for p in PS.glob("*.ps1")}
    assert bash == ps, f"twin mismatch: bash-only={bash - ps} powershell-only={ps - bash}"


# ── run-branch ─────────────────────────────────────────────────────────────

def test_run_branch_noop_without_run_context(repo):
    r = run(PS / "run-branch.ps1", repo["work"])
    assert r.returncode == 0, r.stderr
    assert r.stdout.strip() == ""
    assert git(repo["work"], "branch", "--show-current") == "main"


def test_run_branch_creates_issue_branch_in_project_root(repo):
    r = run(PS / "run-branch.ps1", repo["work"], env=RUN_ENV)
    assert r.returncode == 0, r.stderr
    assert r.stdout.strip() == "factory/intent/adlc-workspace-12"
    assert git(repo["work"], "branch", "--show-current") == "factory/intent/adlc-workspace-12"


def test_run_branch_without_issue_uses_run_id(repo):
    r = run(PS / "run-branch.ps1", repo["work"], env={"ADLC_RUN_ID": "r26"})
    assert r.returncode == 0, r.stderr
    assert r.stdout.strip() == "factory/intent/run-r26"


def test_run_branch_reuses_local_branch(repo):
    run(PS / "run-branch.ps1", repo["work"], env=RUN_ENV)
    (repo["work"] / "x.txt").write_text("1\n")
    git(repo["work"], "add", "-A")
    git(repo["work"], "commit", "-q", "-m", "on branch")
    git(repo["work"], "switch", "-q", "main")
    r = run(PS / "run-branch.ps1", repo["work"], env=RUN_ENV)
    assert r.returncode == 0, r.stderr
    assert git(repo["work"], "log", "-1", "--format=%s") == "on branch"


def test_run_branch_continues_from_origin(repo, tmp_path):
    other = tmp_path / "other"
    subprocess.run(["git", "clone", "-q", str(repo["bare"]), str(other)], check=True)
    git(other, "config", "user.email", "o@t.local")
    git(other, "config", "user.name", "o")
    git(other, "switch", "-q", "-c", "factory/intent/adlc-workspace-12")
    (other / "y.txt").write_text("2\n")
    git(other, "add", "-A")
    git(other, "commit", "-q", "-m", "from another pod")
    git(other, "push", "-q", "origin", "factory/intent/adlc-workspace-12")
    r = run(PS / "run-branch.ps1", repo["work"], env=RUN_ENV)
    assert r.returncode == 0, r.stderr
    assert git(repo["work"], "log", "-1", "--format=%s") == "from another pod"


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
    run(PS / "run-branch.ps1", repo["work"], env=RUN_ENV)
    git(repo["work"], "push", "-q", "origin", "factory/intent/adlc-workspace-12")
    git(repo["work"], "switch", "-q", "main")
    _push_from_other_pod(repo, tmp_path, "newer on origin")
    r = run(PS / "run-branch.ps1", repo["work"], env=RUN_ENV)
    assert r.returncode == 0, r.stderr
    assert git(repo["work"], "log", "-1", "--format=%s") == "newer on origin"


def test_run_branch_halts_when_local_and_origin_diverged(repo, tmp_path):
    run(PS / "run-branch.ps1", repo["work"], env=RUN_ENV)
    git(repo["work"], "push", "-q", "origin", "factory/intent/adlc-workspace-12")
    _push_from_other_pod(repo, tmp_path, "remote side")
    (repo["work"] / "local.txt").write_text("l\n")
    git(repo["work"], "add", "-A")
    git(repo["work"], "commit", "-q", "-m", "local side")
    git(repo["work"], "switch", "-q", "main")
    r = run(PS / "run-branch.ps1", repo["work"], env=RUN_ENV)
    assert r.returncode != 0
    assert "diverged" in r.stderr
    assert git(repo["work"], "branch", "--show-current") == "main"


@pytest.mark.parametrize("ref", ["g/../evil#1", "g//x#1", "/g/x#1", "g/.x#1", "g/-x#1", "x#1", "g/x#1a"])
def test_run_branch_rejects_unsafe_issue_ref(repo, ref):
    r = run(PS / "run-branch.ps1", repo["work"], env={"ADLC_RUN_ID": "r26", "ADLC_ISSUE_REF": ref})
    assert r.returncode != 0, ref
    assert git(repo["work"], "branch", "--show-current") == "main"


# ── commit-step ────────────────────────────────────────────────────────────

def test_commit_step_commits_with_trailers(repo):
    w = repo["work"]
    write(w, ".adlc/drafts/pdr/PDR-127.md", "a\n")
    r = run(PS / "commit-step.ps1", w, *STEP_ARGS, ".adlc/drafts/pdr/PDR-127.md", env=RUN_ENV)
    assert r.returncode == 0, r.stderr
    assert r.stdout.startswith("sha: ") and r.stdout.strip() != "sha: none"
    body = git(w, "log", "-1", "--format=%B")
    assert "Run-Id: r26" in body
    assert "Step: specify" in body
    assert "Output-Type: draft" in body
    assert "Records: PDR-127,PDR-128" in body


def test_commit_step_only_commits_its_paths(repo):
    w = repo["work"]
    write(w, ".adlc/drafts/pdr/PDR-1.md", "a\n")
    write(w, "README.md", "changed\n")
    head = git(w, "rev-parse", "HEAD")
    r = run(PS / "commit-step.ps1", w, *STEP_ARGS, ".adlc/drafts/pdr/PDR-1.md", env=RUN_ENV)
    assert r.returncode == 0, r.stderr
    assert git(w, "log", "-1", "--format=%B").startswith("docs(adlc): factory-product specify")
    # README.md changed but was not in the step's paths: still uncommitted
    # (git() strips output, so the leading unstaged-space marker is gone —
    # "M README.md" here means worktree-modified, index-clean).
    assert git(w, "status", "--short") == "M README.md"
    assert git(w, "diff", "--cached", "--name-only") == ""
    assert head != git(w, "rev-parse", "HEAD")


def test_commit_step_sha_none_when_unchanged(repo):
    w = repo["work"]
    write(w, ".adlc/drafts/pdr/PDR-1.md", "a\n")
    run(PS / "commit-step.ps1", w, *STEP_ARGS, ".adlc/drafts/pdr/PDR-1.md", env=RUN_ENV)
    r = run(PS / "commit-step.ps1", w, *STEP_ARGS, ".adlc/drafts/pdr/PDR-1.md", env=RUN_ENV)
    assert r.returncode == 0, r.stderr
    assert r.stdout.strip() == "sha: none"


def test_commit_step_noop_without_run_context_or_opt_in(repo):
    w = repo["work"]
    write(w, ".adlc/drafts/pdr/PDR-1.md", "a\n")
    head = git(w, "rev-parse", "HEAD")
    r = run(PS / "commit-step.ps1", w, *STEP_ARGS, ".adlc/drafts/pdr/PDR-1.md")
    assert r.returncode == 0, r.stderr
    assert r.stdout.strip() == "sha: none"
    assert git(w, "rev-parse", "HEAD") == head


def test_commit_step_interactive_opt_in_flag(repo):
    w = repo["work"]
    write(w, ".adlc/drafts/pdr/PDR-1.md", "a\n")
    args = list(STEP_ARGS)
    args.insert(0, "--commit")
    r = run(PS / "commit-step.ps1", w, *args, ".adlc/drafts/pdr/PDR-1.md")
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
    r = run(PS / "commit-step.ps1", w, *STEP_ARGS, path, env=RUN_ENV)
    assert r.returncode != 0
    assert "allowlist" in r.stderr or "outside" in r.stderr
    assert git(w, "rev-parse", "HEAD") == head
    assert git(w, "diff", "--cached", "--name-only") == ""


def test_commit_step_rejects_a_multiline_summary_and_bad_output_type(repo):
    w = repo["work"]
    write(w, ".adlc/drafts/pdr/PDR-1.md", "a\n")
    bad = list(STEP_ARGS)
    bad[bad.index("draft")] = "anything"
    assert run(PS / "commit-step.ps1", w, *bad, ".adlc/drafts/pdr/PDR-1.md", env=RUN_ENV).returncode != 0
    ml = list(STEP_ARGS)
    ml[ml.index("two PDR drafts")] = "line one\nSigned-off-by: someone"
    r = run(PS / "commit-step.ps1", w, *ml, ".adlc/drafts/pdr/PDR-1.md", env=RUN_ENV)
    assert r.returncode == 0, r.stderr
    assert git(w, "log", "-1", "--format=%s") == "docs(adlc): factory-product specify — line one Signed-off-by: someone"
    assert "Signed-off-by" not in git(w, "log", "-1", "--format=%(trailers:only)")


# ── open-mr ────────────────────────────────────────────────────────────────

def open_mr_env(repo, extra=None, glab=GLAB):
    bin_dir = fake_cli(repo["tmp"], "glab", glab)
    log = repo["tmp"] / "glab.log"
    out = repo["tmp"] / "steps" / "intent.output.json"
    env = dict(RUN_ENV, PATH=f"{bin_dir}:{os.environ['PATH']}", FAKE_LOG=str(log),
               ADLC_STEP_OUTPUT=str(out), GITLAB_HOST="gl.test")
    env.update(extra or {})
    return env, log, out


def on_run_branch(repo):
    run(PS / "run-branch.ps1", repo["work"], env=RUN_ENV)
    write(repo["work"], ".adlc/drafts/pdr/PDR-1.md", "a\n")
    run(PS / "commit-step.ps1", repo["work"], *STEP_ARGS, ".adlc/drafts/pdr/PDR-1.md", env=RUN_ENV)


def test_open_mr_noop_without_run_context(repo):
    env, log, out = open_mr_env(repo)
    r = run(PS / "open-mr.ps1", repo["work"], env={"PATH": env["PATH"]})
    assert r.returncode == 0, r.stderr
    assert not out.exists()


def test_open_mr_creates_a_draft_mr_with_issue_ownership(repo):
    on_run_branch(repo)
    env, log, out = open_mr_env(repo)
    r = run(PS / "open-mr.ps1", repo["work"], env=env)
    assert r.returncode == 0, r.stderr
    assert r.stdout.strip() == "https://gl.test/g/adlc-workspace/-/merge_requests/77"
    import json as _json
    assert _json.loads(out.read_text())["mr_url"] == "https://gl.test/g/adlc-workspace/-/merge_requests/77"
    calls = log.read_text()
    assert "milestone_id=407" in calls
    assert "assignee_ids[]=5" in calls


def test_open_mr_reuses_an_open_mr_and_keeps_other_output_fields(repo):
    on_run_branch(repo)
    env, log, out = open_mr_env(repo, extra={"FAKE_EXISTING": '[{"web_url":"https://gl.test/g/adlc-workspace/-/merge_requests/9"}]'})
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text('{"conclusion": "two PDR drafts"}')
    r = run(PS / "open-mr.ps1", repo["work"], env=env)
    assert r.returncode == 0, r.stderr
    assert r.stdout.strip() == "https://gl.test/g/adlc-workspace/-/merge_requests/9"
    assert "-X POST" not in log.read_text()  # reused, not created
    import json as _json
    data = _json.loads(out.read_text())
    assert data["mr_url"] == "https://gl.test/g/adlc-workspace/-/merge_requests/9"
    assert data["conclusion"] == "two PDR drafts"


def test_open_mr_assignee_falls_back_to_the_runner(repo):
    on_run_branch(repo)
    glab = GLAB.replace('{"milestone":{"id":407},"assignees":[{"id":5}]}', '{"milestone":null,"assignees":[]}')
    env, log, out = open_mr_env(repo, glab=glab)
    r = run(PS / "open-mr.ps1", repo["work"], env=env)
    assert r.returncode == 0, r.stderr
    assert "assignee_ids[]=99" in log.read_text()


def test_open_mr_blocks_when_the_tracker_token_lacks_the_api_scope(repo):
    on_run_branch(repo)
    env, log, out = open_mr_env(repo, extra={"FAKE_SCOPES": '{"scopes":["read_api"]}'})
    r = run(PS / "open-mr.ps1", repo["work"], env=env)
    assert r.returncode != 0
    assert "scope" in r.stderr
    assert "merge_requests" not in log.read_text().split("personal_access_tokens/self")[0]
