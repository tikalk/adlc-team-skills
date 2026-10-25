"""The factory-review verdict must name the head it certifies — and be checkable.

A verdict certifies exactly one head SHA. A fix push moves the head and
invalidates the verdict, so the review has to run again before
merge-readiness is claimed. The rule is stated in the skill; these tests pin
both halves of it:

  * the marker the skill tells the reviewer to post actually carries
    ``head=<sha>`` — without it the verdict certifies nothing, and
  * the checker that enforces it exists, behaves correctly, and is wired
    into CI.

Everything that comes back from GitHub is untrusted: the repository is
public, so any account can comment, and a comment body can say anything. The
checker therefore never parses a body. jq extracts the fields it needs — the
timestamp, the author, the author's association and the head named inside the
review marker — and the checker parses only those. The tests below pin that
property as well: a body must not be able to create a record, choose a
record's timestamp, or otherwise reach the comparison.
"""

import json
import os
import re
import signal
import subprocess
import time
from pathlib import Path

import pytest
import yaml

ROOT = Path(__file__).parent.parent.parent
SKILL = ROOT / "skills/factory/factory-review"
SKILL_MD = SKILL / "SKILL.md"
LOOP_MD = SKILL / "references/review-loop.md"
CHECKER = SKILL / "scripts/bash/check-verdict-head.sh"
WORKFLOW = ROOT / ".github/workflows/verdict-head.yml"

MARKER = "factory-review:step=review"


def run_checker(tmp_path, bodies, pr_head, *extra):
    """Run the checker over a fixture of comment bodies; return (rc, output).

    `extra` carries optional flags (e.g. `--require-outcome`), so a test can
    exercise the merge-gate mode without the helper growing a new signature
    per flag.
    """
    fixture = tmp_path / "verdicts.txt"
    fixture.write_text(bodies, encoding="utf-8")
    proc = subprocess.run(
        ["bash", str(CHECKER), "--verdicts", str(fixture), "--pr-head", pr_head, *extra],
        capture_output=True,
        text=True,
        timeout=30,
    )
    return proc.returncode, proc.stdout + proc.stderr


def verdict(head, extra=""):
    return (
        f"<!-- {MARKER} run=r1 iter=0 status=completed findings=1 "
        f"important=0 nits=1 {extra}head={head} -->\nA review comment.\n"
    )


def review_marker_templates(text):
    """Every review marker template in the text, joined across wrapped lines.

    The skill's diagram wraps the marker over two lines to fit the box, so
    the template has to be re-joined before it can be read as a marker.
    """
    joined = re.sub(r"\s*\n\s*", " ", text)
    return [m for m in re.findall(r"<!--.*?-->", joined) if MARKER in m]


def literal_marker_templates(text):
    """Every review marker template AS WRITTEN — the lines are not re-joined.

    This is the shape a reviewer copies out of the documentation: the marker
    may span two lines, and that is the shape the checker has to parse.
    """
    templates = []
    lines = text.split("\n")
    index = 0
    while index < len(lines):
        line = lines[index]
        if "<!-- " + MARKER in line:
            chunk = [line[line.index("<!--"):]]
            while "-->" not in chunk[-1] and index + 1 < len(lines):
                index += 1
                chunk.append(lines[index])
            joined = "\n".join(chunk)
            templates.append(joined[: joined.index("-->") + len("-->")])
        index += 1
    return templates


# ── the live path: a mocked `gh` on PATH ───────────────────────────────────
#
# `fetch_records` is the only code that talks to GitHub, so it is the only part
# of the checker the offline fixtures cannot reach. The mock serves canned
# payloads; the checker owns the filter that turns them into records, so the
# mock never sees a body of its own making.

MOCK_GH = '''#!/usr/bin/env python3
"""A mock `gh` for the verdict-head checker: serves canned PR payloads."""
import os
import sys
import time
from pathlib import Path


def main(argv):
    endpoint = None
    i = 0
    while i < len(argv):
        arg = argv[i]
        if arg == "--jq":
            print("mock gh: the checker owns the filter; it must not pass --jq", file=sys.stderr)
            return 1
        if arg in ("api", "--paginate") or arg.startswith("-"):
            i += 1
            continue
        endpoint = arg
        i += 1

    if endpoint is None:
        print("mock gh: no endpoint", file=sys.stderr)
        return 1
    if endpoint.endswith("/comments"):
        kind = "comments"
    elif endpoint.endswith("/reviews"):
        kind = "reviews"
    else:
        print("mock gh: unexpected endpoint %s" % endpoint, file=sys.stderr)
        return 1

    if os.environ.get("MOCK_FAIL") == kind:
        print("gh: API rate limit exceeded for %s" % endpoint, file=sys.stderr)
        return 1

    delay = os.environ.get("MOCK_SLEEP")
    if delay:
        time.sleep(float(delay))

    payload = Path(os.environ["MOCK_" + kind.upper()]).read_text(encoding="utf-8")
    sys.stdout.write(payload)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
'''


def comment(ts, body, assoc="MEMBER"):
    """An issue comment, as the comments API returns it."""
    return {
        "created_at": ts,
        "body": body,
        "user": {"login": "somebody"},
        "author_association": assoc,
    }


def review(ts, body):
    """A review, as the reviews API returns it."""
    return {
        "submitted_at": ts,
        "body": body,
        "user": {"login": "somebody"},
        "author_association": "MEMBER",
    }


def mock_gh_env(tmp_path, comments, reviews, env_extra=None, bin_scripts=None):
    """A PATH with a mock `gh` on it, serving the given payloads."""
    bin_dir = tmp_path / "bin"
    bin_dir.mkdir(parents=True, exist_ok=True)
    mock = bin_dir / "gh"
    mock.write_text(MOCK_GH, encoding="utf-8")
    mock.chmod(0o755)
    for name, content in (bin_scripts or {}).items():
        script = bin_dir / name
        script.write_text(content, encoding="utf-8")
        script.chmod(0o755)

    comments_file = tmp_path / "comments.json"
    comments_file.write_text(json.dumps(comments), encoding="utf-8")
    reviews_file = tmp_path / "reviews.json"
    reviews_file.write_text(json.dumps(reviews), encoding="utf-8")

    env = dict(os.environ)
    env["PATH"] = f"{bin_dir}{os.pathsep}{env['PATH']}"
    env["MOCK_COMMENTS"] = str(comments_file)
    env["MOCK_REVIEWS"] = str(reviews_file)
    if env_extra:
        env.update(env_extra)
    return env


def run_checker_live(
    tmp_path, comments, reviews, pr_head, fail=None, env_extra=None, bin_scripts=None
):
    """Run the checker against a mocked GitHub; return (rc, output)."""
    env = mock_gh_env(
        tmp_path, comments, reviews, env_extra=env_extra, bin_scripts=bin_scripts
    )
    if fail:
        env["MOCK_FAIL"] = fail

    proc = subprocess.run(
        [
            "bash",
            str(CHECKER),
            "--repo",
            "tikalk/adlc-team-skills",
            "--pr",
            "79",
            "--pr-head",
            pr_head,
        ],
        capture_output=True,
        text=True,
        timeout=30,
        env=env,
    )
    return proc.returncode, proc.stdout + proc.stderr


# ── the marker the skill tells the reviewer to post ────────────────────────

def test_skill_marker_template_carries_the_head():
    content = SKILL_MD.read_text(encoding="utf-8")
    templates = review_marker_templates(content)
    assert templates, "the skill must show the review marker template"
    for template in templates:
        assert "head=" in template, (
            "the review marker template must carry the head it certifies: "
            f"{template.strip()}"
        )


def test_review_loop_marker_template_carries_the_head():
    content = LOOP_MD.read_text(encoding="utf-8")
    templates = review_marker_templates(content)
    assert templates, "the review-loop reference must show the review marker"
    for template in templates:
        assert "head=" in template, (
            f"the review marker must carry the head it certifies: {template.strip()}"
        )


@pytest.mark.parametrize(
    ("document", "name"), [(SKILL_MD, "skill"), (LOOP_MD, "review-loop")]
)
def test_the_marker_template_carries_the_outcome(document, name):
    """The marker must say what the verdict concluded, not only which head.

    A verdict that names the current head can still be a `not-merge-ready`
    verdict, or one carrying open Important findings. Without an `outcome=`
    token the checker can tell a *current* verdict from a *stale* one but
    never a *mergeable* verdict from a *blocking* one — so the schema the
    docs publish has to carry the outcome the gate reads.
    """
    templates = review_marker_templates(document.read_text(encoding="utf-8"))
    assert templates, f"the {name} must show the review marker"
    for template in templates:
        assert "outcome=" in template, (
            f"the {name} review marker template must carry outcome=: {template.strip()}"
        )


@pytest.mark.parametrize(
    ("document", "name"), [(SKILL_MD, "skill"), (LOOP_MD, "review-loop")]
)
def test_the_marker_template_pins_the_full_schema(document, name):
    """Every field the gate reads is named in the published template.

    The schema is pinned field by field so a poster that drops one — the bare
    `status=… head=…` marker shape that reached the board — cannot silently
    satisfy the gate. Each field is asserted on the template as re-joined
    across the diagram's wrap, so a field that exists only on a line the box
    wrapped away still counts as present.
    """
    templates = review_marker_templates(document.read_text(encoding="utf-8"))
    assert templates, f"the {name} must show the review marker"
    for field in ("run=", "iter=", "status=", "outcome=", "head="):
        for template in templates:
            assert field in template, (
                f"the {name} review marker template must carry {field}: "
                f"{template.strip()}"
            )


@pytest.mark.parametrize(
    "document", [SKILL_MD, LOOP_MD], ids=["skill", "review-loop"]
)
def test_the_published_marker_template_is_accepted_as_written(tmp_path, document):
    """The template the docs publish must be a template the checker accepts.

    The skill's diagram wraps the marker over several lines to fit the box.
    The checker has to read the marker as it is written — the template and
    the checker have to agree, or the shipped template certifies nothing.
    """
    content = document.read_text(encoding="utf-8")
    templates = literal_marker_templates(content)
    assert templates, f"{document.name} must show the review marker template"
    head = "a" * 40
    for template in templates:
        body = template.replace("<sha>", head)
        rc, out = run_checker(tmp_path, body, head)
        assert rc == 0, (
            f"the checker must accept the published template as written "
            f"({template!r}): {out}"
        )


def test_the_label_step_does_not_promote_an_open_important_to_merge_ready():
    """The `validation` label names the lifecycle stage, not the verdict.

    The step used to set `validation` on both branches and then advise the
    code-owner of merge-readiness, so a PR carrying open Important findings
    read as awaiting a merge decision. Merge-readiness is carried by the
    marker's `outcome=` — the thing the gate can check — and the advice to
    the code-owner has to be conditional on it.
    """
    content = SKILL_MD.read_text(encoding="utf-8")
    step = next(
        (ln for ln in content.split("\n") if ln.lstrip().startswith("6. Set the PR label")),
        None,
    )
    assert step, "the label step must exist and begin '6. Set the PR label'"
    assert "outcome=" in step, (
        "the label step must tie merge-readiness to the marker's outcome= "
        f"field, not to the label: {step!r}"
    )
    assert "only when the verdict is `merge-ready`" in step, (
        "advice to the code-owner must be conditional on the verdict: "
        f"{step!r}"
    )


def test_skill_states_the_rule_and_names_the_checker():
    content = SKILL_MD.read_text(encoding="utf-8")
    assert "Re-review after any fix push" in content, (
        "the skill must state the re-review-after-fix rule"
    )
    assert "head=<sha>" in content, "the skill must require the head in the marker"
    assert "check-verdict-head.sh" in content, (
        "the skill must name the checker that enforces the rule"
    )


# ── the checker ───────────────────────────────────────────────────────────

def test_checker_exists_and_is_executable():
    assert CHECKER.exists(), f"the verdict checker is missing at {CHECKER}"
    assert os.access(CHECKER, os.X_OK), "the checker must be executable"


def test_verdict_naming_the_current_head_passes(tmp_path):
    rc, out = run_checker(tmp_path, verdict("a" * 40), "a" * 40)
    assert rc == 0, out
    assert "OK" in out


def test_verdict_on_a_moved_head_fails(tmp_path):
    rc, out = run_checker(tmp_path, verdict("a" * 40), "b" * 40)
    assert rc == 1, out
    assert "FAIL" in out
    assert "a" * 40 in out and "b" * 40 in out, "the failure must name both heads"


def test_no_verdict_is_not_a_failure(tmp_path):
    rc, out = run_checker(tmp_path, "A human comment with no marker.\n", "a" * 40)
    assert rc == 0, out
    assert "nothing to verify" in out


def test_a_pr_with_no_comments_and_no_reviews_passes(tmp_path):
    """Regression: zero comments + zero reviews used to hand the selector one
    blank record — a phantom verdict with empty fields that failed every
    fresh PR (seen live on adlc-team-skills #91)."""
    rc, out = run_checker_live(tmp_path, [], [], "a" * 40)
    assert rc == 0, out
    assert "nothing to verify" in out


def test_verdict_without_a_head_fails(tmp_path):
    """A verdict that names no head certifies nothing — it must not pass."""
    body = f"<!-- {MARKER} run=r1 iter=0 status=completed findings=0 important=0 nits=0 -->\n"
    rc, out = run_checker(tmp_path, body, "a" * 40)
    assert rc == 1, out
    assert "names no head" in out


def test_the_newest_verdict_wins(tmp_path):
    """An older verdict must not mask a newer one."""
    bodies = (
        verdict("a" * 40)
        + "%%%\n"
        + verdict("b" * 40)
    )
    rc, out = run_checker(tmp_path, bodies, "a" * 40)
    assert rc == 1, out
    assert "b" * 40 in out, "the newest verdict is the one that counts"

    rc, out = run_checker(tmp_path, bodies, "b" * 40)
    assert rc == 0, out


def test_non_verdict_markers_are_ignored(tmp_path):
    """A fix or converge marker is not a verdict — it must not be read as one."""
    bodies = (
        "<!-- factory-review:step=fix run=r1 iter=0 status=completed fixed=1 "
        "new_head_sha=" + "c" * 40 + " ci_status=pass -->\nA fix.\n"
        + "%%%\n"
        + verdict("a" * 40)
    )
    rc, out = run_checker(tmp_path, bodies, "a" * 40)
    assert rc == 0, out


def test_a_stale_fix_marker_does_not_satisfy_the_check(tmp_path):
    """Only the review verdict certifies; a fix marker never does."""
    bodies = (
        "<!-- factory-review:step=fix run=r1 iter=0 status=completed fixed=1 "
        "new_head_sha=" + "b" * 40 + " ci_status=pass -->\nA fix.\n"
    )
    rc, out = run_checker(tmp_path, bodies, "b" * 40)
    assert rc == 0, out
    assert "nothing to verify" in out


def test_missing_pr_head_is_a_usage_error(tmp_path):
    proc = subprocess.run(
        ["bash", str(CHECKER), "--verdicts", str(tmp_path / "nope.txt")],
        capture_output=True,
        text=True,
        timeout=30,
    )
    assert proc.returncode == 2, proc.stdout + proc.stderr


def test_a_trailing_flag_without_a_value_is_a_usage_error(tmp_path):
    """A flag with no value must not hang the parser."""
    for flag in ("--repo", "--pr", "--pr-head", "--verdicts"):
        proc = subprocess.run(
            ["bash", str(CHECKER), flag],
            capture_output=True,
            text=True,
            timeout=30,
        )
        out = proc.stdout + proc.stderr
        assert proc.returncode == 2, f"{flag} did not exit 2: {out}"
        assert "requires a value" in out, out


def test_a_head_that_is_not_a_full_sha_is_rejected(tmp_path):
    """A short SHA certifies nothing — it cannot be compared to a head."""
    rc, out = run_checker(tmp_path, verdict("abc1234"), "a" * 40)
    assert rc == 1, out
    assert "40-character SHA" in out


def test_a_missing_verdicts_file_is_an_error(tmp_path):
    """The offline path must not read a missing file as "no verdict"."""
    proc = subprocess.run(
        [
            "bash",
            str(CHECKER),
            "--verdicts",
            str(tmp_path / "nope.txt"),
            "--pr-head",
            "a" * 40,
        ],
        capture_output=True,
        text=True,
        timeout=30,
    )
    assert proc.returncode == 2, proc.stdout + proc.stderr
    assert "nothing to verify" not in proc.stdout + proc.stderr


# ── the live path (a mocked gh on PATH) ────────────────────────────────────

def test_the_live_path_picks_the_newest_verdict(tmp_path):
    """The newest verdict wins — an older one must not shadow it."""
    rc, out = run_checker_live(
        tmp_path,
        comments=[
            comment("2026-10-20T10:00:00Z", "A human note: we now add `head=<sha>` to the marker."),
            comment("2026-10-20T10:30:00Z", verdict("a" * 40)),
            comment("2026-10-20T11:40:45Z", verdict("b" * 40)),
        ],
        reviews=[],
        pr_head="b" * 40,
    )
    assert rc == 0, out
    assert "OK" in out


def test_the_live_path_reports_a_stale_verdict(tmp_path):
    rc, out = run_checker_live(
        tmp_path,
        comments=[comment("2026-10-20T11:40:45Z", verdict("a" * 40))],
        reviews=[],
        pr_head="b" * 40,
    )
    assert rc == 1, out
    assert "FAIL" in out
    assert "a" * 40 in out and "b" * 40 in out, "the failure must name both heads"


def test_a_review_body_newer_than_an_issue_comment_wins(tmp_path):
    """A verdict posted as a review is newer than one in the comment thread."""
    rc, out = run_checker_live(
        tmp_path,
        comments=[comment("2026-10-20T11:40:45Z", verdict("a" * 40))],
        reviews=[review("2026-10-20T12:00:00Z", verdict("b" * 40))],
        pr_head="b" * 40,
    )
    assert rc == 0, out


def test_prose_that_mentions_head_does_not_hijack_the_parse(tmp_path):
    """Only a head named INSIDE the marker counts."""
    rc, out = run_checker_live(
        tmp_path,
        comments=[
            comment(
                "2026-10-20T10:00:00Z",
                "We now write `head=<sha>` into the marker, so the check can read it back.",
            ),
            comment("2026-10-20T11:40:45Z", verdict("b" * 40)),
        ],
        reviews=[],
        pr_head="b" * 40,
    )
    assert rc == 0, out


def test_a_newer_comment_that_mentions_head_does_not_hijack_the_parse(tmp_path):
    """The marker scoping must hold on its own, not only via the ordering.

    Here the comment that mentions `head=` is the NEWEST one and it carries a
    verdict marker of its own, so nothing but the marker scoping itself can
    keep the mentioned head from being read as the verdict.
    """
    rc, out = run_checker_live(
        tmp_path,
        comments=[
            comment("2026-10-20T10:00:00Z", verdict("b" * 40)),
            comment(
                "2026-10-20T12:00:00Z",
                "The marker carries head=" + "a" * 40 + " so the check can read it back.\n"
                + verdict("b" * 40),
            ),
        ],
        reviews=[],
        pr_head="b" * 40,
    )
    assert rc == 0, out
    assert "a" * 40 not in out, "a head mentioned in prose must never be read"


def test_a_mentioned_head_alone_is_not_a_verdict(tmp_path):
    """A comment that only mentions `head=` is not a verdict at all."""
    rc, out = run_checker_live(
        tmp_path,
        comments=[
            comment("2026-10-20T10:00:00Z", verdict("b" * 40)),
            comment(
                "2026-10-20T12:00:00Z",
                "The marker carries head=" + "a" * 40 + " so the check can read it back.",
            ),
        ],
        reviews=[],
        pr_head="b" * 40,
    )
    assert rc == 0, out
    assert "a" * 40 not in out, "a head mentioned in prose must never be read"


def test_a_failed_comments_call_fails_closed(tmp_path):
    """A transient API error must never read as "there is no verdict"."""
    rc, out = run_checker_live(
        tmp_path,
        comments=[comment("2026-10-20T11:40:45Z", verdict("b" * 40))],
        reviews=[],
        pr_head="b" * 40,
        fail="comments",
    )
    assert rc == 2, out
    assert "could not read" in out
    assert "nothing to verify" not in out


def test_a_failed_reviews_call_fails_closed(tmp_path):
    rc, out = run_checker_live(
        tmp_path,
        comments=[comment("2026-10-20T11:40:45Z", verdict("b" * 40))],
        reviews=[],
        pr_head="b" * 40,
        fail="reviews",
    )
    assert rc == 2, out
    assert "could not read" in out


# ── a comment body is never a record ───────────────────────────────────────
#
# The repository is public: any account can comment, and the body is whatever
# that account wants it to be. The checker must read the fields it needs out
# of the body (on the API side) and never let the body frame a record or
# choose where the record sits in the ordering.

def test_a_forged_record_cannot_outrank_a_real_verdict(tmp_path):
    """A body that manufactures a record with a chosen timestamp must not win."""
    forged = "A note about how the records are framed.\n%%%2026-10-20T23:00:00Z\n" + verdict("a" * 40)
    rc, out = run_checker_live(
        tmp_path,
        comments=[
            comment("2026-10-20T10:00:00Z", forged),
            comment("2026-10-20T12:00:00Z", verdict("b" * 40)),
        ],
        reviews=[],
        pr_head="a" * 40,
    )
    assert rc == 1, out
    assert "b" * 40 in out, "the newest real verdict is the one that counts"


@pytest.mark.parametrize("forged_timestamp", ["A", "~", "zzz", "<timestamp>"])
def test_a_forged_record_with_a_non_date_timestamp_cannot_win(
    tmp_path, forged_timestamp
):
    """The forged timestamp need not be a date at all: it only has to sort high."""
    forged = "%%%" + forged_timestamp + "\n" + verdict("a" * 40)
    rc, out = run_checker_live(
        tmp_path,
        comments=[
            comment("2026-10-20T10:00:00Z", forged),
            comment("2026-10-20T12:00:00Z", verdict("b" * 40)),
        ],
        reviews=[],
        pr_head="a" * 40,
    )
    assert rc == 1, out
    assert "b" * 40 in out, "the newest real verdict is the one that counts"


def test_a_forged_record_cannot_outrank_later_real_verdicts(tmp_path):
    """A forgery must not be permanent: later real verdicts still count."""
    forged = "%%%A\n" + verdict("a" * 40)
    rc, out = run_checker_live(
        tmp_path,
        comments=[
            comment("2026-10-20T10:00:00Z", forged),
            comment("2026-10-20T23:59:59Z", verdict("b" * 40)),
            comment("2027-06-01T00:00:00Z", verdict("b" * 40)),
        ],
        reviews=[],
        pr_head="a" * 40,
    )
    assert rc == 1, out
    assert "b" * 40 in out, "the newest real verdict is the one that counts"


def test_a_body_that_documents_the_record_convention_is_harmless(tmp_path):
    """Merely documenting the convention must not change which verdict counts.

    This needs no deliberate attack: a reviewer who writes down how the
    records are framed — the placeholder at the start of a line — and quotes a
    marker in the same body would otherwise change the verdict the checker
    reads.
    """
    body = (
        "The record framing is introduced by the line below.\n"
        "%%%<timestamp>\n"
        + verdict("c" * 40)
    )
    rc, out = run_checker_live(
        tmp_path,
        comments=[
            comment("2026-10-20T10:00:00Z", body),
            comment("2026-10-20T12:00:00Z", verdict("b" * 40)),
        ],
        reviews=[],
        pr_head="b" * 40,
    )
    assert rc == 0, out
    assert "c" * 40 not in out, "a quoted marker must not become the verdict"


def test_a_body_cannot_hide_a_verdict_by_framing_it_as_another_record(tmp_path):
    """A body that puts a verdict behind a record boundary still counts."""
    body = "Some prose.\n%%%2026-10-20T23:00:00Z\n" + verdict("b" * 40)
    rc, out = run_checker_live(
        tmp_path,
        comments=[comment("2026-10-20T12:00:00Z", body)],
        reviews=[],
        pr_head="b" * 40,
    )
    assert rc == 0, out


def test_an_outsider_marker_does_not_override_a_collaborator_verdict(tmp_path):
    """A verdict only counts when it comes from a collaborator with the repo."""
    rc, out = run_checker_live(
        tmp_path,
        comments=[
            comment("2026-10-20T10:00:00Z", verdict("a" * 40)),
            comment("2026-10-20T12:00:00Z", verdict("b" * 40), assoc="NONE"),
        ],
        reviews=[],
        pr_head="b" * 40,
    )
    assert rc == 1, out
    assert "a" * 40 in out, "the collaborator's verdict is the one that counts"


def test_a_verdict_from_an_outsider_still_counts_when_no_collaborator_posted_one(
    tmp_path,
):
    """The check must not go green merely because it refused to read a verdict."""
    rc, out = run_checker_live(
        tmp_path,
        comments=[comment("2026-10-20T12:00:00Z", verdict("a" * 40), assoc="NONE")],
        reviews=[],
        pr_head="a" * 40,
    )
    assert rc == 0, out


def test_the_checker_does_not_advertise_the_record_separator(tmp_path):
    """The convention must not be advertised in a copy-pasteable form.

    A body that quotes the convention at the start of a line used to
    manufacture a record of its own. The checker must not hand that form out.
    """
    proc = subprocess.run(
        ["bash", str(CHECKER), "--help"],
        capture_output=True,
        text=True,
        timeout=30,
    )
    out = proc.stdout + proc.stderr
    assert proc.returncode == 0, out
    for line in out.split("\n"):
        assert not line.startswith("%%%"), (
            "the help output must not print the record separator at the start "
            f"of a line: {line!r}"
        )


def test_a_failed_call_leaves_no_temporary_file_behind(tmp_path):
    """The scratch file that holds gh's error must not survive the call."""
    scratch = tmp_path / "tmp"
    scratch.mkdir()
    rc, out = run_checker_live(
        tmp_path,
        comments=[comment("2026-10-20T11:40:45Z", verdict("b" * 40))],
        reviews=[],
        pr_head="b" * 40,
        fail="comments",
        env_extra={"TMPDIR": str(scratch)},
    )
    assert rc == 2, out
    assert list(scratch.iterdir()) == [], "the scratch file must be cleaned up"


def test_a_failing_mktemp_is_an_infrastructure_error(tmp_path):
    """`mktemp` can fail; the checker must say so, not fail obscurely."""
    rc, out = run_checker_live(
        tmp_path,
        comments=[comment("2026-10-20T11:40:45Z", verdict("b" * 40))],
        reviews=[],
        pr_head="b" * 40,
        bin_scripts={"mktemp": "#!/bin/sh\nexit 1\n"},
    )
    assert rc == 2, out
    assert "could not create a temporary file" in out, out


def test_an_interrupted_run_leaves_no_temporary_file_behind(tmp_path):
    """An interrupt must not leave the scratch file behind."""
    scratch = tmp_path / "scratch"
    scratch.mkdir()
    env = mock_gh_env(
        tmp_path,
        comments=[comment("2026-10-20T11:40:45Z", verdict("b" * 40))],
        reviews=[],
        env_extra={"TMPDIR": str(scratch), "MOCK_SLEEP": "30"},
    )
    proc = subprocess.Popen(
        [
            "bash",
            str(CHECKER),
            "--repo",
            "tikalk/adlc-team-skills",
            "--pr",
            "79",
            "--pr-head",
            "b" * 40,
        ],
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        start_new_session=True,
    )
    try:
        deadline = time.time() + 20
        while time.time() < deadline and not list(scratch.iterdir()):
            time.sleep(0.05)
        assert list(scratch.iterdir()), "the checker must have opened a scratch file"
        os.killpg(os.getpgid(proc.pid), signal.SIGINT)
        try:
            proc.communicate(timeout=20)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.communicate()
        time.sleep(0.2)
        assert list(scratch.iterdir()) == [], (
            "the scratch file must not survive an interrupt"
        )
    finally:
        if proc.poll() is None:
            proc.kill()
            proc.communicate()


# ── the merge gate: the marker's OUTCOME, not just its head ─────────────────
#
# The head check alone answers "is the verdict about the current head?" — it
# cannot answer "does the verdict say this PR may merge?". A verdict can name
# the current head and still carry `outcome=not-merge-ready`, or report open
# Important findings (which this repository's review policy treats as blocking
# a merge). `--require-outcome` opts the checker into that second question, so
# the default mode stays a pure staleness check and the gate mode fails closed
# on a verdict that does not certify merge-readiness.

MERGE_GATE = "--require-outcome"


def test_a_merge_ready_verdict_passes_the_gate(tmp_path):
    """The gate's passing case: the verdict is current AND says merge-ready."""
    body = verdict("a" * 40, extra="outcome=merge-ready ")
    rc, out = run_checker(tmp_path, body, "a" * 40, MERGE_GATE)
    assert rc == 0, out
    assert "OK" in out


def test_a_not_merge_ready_verdict_fails_the_gate(tmp_path):
    """Naming the current head is not enough: a not-merge-ready verdict must
    fail the gate even though the head matches exactly."""
    body = verdict("a" * 40, extra="outcome=not-merge-ready ")
    rc, out = run_checker(tmp_path, body, "a" * 40, MERGE_GATE)
    assert rc == 1, out
    assert "FAIL" in out


def test_open_important_findings_fail_the_gate(tmp_path):
    """A verdict that reports `important=1` cannot certify merge-readiness.

    The review policy treats an Important finding as blocking, so the gate
    must not pass a verdict that counts one — even if the poster labelled the
    outcome `merge-ready`. The count is the machine-checkable fact; the
    outcome string is the poster's summary of it.
    """
    body = (
        f"<!-- {MARKER} run=r1 iter=0 status=completed outcome=merge-ready "
        f"findings=3 important=1 nits=1 head={'a' * 40} -->\nA review.\n"
    )
    rc, out = run_checker(tmp_path, body, "a" * 40, MERGE_GATE)
    assert rc == 1, out
    assert "FAIL" in out


def test_a_verdict_without_an_outcome_fails_the_gate(tmp_path):
    """Failing closed on a marker that omits `outcome=`.

    A verdict posted against the older schema — the bare `status=… head=…`
    shape that reached the board — makes no claim about merge-readiness, so
    the gate must not treat its silence as a pass. Silence is not consent.
    """
    body = verdict("a" * 40)
    rc, out = run_checker(tmp_path, body, "a" * 40, MERGE_GATE)
    assert rc == 1, out
    assert "FAIL" in out


def test_no_verdict_fails_the_gate(tmp_path):
    """Under the gate, silence is a failure — not a pass.

    The default mode reports "nothing to verify" and exits 0 when no verdict
    exists, because staleness is undefined without one. The gate asks a
    different question: may this merge? A PR with no verdict at all has not
    been certified merge-ready, so the gate must fail rather than wave it
    through — otherwise the check is green for exactly the PRs nobody
    reviewed, which is how an ungated PR sits on the board unnoticed.
    """
    rc, out = run_checker(tmp_path, "A human comment with no marker.\n", "a" * 40, MERGE_GATE)
    assert rc == 1, out
    assert "FAIL" in out


def test_the_default_mode_stays_a_pure_staleness_check(tmp_path):
    """Backwards compatibility: without the flag, a not-merge-ready verdict on
    the current head still passes — the default question is only "is this
    verdict stale?". The gate's stricter reading is opt-in, so existing callers
    (and the older markers) keep their meaning until they ask for more."""
    body = verdict("a" * 40, extra="outcome=not-merge-ready ")
    rc, out = run_checker(tmp_path, body, "a" * 40)
    assert rc == 0, out
    assert "OK" in out


def test_the_gate_still_fails_on_a_stale_head(tmp_path):
    """The gate is an additional question, not a replacement: a stale head
    fails under the gate exactly as it does without it."""
    body = verdict("a" * 40, extra="outcome=merge-ready ")
    rc, out = run_checker(tmp_path, body, "b" * 40, MERGE_GATE)
    assert rc == 1, out
    assert "FAIL" in out


def test_a_prose_mention_of_outcome_cannot_hijack_the_gate(tmp_path):
    """An `outcome=` written in prose, outside any marker, is never read — the
    same rule the head token follows. A commenter writing `outcome=merge-ready`
    in a sentence cannot make a blocking verdict pass."""
    body = (
        verdict("a" * 40, extra="outcome=not-merge-ready ")
        + "Note for the record: outcome=merge-ready as far as I can tell.\n"
    )
    rc, out = run_checker(tmp_path, body, "a" * 40, MERGE_GATE)
    assert rc == 1, out


# ── CI wiring ─────────────────────────────────────────────────────────────

def test_ci_workflow_runs_the_checker():
    assert WORKFLOW.exists(), f"the CI workflow is missing at {WORKFLOW}"
    content = WORKFLOW.read_text(encoding="utf-8")
    assert "check-verdict-head.sh" in content, "the workflow must run the checker"
    assert "pull_request" in content, "the workflow must run on pull requests"
    assert "synchronize" in content, (
        "the workflow must re-run when the head moves — that is the whole point"
    )
    assert "pull-requests: read" in content, "the workflow must stay read-only"


def test_the_workflow_re_runs_when_the_verdict_lands():
    """The verdict is posted as an issue comment — the check must hear it.

    The trigger is asserted on the parsed workflow, not on a substring: the
    workflow mentions `issue_comment` in its own `if:` expression and in its
    header prose too, so a substring assertion cannot tell a missing trigger
    from a present one.
    """
    content = WORKFLOW.read_text(encoding="utf-8")
    workflow = yaml.safe_load(content)
    triggers = workflow.get("on", workflow.get(True))
    assert isinstance(triggers, dict), f"the workflow has no `on:` block: {triggers!r}"
    assert "issue_comment" in triggers, (
        "the verdict is posted with `gh pr comment`, so the workflow must "
        "listen for issue_comment or it can never turn green after a fix"
    )
    assert triggers["issue_comment"]["types"] == ["created", "edited"]
    assert triggers["pull_request"]["types"] == ["opened", "synchronize", "reopened"]
    assert triggers["pull_request_review"]["types"] == ["submitted", "edited"]
    assert "github.event.pull_request.number || github.event.issue.number" in content, (
        "the PR number must be read from the payload of every trigger — a "
        "pull_request_review payload carries no top-level number"
    )
    assert ".head.sha" in content and "pulls/" in content, (
        "an issue_comment payload carries no head SHA, so the head must be "
        "resolved from the API when the event does not carry one"
    )


def test_the_workflow_stays_read_only():
    content = WORKFLOW.read_text(encoding="utf-8")
    assert "pull_request_target" not in content, (
        "pull_request_target runs with write access to the base branch"
    )
    for scope in ("contents: read", "issues: read", "pull-requests: read"):
        assert scope in content, f"the workflow must keep `{scope}`"


def test_the_workflow_requires_the_outcome():
    """The CI job must ask the harder question, not just the staleness one.

    The checker's default mode is a pure head-binding check — a not-merge-ready
    verdict on the current head passes it. If the workflow ran that default, a
    verdict that explicitly blocks a merge would show a green check, which is
    exactly the false assurance this gate exists to prevent.
    """
    content = WORKFLOW.read_text(encoding="utf-8")
    assert "--require-outcome" in content, (
        "the CI job must pass --require-outcome so a green check means "
        "merge-ready, not merely current"
    )


def test_the_workflow_bounds_the_issue_comment_runs():
    """An issue_comment run is user-triggerable on a public repository."""
    content = WORKFLOW.read_text(encoding="utf-8")
    workflow = yaml.safe_load(content)
    assert "concurrency" in workflow, (
        "the workflow must bound the runs a commenter can trigger"
    )
    assert workflow["concurrency"]["cancel-in-progress"] is True
