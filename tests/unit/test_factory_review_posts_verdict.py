"""A factory review is not done until its verdict is on the PR/MR (SF-SKILL-01).

Live evidence: review runs adlc-review-octopus-next-9d8cw (octopus-next!1298)
and adlc-review-push-octopus-next-nwmd8 (!1302), 2026-11-09, composed a full
verdict, ended with it as the agent's final message, posted nothing, and the
runs reported Succeeded; adlc-argo-wf!84 and agentic-container!55 ended with
"verdict preview — not yet posted". These tests pin:

- the skill text: post through post-verdict.sh, read back, never end with the
  verdict only in the final message, a project review skill never makes it a
  draft; the tracker reference offers the `glab api` path that works in runner
  pods (S38) and the read-back after a verdict;
- the script (bash, and its PowerShell twin where pwsh exists): it refuses a
  malformed body, posts, confirms by read-back, retries a silently lost post,
  fails (exit 1) when the verdict never lands, never posts twice, and fails
  closed (exit 2) when the thread is unreadable.
"""
import json
import os
import shutil
import stat
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).parent.parent.parent
SKILL = ROOT / "skills/factory/factory-review/SKILL.md"
TRACKER = ROOT / "skills/factory/factory-runbook/references/tracker-integration.md"
SCRIPT = ROOT / "skills/factory/factory-review/scripts/bash/post-verdict.sh"
PS_SCRIPT = ROOT / "skills/factory/factory-review/scripts/powershell/post-verdict.ps1"

HEAD = "410db874b0a3c56f2c3b2d3e0f1a2b3c4d5e6f70"
RUN = "d82c9b6f-c5b7-458d-b74a-d5b01505221a"
MR = "tikalk/engineering/octopus-next!1298"
PR = "tikalk/adlc-team-skills#166"
MARKER = (f"<!-- factory-review:step=review run={RUN} iter=0 status=completed "
          f"outcome=merge-ready findings=2 important=0 nits=2 head={HEAD} -->")
BODY = MARKER + "\n\n## Verdict\n**Outcome:** merge-ready\n\n## Important findings\nNone.\n\n## Nits\n### N1 — a\n\n### N2 — b\n"

# A fake `glab api` / `gh api`. State in $FAKE_TRACKER_DIR: notes.json (the
# thread), comments.json (GitHub issue comments), calls.log, posted.jsonl.
# Knobs: FAKE_DROP=1 accept posts but never store them (the silent-loss case);
# FAKE_REFUSE=1 refuse posts; FAKE_READ_FAIL=1 fail every GET;
# FAKE_READ_GARBAGE=1 answer GETs with non-JSON; FAKE_PAGES=1 answer a
# --paginate GET as two concatenated arrays; FAKE_PAGE_SIZE=<n> answer a GET
# of the thread with its first n comments only, unless --paginate is passed.
# A refusal prints the HTTP status on stderr the way the real CLIs do.
FAKE = r'''#!/usr/bin/env bash
set -u
d="${FAKE_TRACKER_DIR:?}"
[ "${1:-}" = api ] || { echo "fake: only 'api' is supported" >&2; exit 64; }
shift
method=GET path="" input="" paginate=0
while [ $# -gt 0 ]; do
  case "$1" in
    --hostname) echo "$2" >> "$d/hosts.log"; shift 2 ;;
    -X) method="$2"; shift 2 ;;
    -H) shift 2 ;;
    --input) input="$2"; shift 2 ;;
    --paginate) paginate=1; shift ;;
    *) path="$1"; shift ;;
  esac
done
echo "$method $path" >> "$d/calls.log"
[ -f "$d/notes.json" ] || echo '[]' > "$d/notes.json"
if [ "$method" = GET ]; then
  [ "${FAKE_READ_FAIL:-0}" = 1 ] && { echo "fake: 500 Internal Server Error (HTTP 500)" >&2; exit 1; }
  [ "${FAKE_READ_GARBAGE:-0}" = 1 ] && { echo "<html>busy</html>"; exit 0; }
  case "$path" in
    */issues/*/comments*) cat "$d/comments.json" 2>/dev/null || echo '[]' ;;
    *) if [ "$paginate" = 1 ] && [ "${FAKE_PAGES:-0}" = 1 ]; then printf '[{"id":1,"body":"x"}]'; fi
       if [ -n "${FAKE_PAGE_SIZE:-}" ] && [ "$paginate" = 0 ]; then
         node -e 'const a = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8")); console.log(JSON.stringify(a.slice(0, Number(process.argv[2]))))' "$d/notes.json" "$FAKE_PAGE_SIZE"
       else
         cat "$d/notes.json"
       fi ;;
  esac
  exit 0
fi
[ "${FAKE_REFUSE:-0}" = 1 ] && { printf 'fake: 403 Forbidden (HTTP 403)\ntry again later\n\n' >&2; exit 1; }
if [ "$input" = - ]; then body="$(cat)"; else body="$(cat "$input")"; fi
printf '%s\n' "$body" >> "$d/posted.jsonl"
[ "${FAKE_DROP:-0}" = 1 ] && { echo '{}'; exit 0; }
node -e '
  const fs = require("fs"); const [f, raw] = process.argv.slice(1);
  const notes = JSON.parse(fs.readFileSync(f, "utf8"));
  notes.unshift({id: 1000 + notes.length, body: JSON.parse(raw).body});
  fs.writeFileSync(f, JSON.stringify(notes)); console.log("{}");' "$d/notes.json" "$body"
'''

needs_tools = pytest.mark.skipif(shutil.which("bash") is None or shutil.which("node") is None,
                                 reason="needs bash and node")
INTERPRETERS = [
    pytest.param("bash", marks=[pytest.mark.requires_bash, needs_tools]),
    pytest.param("pwsh", marks=pytest.mark.skipif(shutil.which("pwsh") is None or shutil.which("node") is None,
                                                  reason="needs pwsh and node (CI runs it)")),
]


@pytest.fixture
def tracker(tmp_path):
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir()
    for name in ("glab", "gh"):
        p = bin_dir / name
        p.write_text(FAKE)
        p.chmod(p.stat().st_mode | stat.S_IEXEC)
    state = tmp_path / "state"
    state.mkdir()
    return {"bin": bin_dir, "state": state, "tmp": tmp_path}


def run(tracker, interpreter, *args, **knobs):
    # A lane run: the run id comes from WORKFLOW_INPUTS, as in a review pod
    # (the verdict schema requires the marker's run= to be this run's id).
    env = {k: v for k, v in os.environ.items() if not k.startswith("FAKE_") and k != "ADLC_RUN_ID"}
    env.update({"PATH": f"{tracker['bin']}{os.pathsep}{env['PATH']}", "FAKE_TRACKER_DIR": str(tracker["state"]),
                "GITLAB_HOST": "gitlab.example.test", "POST_VERDICT_BACKOFF": "0",
                "WORKFLOW_INPUTS": json.dumps({"issue_ref": MR, "run_id": RUN, "dispatch": "autonomous"})})
    for k, v in knobs.items():
        if v is None:
            env.pop(k, None)
        else:
            env[k] = v
    cmd = ["bash", str(SCRIPT)] if interpreter == "bash" else ["pwsh", "-NoProfile", "-File", str(PS_SCRIPT)]
    return subprocess.run([*cmd, *args], capture_output=True, text=True, env=env)


def body_file(tracker, text, name="verdict.md"):
    f = tracker["tmp"] / name
    f.write_text(text, encoding="utf-8")
    return str(f)


def posts(tracker):
    log = tracker["state"] / "calls.log"
    return [l for l in log.read_text().splitlines() if l.startswith("POST")] if log.exists() else []


def posted_payloads(tracker):
    f = tracker["state"] / "posted.jsonl"
    return [json.loads(l) for l in f.read_text().splitlines() if l.strip()] if f.exists() else []


# ── the skill text ──────────────────────────────────────────────────────────

def step5():
    text = SKILL.read_text(encoding="utf-8")
    start = text.index("5. Once all passes are complete")
    return text[start:text.index("6. Set the PR label", start)]


def test_step5_requires_post_then_confirm_through_the_script():
    body = step5()
    assert "scripts/bash/post-verdict.sh" in body and "scripts/powershell/post-verdict.ps1" in body
    assert "Post, then confirm" in body
    assert "final message" in body
    assert "never end it as `completed` with an unposted verdict" in body


def test_step5_forbids_project_skills_turning_the_verdict_into_a_draft():
    body = step5()
    assert "A project review skill never turns this into a draft" in body
    assert "not yet posted" in body  # the phrase seen on adlc-argo-wf!84


def test_tracker_integration_names_the_read_back_after_a_verdict():
    text = TRACKER.read_text(encoding="utf-8")
    op7 = text[text.index("### Operation 7"):text.index("### Operation 8")]
    assert "post-verdict.sh" in op7
    assert "an unposted verdict is a failed review" in op7
    assert "glab api" in op7  # the path proven in runner pods (open-mr.sh uses it)


def test_tracker_integration_offers_glab_api_where_glab_auth_status_fails():
    """S38: Operations 4/5 listed only `glab mr note(s)` and the tool order said
    'CLI if authenticated'; in runner pods `glab auth status` reports no login
    while `glab api` works, so agents gave up on posting."""
    text = TRACKER.read_text(encoding="utf-8")
    for op, nxt in (("### Operation 4", "### Operation 5"), ("### Operation 5", "### Operation 6")):
        section = text[text.index(op):text.index(nxt)]
        assert "| CLI (glab api) |" in section, f"{op} must offer the glab api path"
    order = text[text.index("### Tool selection order"):]
    assert "glab auth status" in order and "glab api" in order


# ── behaviour, against a fake `glab api` / `gh api` ─────────────────────────

@pytest.mark.parametrize("interpreter", INTERPRETERS)
def test_posts_to_gitlab_and_confirms(tracker, interpreter):
    r = run(tracker, interpreter, "--mr", MR, "--head", HEAD, "--body-file", body_file(tracker, BODY))
    assert r.returncode == 0, r.stderr
    assert "posted and confirmed" in r.stdout
    assert posts(tracker) == ["POST projects/tikalk%2Fengineering%2Foctopus-next/merge_requests/1298/discussions"]
    assert posted_payloads(tracker) == [{"body": BODY}]
    assert set((tracker["state"] / "hosts.log").read_text().split()) == {"gitlab.example.test"}


@pytest.mark.parametrize("interpreter", INTERPRETERS)
def test_posts_to_github_as_a_comment_review_bound_to_the_head(tracker, interpreter):
    r = run(tracker, interpreter, "--mr", PR, "--head", HEAD, "--body-file", body_file(tracker, BODY))
    assert r.returncode == 0, r.stderr
    assert posts(tracker) == ["POST repos/tikalk/adlc-team-skills/pulls/166/reviews"]
    assert posted_payloads(tracker) == [{"body": BODY, "event": "COMMENT", "commit_id": HEAD}]
    assert set((tracker["state"] / "hosts.log").read_text().split()) == {"github.com"}


@pytest.mark.parametrize("interpreter", INTERPRETERS)
def test_a_silently_lost_post_is_retried_then_fails(tracker, interpreter):
    r = run(tracker, interpreter, "--mr", MR, "--head", HEAD, "--body-file", body_file(tracker, BODY),
            "--retries", "3", FAKE_DROP="1")
    assert r.returncode == 1
    assert "the review failed" in r.stderr
    assert len(posts(tracker)) == 3


@pytest.mark.parametrize("interpreter", INTERPRETERS)
def test_a_refused_post_is_reported_and_fails(tracker, interpreter):
    r = run(tracker, interpreter, "--mr", MR, "--head", HEAD, "--body-file", body_file(tracker, BODY),
            "--retries", "2", FAKE_REFUSE="1")
    assert r.returncode == 1
    assert "attempt 1: the tracker refused the post" in r.stderr
    assert "attempt 2: the tracker refused the post" in r.stderr


@pytest.mark.parametrize("interpreter", INTERPRETERS)
def test_never_posts_twice_for_the_same_run_iter_head(tracker, interpreter):
    f = body_file(tracker, BODY)
    assert run(tracker, interpreter, "--mr", MR, "--head", HEAD, "--body-file", f).returncode == 0
    r = run(tracker, interpreter, "--mr", MR, "--head", HEAD, "--body-file", f)
    assert r.returncode == 0 and "not posted twice" in r.stdout
    assert len(posts(tracker)) == 1
    # A new iteration on the same head is a new verdict.
    r = run(tracker, interpreter, "--mr", MR, "--head", HEAD, "--body-file",
            body_file(tracker, BODY.replace("iter=0", "iter=1"), "v2.md"))
    assert r.returncode == 0 and "posted and confirmed" in r.stdout
    assert len(posts(tracker)) == 2


@pytest.mark.parametrize("interpreter", INTERPRETERS)
@pytest.mark.parametrize("text, why", [
    # the marker was on line 5 of octopus-next!1334 notes 87534/87543
    ("## Verdict\n\n**Outcome:** merge-ready\n\n" + MARKER + "\n", "first non-blank line"),
    (MARKER + "\n" + MARKER + "\n", "exactly one"),
    ("## Verdict\nno marker at all\n", "exactly one"),
    (MARKER.replace(HEAD, "0" * 40) + "\n", "but --head is"),
    (MARKER.replace(f"run={RUN} ", "") + "\n", "no run="),
    (MARKER.replace(f"run={RUN}", "run=../x") + "\n", "not a valid run id"),
], ids=["marker-not-first", "two-markers", "no-marker", "other-head", "no-run", "unsafe-run"])
def test_malformed_bodies_are_refused_before_posting(tracker, interpreter, text, why):
    r = run(tracker, interpreter, "--mr", MR, "--head", HEAD, "--body-file", body_file(tracker, text))
    assert r.returncode == 2 and why in r.stderr, r.stderr
    assert posts(tracker) == []


@pytest.mark.parametrize("interpreter", INTERPRETERS)
@pytest.mark.parametrize("args, knobs, why", [
    (["--mr", "1298"], {}, "--mr must be"),
    (["--mr", MR, "--head", HEAD[:7]], {}, "40-character"),
    (["--mr", MR], {"GITLAB_HOST": None}, "GITLAB_HOST is not set"),
    (["--mr", MR, "--retries", "0"], {}, "--retries takes 1-9"),
    (["--mr", MR, "--bogus"], {}, "unknown argument"),
], ids=["bare-iid", "short-head", "no-gitlab-host", "zero-retries", "unknown-arg"])
def test_usage_errors_exit_2_and_post_nothing(tracker, interpreter, args, knobs, why):
    full = list(args)
    if "--head" not in full:
        full += ["--head", HEAD]
    r = run(tracker, interpreter, *full, "--body-file", body_file(tracker, BODY), **knobs)
    assert r.returncode == 2 and why in r.stderr, r.stderr
    assert posts(tracker) == []


@pytest.mark.parametrize("interpreter", INTERPRETERS)
def test_check_only_reports_presence_and_absence(tracker, interpreter):
    r = run(tracker, interpreter, "--mr", MR, "--head", HEAD, "--check-only")
    assert r.returncode == 1 and "MISSING" in r.stdout
    run(tracker, interpreter, "--mr", MR, "--head", HEAD, "--body-file", body_file(tracker, BODY))
    r = run(tracker, interpreter, "--mr", MR, "--head", HEAD, "--check-only")
    assert r.returncode == 0 and "OK" in r.stdout
    r = run(tracker, interpreter, "--mr", MR, "--head", HEAD, "--check-only", "--run", RUN)
    assert r.returncode == 0
    r = run(tracker, interpreter, "--mr", MR, "--head", HEAD, "--check-only", "--run", "other-run")
    assert r.returncode == 1 and "run=other-run" in r.stdout
    assert len(posts(tracker)) == 1  # check-only never posts


@pytest.mark.parametrize("interpreter", INTERPRETERS)
def test_check_only_ignores_other_markers_and_other_heads(tracker, interpreter):
    notes = [
        {"id": 1, "body": f"<!-- factory-review:step=review-loop run={RUN} head={HEAD} -->"},
        {"id": 2, "body": MARKER.replace(HEAD, "1" * 40)},
        {"id": 3, "body": f"## Verdict\nquoted marker {MARKER}"},
    ]
    (tracker["state"] / "notes.json").write_text(json.dumps(notes))
    r = run(tracker, interpreter, "--mr", MR, "--head", HEAD, "--check-only")
    assert r.returncode == 0 and "comment 3" in r.stdout  # a marker anywhere in a posted comment counts


@pytest.mark.parametrize("interpreter", INTERPRETERS)
def test_github_paginated_pages_are_all_read(tracker, interpreter):
    (tracker["state"] / "notes.json").write_text(json.dumps([{"id": 77, "body": BODY}]))
    r = run(tracker, interpreter, "--mr", PR, "--head", HEAD, "--check-only", FAKE_PAGES="1")
    assert r.returncode == 0 and "comment 77" in r.stdout, r.stdout + r.stderr


@pytest.mark.parametrize("interpreter", INTERPRETERS)
@pytest.mark.parametrize("knob", ["FAKE_READ_FAIL", "FAKE_READ_GARBAGE"])
def test_unreadable_thread_fails_closed(tracker, interpreter, knob):
    r = run(tracker, interpreter, "--mr", MR, "--head", HEAD, "--check-only", **{knob: "1"})
    assert r.returncode == 2, r.stdout + r.stderr
    r = run(tracker, interpreter, "--mr", MR, "--head", HEAD, "--body-file", body_file(tracker, BODY), **{knob: "1"})
    assert r.returncode == 2
    assert posts(tracker) == []


# ── SF-FIX-11: a busy GitLab thread, and the tracker's own error text ───────

def _busy_thread(n):
    return [{"id": 5000 - i, "body": f"comment {i}", "system": i % 2 == 0} for i in range(n)]


@pytest.mark.parametrize("interpreter", INTERPRETERS)
def test_a_gitlab_verdict_older_than_one_page_is_found(tracker, interpreter):
    """The GitLab read was the newest 100 notes; system notes and inline diff
    notes count toward the 100. On a busy MR --check-only said MISSING for a
    verdict that was there, and the dedup lookup posted it a second time."""
    (tracker["state"] / "notes.json").write_text(json.dumps(_busy_thread(100) + [{"id": 77, "body": BODY}]))
    r = run(tracker, interpreter, "--mr", MR, "--head", HEAD, "--check-only", FAKE_PAGE_SIZE="100")
    assert r.returncode == 0 and "comment 77" in r.stdout, r.stdout + r.stderr
    r = run(tracker, interpreter, "--mr", MR, "--head", HEAD, "--body-file", body_file(tracker, BODY),
            FAKE_PAGE_SIZE="100")
    assert r.returncode == 0 and "not posted twice" in r.stdout, r.stdout + r.stderr
    assert posts(tracker) == []


@pytest.mark.parametrize("interpreter", INTERPRETERS)
@pytest.mark.parametrize("mr", [MR, PR])
def test_the_trackers_own_error_is_in_the_error_line(tracker, interpreter, mr):
    """A 401, a 403 and a 404 all read "cannot read the notes" / "the tracker
    refused the post"; the CLI's stderr line with the HTTP status is now kept."""
    r = run(tracker, interpreter, "--mr", mr, "--head", HEAD, "--check-only", FAKE_READ_FAIL="1")
    assert r.returncode == 2 and "cannot read the" in r.stderr
    assert "fake: 500 Internal Server Error (HTTP 500)" in r.stderr
    r = run(tracker, interpreter, "--mr", mr, "--head", HEAD, "--body-file", body_file(tracker, BODY),
            "--retries", "2", FAKE_REFUSE="1")
    assert r.returncode == 1
    assert r.stderr.count("the tracker refused the post — fake: 403 Forbidden (HTTP 403)") == 2


def test_never_calls_an_approve_endpoint():
    for script in (SCRIPT, PS_SCRIPT):
        text = script.read_text(encoding="utf-8")
        assert "/approve" not in text and "APPROVE" not in text, script.name


def test_both_twins_run_the_same_node_scripts():
    """The marker parser and the thread search are the same JavaScript in both
    twins, so the twins cannot disagree on what counts as a verdict."""
    sh = SCRIPT.read_text(encoding="utf-8")
    ps = PS_SCRIPT.read_text(encoding="utf-8")
    for bash_var, ps_var in (("MARKER_JS", "$markerJs"), ("FIND_JS", "$findJs")):
        js_sh = sh.split(f"{bash_var}='\n", 1)[1].split("\n'\n", 1)[0]
        js_ps = ps.split(f"{ps_var} = @'\n", 1)[1].split("\n'@", 1)[0]
        assert js_sh == js_ps, f"{bash_var} differs between the twins"


# ── SF-SKILL-02: the schema lint runs before anything is posted ─────────────

@pytest.mark.parametrize("interpreter", INTERPRETERS)
@pytest.mark.parametrize("text, why", [
    # an invented run id (octopus-next!1335 carried run=mr-1335)
    (BODY.replace(f"run={RUN}", "run=mr-1298"), "run=mr-1298 but this run is " + RUN),
    # findings=0 with a nit (octopus-next!1321)
    (BODY.replace("findings=2", "findings=0"), "findings=0 but important+nits=2"),
    # interactive wording (adlc-argo-wf!84)
    (BODY + "\nVerdict preview — not yet posted (needs your confirm)\n", "interactive hand-off"),
], ids=["invented-run-id", "inconsistent-counts", "interactive-wording"])
def test_a_body_that_fails_the_schema_is_never_posted(tracker, interpreter, text, why):
    r = run(tracker, interpreter, "--mr", MR, "--head", HEAD, "--body-file", body_file(tracker, text))
    assert r.returncode == 2, r.stdout + r.stderr
    assert "does not follow the verdict schema" in r.stderr and why in r.stderr
    assert posts(tracker) == []


def test_post_verdict_lints_before_it_posts():
    for script, needle in ((SCRIPT, 'verdict-schema.sh" lint'), (PS_SCRIPT, "'verdict-schema.ps1') lint")):
        text = script.read_text(encoding="utf-8")
        assert needle in text, script.name
        assert text.index(needle) < text.index("-X"), f"{script.name}: lint must run before the POST"

