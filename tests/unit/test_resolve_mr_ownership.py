"""MR/PR milestone + assignee propagation resolver (the MR-ownership decision).

The resolver is the deterministic half of the MR-ownership decision: it answers what the
connector should set, what it should skip, and what it should block on. All
five locked rulings are pinned here — all providers, silent skip, fallback
chain, preserve-only, block-on-error — plus the per-provider mapping.
"""

import json
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).parent.parent.parent
SCRIPTS = ROOT / "skills/factory/factory-mission/scripts"
RESOLVER_BASH = SCRIPTS / "bash/resolve-mr-ownership.sh"
RESOLVER_PWSH = SCRIPTS / "powershell/resolve-mr-ownership.ps1"
HAVE_BASH = shutil.which("bash") is not None
HAVE_PWSH = shutil.which("pwsh") is not None


def _run(script, payload_str=None, file_arg=None):
    if script.suffix == ".sh":
        cmd = ["bash", str(script)]
    else:
        cmd = ["pwsh", "-NoProfile", "-File", str(script)]
    if file_arg is not None:
        cmd.append(str(file_arg))
    return subprocess.run(
        cmd,
        input=payload_str,
        capture_output=True,
        text=True,
        timeout=30,
    )


def resolve(**payload):
    """Run the resolver over a payload; return the parsed result.

    Runs the bash twin, and the PowerShell twin too when pwsh is installed —
    the twins must agree (CDR-022: one behavior, two platform scripts).
    """
    payload_str = json.dumps(payload)
    proc = _run(RESOLVER_BASH, payload_str=payload_str)
    assert proc.returncode == 0, f"resolver failed: {proc.stderr}"
    out = json.loads(proc.stdout)
    if HAVE_PWSH:
        proc2 = _run(RESOLVER_PWSH, payload_str=payload_str)
        assert proc2.returncode == 0, f"pwsh resolver failed: {proc2.stderr}"
        out2 = json.loads(proc2.stdout)
        assert out == out2, f"twins disagree:\nbash : {out}\npwsh : {out2}"
    return out


def test_resolver_exists():
    assert RESOLVER_BASH.exists(), f"resolver missing at {RESOLVER_BASH}"
    assert RESOLVER_PWSH.exists(), f"resolver twin missing at {RESOLVER_PWSH}"


# ── per-provider milestone mapping (the MR-ownership decision "all providers") ───────────────

def test_gitlab_maps_milestone_id_verbatim():
    out = resolve(
        provider="gitlab",
        issue={"milestone_id": 7, "assignees": []},
        mr={"milestone_id": None, "assignees": []},
        initiator="alice",
        runner="bot",
    )
    assert out["action"] == "set"
    assert out["milestone"] == 7
    assert out["milestone_field"] == "milestone_id"


def test_github_maps_milestone_number():
    out = resolve(
        provider="github",
        issue={"milestone": {"number": 3}, "assignees": []},
        mr={"milestone": None, "assignees": []},
        initiator="alice",
        runner="bot",
    )
    assert out["milestone"] == 3
    assert out["milestone_field"] == "milestone"


@pytest.mark.parametrize("provider", ["jira", "linear"])
def test_provider_without_milestone_is_a_noop_not_an_error(provider):
    out = resolve(
        provider=provider,
        issue={"milestone_id": 7, "assignees": ["alice"]},
        mr={"milestone_id": None, "assignees": []},
        initiator=None,
        runner="bot",
    )
    assert out["milestone"] is None, f"{provider} has no milestone concept"
    assert out["milestone_field"] is None
    assert out["action"] == "set", "the assignee still propagates"
    assert "no-op" in out["reason"]


def test_unknown_provider_blocks():
    out = resolve(provider="bitbucket", issue={}, mr={})
    assert out["action"] == "block"
    assert "unknown provider" in out["reason"]


# ── silent skip when the Issue has no milestone (ruling 2) ──────────────────

def test_issue_without_milestone_is_skipped_silently():
    out = resolve(
        provider="gitlab",
        issue={"milestone_id": None, "assignees": []},
        mr={"milestone_id": None, "assignees": []},
        initiator="alice",
        runner="bot",
    )
    assert out["milestone"] is None
    assert "no milestone" in out["reason"]
    assert out["action"] == "set", "the assignee still propagates — only the milestone is skipped"


def test_issue_without_milestone_and_without_assignee_is_a_clean_skip():
    out = resolve(
        provider="gitlab",
        issue={"milestone_id": None, "assignees": []},
        mr={"milestone_id": None, "assignees": []},
        initiator=None,
        runner=None,
    )
    assert out["action"] == "skip"
    assert out["milestone"] is None and out["assignee"] is None


# ── preserve-only (ruling 4) ───────────────────────────────────────────────

def test_existing_mr_milestone_is_preserved():
    out = resolve(
        provider="gitlab",
        issue={"milestone_id": 7, "assignees": []},
        mr={"milestone_id": 99, "assignees": []},
        initiator="alice",
        runner="bot",
    )
    assert out["milestone"] is None, "an MR milestone set by a human must not be overwritten"
    assert "preserved" in out["reason"]


def test_existing_mr_assignee_is_preserved():
    out = resolve(
        provider="github",
        issue={"milestone": None, "assignees": ["carol"]},
        mr={"milestone": None, "assignees": ["dave"]},
        initiator="alice",
        runner="bot",
    )
    assert out["assignee"] is None, "an MR assignee set by a human must not be overwritten"
    assert "preserved" in out["reason"]


# ── the assignee fallback chain (ruling 3) ─────────────────────────────────

def test_initiator_wins_the_chain():
    out = resolve(
        provider="gitlab",
        issue={"milestone_id": None, "assignees": ["carol"]},
        mr={"assignees": []},
        initiator="alice",
        runner="bot",
    )
    assert out["assignee"] == "alice"
    assert out["assignee_field"] == "assignee_ids"


def test_issue_assignee_is_the_second_link():
    out = resolve(
        provider="gitlab",
        issue={"milestone_id": None, "assignees": ["carol", "dan"]},
        mr={"assignees": []},
        initiator=None,
        runner="bot",
    )
    assert out["assignee"] == "carol", "the first Issue assignee is the second link"


def test_runner_identity_is_the_last_link():
    out = resolve(
        provider="gitlab",
        issue={"milestone_id": None, "assignees": []},
        mr={"assignees": []},
        initiator=None,
        runner="ci-bot",
    )
    assert out["assignee"] == "ci-bot"


def test_no_candidate_at_all_leaves_the_assignee_unset():
    out = resolve(
        provider="gitlab",
        issue={"milestone_id": None, "assignees": []},
        mr={"assignees": []},
        initiator=None,
        runner=None,
    )
    assert out["assignee"] is None
    assert "no assignee candidate" in out["reason"]


# ── block on a missing scope (ruling 5) ────────────────────────────────────

def test_denied_scope_blocks_with_an_actionable_error():
    out = resolve(
        provider="gitlab",
        issue={"milestone_id": 7, "assignees": ["alice"]},
        mr={},
        initiator="alice",
        runner="bot",
        denied_scope="api",
    )
    assert out["action"] == "block"
    assert "api" in out["reason"], "the error must name the missing scope"
    assert out["milestone"] is None and out["assignee"] is None


def test_denied_scope_blocks_before_any_propagation():
    """The pre-flight check runs first — nothing is propagated under a block."""
    out = resolve(
        provider="github",
        issue={"milestone": {"number": 3}, "assignees": ["alice"]},
        mr={},
        initiator="alice",
        runner="bot",
        denied_scope="project",
    )
    assert out["action"] == "block"
    assert out["milestone"] is None
    assert out["assignee"] is None


# ── the resolver is deterministic ───────────────────────────────────────────

def test_resolution_is_deterministic():
    payload = dict(
        provider="gitlab",
        issue={"milestone_id": 7, "assignees": ["carol"]},
        mr={},
        initiator="alice",
        runner="bot",
    )
    assert resolve(**payload) == resolve(**payload)


def test_resolver_accepts_a_payload_file(tmp_path):
    payload_file = tmp_path / "payload.json"
    payload_file.write_text(
        json.dumps(
            {
                "provider": "gitlab",
                "issue": {"milestone_id": 7, "assignees": []},
                "mr": {},
                "initiator": "alice",
                "runner": "bot",
            }
        ),
        encoding="utf-8",
    )
    proc = _run(RESOLVER_BASH, file_arg=payload_file)
    assert proc.returncode == 0, proc.stderr
    assert json.loads(proc.stdout)["milestone"] == 7
    if HAVE_PWSH:
        proc2 = _run(RESOLVER_PWSH, file_arg=payload_file)
        assert proc2.returncode == 0, proc2.stderr
        assert json.loads(proc2.stdout)["milestone"] == 7
