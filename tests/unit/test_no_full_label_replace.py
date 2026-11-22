"""No skill may teach a label write that replaces the whole label set (SF-FIX-04).

Evidence: in the archived runner logs agents hand-wrote calls such as
`curl --request PUT … --data "labels=Backlog,Fullstack,autonomous,validation"`.
On GitLab `labels=` in a PUT states the complete set, so every label not in
the list is deleted. GitLab's label history shows the damage:
adlc-workspace#101, 2026-11-16 11:44:19 — the one write that added
`validation` removed `InProgress`, `agent-can-execute`, `epic` and
`supervised`; agentic-container!55, 2026-10-31, lost `supervised`. The
dispatch label (`supervised` / `autonomous`) is what the close, resume and
triage triggers filter on, so an issue that loses it is no longer settled
when it closes and cannot be resumed.

The guidance never showed a full-list write for GitLab, but it never forbade
one either, its only raw form for label writes was the `glab issue update`
CLI (which agents in pods abandoned for curl), and for GitHub MCP it told the
agent to send "the full `labels` array". These tests pin the rule, the
add/remove examples, and a lint over every file under `skills/`.
"""
import re
from pathlib import Path

ROOT = Path(__file__).parent.parent.parent
SKILLS = ROOT / "skills"
FACTORY = SKILLS / "factory"
TRACKER = FACTORY / "factory-runbook/references/tracker-integration.md"

# A label parameter that states the whole set: `labels=` not part of
# `add_labels=` / `remove_labels=` (GitLab), and GitHub's replace-all call.
FULL_SET = [
    (re.compile(r"(?<![A-Za-z_])labels="), "`labels=` states the whole label set (use add_labels / remove_labels)"),
    (re.compile(r"full\s+`?labels`?\s+(array|list|set)", re.IGNORECASE), "a full labels array replaces the whole set"),
    (re.compile(r"\bPUT\b[^\n]*/issues/[^\s\"'`]*/labels\b"), "PUT …/issues/<n>/labels replaces the whole set on GitHub"),
]
# A line that forbids the form may name it.
FORBIDS = re.compile(r"\b(never|do not|don't|must not)\b", re.IGNORECASE)
TEXT_SUFFIXES = {".md", ".sh", ".ps1", ".yml", ".yaml", ".json", ".js", ".txt"}


def offenders(root):
    found = []
    for path in sorted(root.rglob("*")):
        if not path.is_file() or path.suffix not in TEXT_SUFFIXES:
            continue
        for n, line in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
            if FORBIDS.search(line):
                continue
            for pattern, why in FULL_SET:
                if pattern.search(line):
                    found.append(f"{path.relative_to(ROOT)}:{n}: {why}")
    return found


def test_no_skill_file_teaches_a_full_label_set_write():
    found = offenders(SKILLS)
    assert not found, "label writes that replace the whole set:\n" + "\n".join(found)


def test_the_lint_catches_the_forms_seen_in_the_logs(tmp_path):
    bad = tmp_path / "bad.md"
    bad.write_text(
        'curl --request PUT --data "labels=Backlog,Fullstack,autonomous,validation" "$API/issues/1515"\n'
        '-d "labels=agent-authored"\n'
        "GitHub MCP: `update_issue` with the full `labels` array: current labels minus the others.\n"
        'gh api -X PUT "repos/o/r/issues/7/labels" --input -\n',
        encoding="utf-8")
    good = tmp_path / "good.md"
    good.write_text(
        'glab api -X PUT "projects/p/issues/1" -f add_labels=validation -f remove_labels=executing\n'
        "Never send `labels=<list>`: it deletes every label you did not list.\n"
        'gh api -X POST "repos/o/r/issues/7/labels" --input -\n',
        encoding="utf-8")
    global ROOT
    saved, ROOT = ROOT, tmp_path
    try:
        assert len(offenders(tmp_path)) == 4
        bad.unlink()
        assert offenders(tmp_path) == []
    finally:
        ROOT = saved


def test_the_prohibition_exemption_is_per_line_and_does_not_spill(tmp_path):
    """The lint skips a line that forbids the form. That is a per-line
    heuristic, so a line that mixes a prohibition word with a forbidden form
    is skipped too — a known limit, pinned here so it is a choice and not an
    accident. What must hold: the exemption never reaches another line, and a
    prohibition word inside a longer word does not exempt anything."""
    global ROOT
    saved, ROOT = ROOT, tmp_path
    try:
        mixed = tmp_path / "mixed.md"
        # One line: a prohibition about something else, and the forbidden form.
        mixed.write_text('Never edit the ticket body; then send -d "labels=validation,supervised".\n', encoding="utf-8")
        assert offenders(tmp_path) == [], "known limit: a mixed line is exempt as a whole"
        # The same instruction split over two lines: the second line is caught.
        mixed.write_text('Never edit the ticket body.\nThen send -d "labels=validation,supervised".\n', encoding="utf-8")
        assert [o.split(": ")[0] for o in offenders(tmp_path)] == ["mixed.md:2"]
        # A prohibition line between two bad lines exempts only itself.
        mixed.write_text('-d "labels=a"\nDo not send `labels=<list>`.\n-d "labels=b"\n', encoding="utf-8")
        assert [o.split(": ")[0] for o in offenders(tmp_path)] == ["mixed.md:1", "mixed.md:3"]
        # "nevertheless" / "donut" are not prohibitions.
        mixed.write_text('Nevertheless send -d "labels=a,b" here.\n', encoding="utf-8")
        assert len(offenders(tmp_path)) == 1
    finally:
        ROOT = saved


def between(text, start, end):
    i = text.index(start)
    return text[i:text.index(end, i)]


def test_tracker_integration_states_the_rule_with_its_reason():
    text = TRACKER.read_text(encoding="utf-8")
    safety = text[text.index("## Safety Constraints"):]
    rule = next(l for l in safety.splitlines() if "never replaced" in l)
    assert "`labels=" in rule and "add_labels" in rule and "remove_labels" in rule
    assert "deletes every label" in rule
    assert "`supervised`" in rule and "`autonomous`" in rule   # why it matters: the dispatch label
    assert "set-lifecycle.sh" in rule
    assert "adlc-workspace#101" in rule                          # the evidence


def test_operation_9_gives_the_raw_api_form_next_to_every_cli_form():
    op9 = between(TRACKER.read_text(encoding="utf-8"), "### Operation 9", "### Operation 10")
    # Set Lifecycle step 3: add + remove in one call, GitLab through `glab api`.
    assert '-f add_labels="<target>" -f remove_labels="<others>"' in op9
    assert "glab api --hostname <host> -X PUT" in op9
    # GitHub MCP no longer sends the whole array.
    assert "full `labels` array" not in op9 or all(
        FORBIDS.search(l) for l in op9.splitlines() if "full `labels` array" in l)
    # Stamping (agent-authored, the PR's validation label, dispatch/gating labels) is add-only.
    stamping = between(op9, "**Other label writes", "2. **State-Based")
    assert 'merge_requests/<iid>" -f add_labels=' in stamping
    assert 'issues/<iid>" -f add_labels=' in stamping
    assert "--add-label" in stamping
    assert "add_labels" in stamping and "remove_labels" in stamping


def test_a_one_of_a_set_label_replaces_the_others_of_its_set_in_the_same_call():
    """Add-only stamping left two dispatch labels after a re-triage: a spec
    correction sends the issue back to `intent` (set-lifecycle removes
    lifecycle labels only), and the next approval added the newly chosen
    dispatch label next to the old one. The close, resume and triage triggers
    filter on `supervised` / `autonomous`, so both matched."""
    op9 = between(TRACKER.read_text(encoding="utf-8"), "### Operation 9", "### Operation 10")
    stamping = between(op9, "**Other label writes", "2. **State-Based")
    rule = next(l for l in stamping.splitlines() if "one of a set" in l and "same call" in l)
    assert '-f add_labels="autonomous" -f remove_labels="supervised,interactive"' in rule
    assert '--add-label "autonomous" --remove-label "supervised" --remove-label "interactive"' in rule
    assert "`agent-can-execute`" in rule and "`human-required`" in rule
    assert "exactly one label of each set remains" in rule
    assert "Safety Constraint 11" in rule and not any(p.search(rule) for p, _ in FULL_SET)

    queue = (FACTORY / "factory-queue/SKILL.md").read_text(encoding="utf-8")
    line = next(l for l in queue.splitlines() if "Stamp automation-gating" in l)
    assert "each with an add-only call" not in line
    assert "--add-label autonomous --remove-label supervised --remove-label interactive" in line
    assert "add_labels=autonomous" in line and "remove_labels=supervised,interactive" in line
    assert "`agent-can-execute` in, `human-required` out" in line
    assert "Other label writes" in line and "one of each set remains" in line


def test_skills_that_stamp_a_label_point_to_the_add_only_form():
    for rel, anchor in [
        ("factory-mission/SKILL.md", "Stamp `agent-authored` on opened PRs"),
        ("factory-queue/SKILL.md", "Stamp automation-gating"),
        ("factory-runbook/references/tracker-integration.md", "When opening PRs, stamp `agent-authored`"),
    ]:
        text = (FACTORY / rel).read_text(encoding="utf-8")
        line = next(l for l in text.splitlines() if anchor in l)
        assert "Other label writes" in line, f"{rel}: the stamping line must name the add-only form"
    review = (FACTORY / "factory-review/SKILL.md").read_text(encoding="utf-8")
    s7 = between(review, "7. **No ticket body edits**", "8. **Invocation")
    assert "add_labels=validation" in s7 and "set-lifecycle.sh" in s7
    assert "never" in s7.lower() and "`labels=" in s7


def test_lifecycle_moves_go_through_the_set_lifecycle_step():
    """review-loop.md told the agent to "stamp `lifecycle=intent` label" by hand."""
    loop = (FACTORY / "factory-review/references/review-loop.md").read_text(encoding="utf-8")
    routing = loop[loop.index("## SPEC_CORRECTION_NEEDED Routing"):]
    assert "stamp `lifecycle=intent` label" not in loop
    assert "set-lifecycle.sh" in routing and "--to intent" in routing
