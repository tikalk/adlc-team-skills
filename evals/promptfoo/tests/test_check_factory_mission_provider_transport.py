"""Unit test for check_factory_mission_provider_transport.py grader.

Verifies the grader produces correct pass/fail results for the
factory-mission provider-transport criterion (EVAL-014): the remote lane
delegates workspace setup to `adlc-cli ... --provider coder`, runs no
skill-side env sync, and halts without a script fallback.
"""
import sys
from pathlib import Path

graders_dir = Path(__file__).parent.parent / "graders"
sys.path.insert(0, str(graders_dir))

from check_factory_mission_provider_transport import get_assert


# ---------------------------------------------------------------------------
# Pass cases
# ---------------------------------------------------------------------------

PASS_DELEGATES = """Provisioning the remote workspace via the transport:
`adlc-cli workspace setup --provider coder`. The CLI owns clone, skills, and
env setup — the lane runs no env-sync script of its own."""


def test_pass_delegates_to_transport():
    """Delegating setup to the provider transport passes."""
    result = get_assert(PASS_DELEGATES)
    assert result["pass"] is True
    assert result["score"] == 1.0


PASS_HALTS_ON_FAILURE = """`adlc-cli workspace setup --provider coder` exited non-zero
(not implemented: live coder transport). Halting the run and handing back to
the developer — no script fallback, the transport is the only owner of setup."""


def test_pass_halts_on_transport_failure():
    """Halting on a transport failure without a fallback passes."""
    result = get_assert(PASS_HALTS_ON_FAILURE)
    assert result["pass"] is True


PASS_WORKFLOW_RUN = """Running the step remotely:
`adlc-cli workflow run factory --input run_id=r-7 --provider coder`."""


def test_pass_workflow_run_through_transport():
    """Routing the step through the transport passes."""
    result = get_assert(PASS_WORKFLOW_RUN)
    assert result["pass"] is True


# ---------------------------------------------------------------------------
# Fail cases
# ---------------------------------------------------------------------------

FAIL_USES_SCRIPT = """Setting up the workspace by running
skills/factory/factory-mission/scripts/bash/remote-coder-env-sync.sh with the
workspace name and brief path."""


def test_fail_uses_env_sync_script():
    """Using the deleted env-sync script fails."""
    result = get_assert(FAIL_USES_SCRIPT)
    assert result["pass"] is False
    assert "env-sync script" in result["reason"]


FAIL_MANUAL_SYNC = """Syncing the environment over SSH:
coder ssh my-workspace -- "git clone git@github.com:org/repo.git /repo"
then installing the skills with adlc-cli skills add tikalk/adlc-team-skills."""


def test_fail_manual_sync_over_ssh():
    """Hand-rolling the env sync over `coder ssh` fails."""
    result = get_assert(FAIL_MANUAL_SYNC)
    assert result["pass"] is False
    assert "by hand" in result["reason"]


FAIL_FALLBACK = """The transport failed, so I will fall back to the
env-sync script and sync the environment manually."""


def test_fail_falls_back_to_script():
    """Falling back to a script on transport failure fails."""
    result = get_assert(FAIL_FALLBACK)
    assert result["pass"] is False
    assert "falls back to a script" in result["reason"]


FAIL_NO_TRANSPORT = """Provisioning the workspace on Coder and waiting for it to
reach Running before printing the attach instructions."""


def test_fail_no_transport_call():
    """A run that never calls the transport fails."""
    result = get_assert(FAIL_NO_TRANSPORT)
    assert result["pass"] is False
    assert "no adlc-cli provider transport call" in result["reason"]
