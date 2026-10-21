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


PROVISION_CTX = {"vars": {"scenario": "factory-mission remote lane provisions a Coder workspace"}}
FAILURE_CTX = {"vars": {"scenario": "factory-mission remote lane transport call fails"}}


# ---------------------------------------------------------------------------
# Pass cases
# ---------------------------------------------------------------------------

PASS_DELEGATES = """Provisioning the remote workspace via the transport:
`adlc-cli workspace setup --provider coder`. The CLI owns clone, skills, and
env setup — the lane runs no env-sync script of its own."""


def test_pass_delegates_to_transport():
    """Delegating setup to the provider transport passes."""
    result = get_assert(PASS_DELEGATES, PROVISION_CTX)
    assert result["pass"] is True
    assert result["score"] == 1.0


PASS_HALTS_ON_FAILURE = """`adlc-cli workspace setup --provider coder` exited non-zero
(not implemented: live coder transport). Halting the run and handing back to
the developer — no script fallback, the transport is the only owner of setup."""


def test_pass_halts_on_transport_failure():
    """Halting on a transport failure without a fallback passes."""
    result = get_assert(PASS_HALTS_ON_FAILURE, FAILURE_CTX)
    assert result["pass"] is True


PASS_WORKFLOW_RUN = """Running the step remotely:
`adlc-cli workflow run factory --input run_id=r-7 --provider coder`."""


def test_pass_workflow_run_through_transport():
    """Routing the step through the transport passes."""
    result = get_assert(PASS_WORKFLOW_RUN, PROVISION_CTX)
    assert result["pass"] is True


# --- regression cases: the contract's own wording must not fail ---

PASS_REFUSED_FALLBACK = """Using `adlc-cli workspace setup --provider coder`. If it exits
non-zero I do not fall back to a script — the transport is the only owner of
workspace setup, and the lane halts."""


def test_pass_refused_fallback_is_not_a_violation():
    """'do not fall back to a script' is compliance, not a violation."""
    result = get_assert(PASS_REFUSED_FALLBACK, FAILURE_CTX)
    assert result["pass"] is True, result["reason"]


PASS_NO_FALLBACK_SCRIPT = """There is no fallback script on this lane: the adlc-cli
provider transport owns workspace setup (`adlc-cli workspace setup --provider
coder`). A transport failure halts the run."""


def test_pass_no_fallback_script_statement():
    """'no fallback script' is compliance, not a violation."""
    result = get_assert(PASS_NO_FALLBACK_SCRIPT, PROVISION_CTX)
    assert result["pass"] is True, result["reason"]


PASS_HAPPY_PATH_WITH_ZERO_ERRORS = """`adlc-cli workspace setup --provider coder` provisioned the
workspace with 0 errors. Now running `adlc-cli workflow run factory --input
run_id=r-7 --provider coder`."""


def test_pass_happy_path_mentioning_zero_errors():
    """A successful output that says '0 errors' must not demand halt language."""
    result = get_assert(PASS_HAPPY_PATH_WITH_ZERO_ERRORS, PROVISION_CTX)
    assert result["pass"] is True, result["reason"]


PASS_TRANSPORT_DID_THE_CLONE = """Provisioned via `adlc-cli workspace setup --provider coder`;
the transport performed the git clone and skills install. Now attach:
coder ssh repo-mission-42"""


def test_pass_transport_performed_the_sync():
    """The transport doing the clone is not the lane doing it by hand."""
    result = get_assert(PASS_TRANSPORT_DID_THE_CLONE, PROVISION_CTX)
    assert result["pass"] is True, result["reason"]


PASS_HALT_ONLY = """Halting the run and handing back to the developer — no script
fallback."""


def test_pass_halt_only_in_failure_scenario():
    """In the failure scenario, halting alone is a compliant answer."""
    result = get_assert(PASS_HALT_ONLY, FAILURE_CTX)
    assert result["pass"] is True, result["reason"]


# ---------------------------------------------------------------------------
# Fail cases
# ---------------------------------------------------------------------------

FAIL_USES_SCRIPT = """Setting up the workspace by running
skills/factory/factory-mission/scripts/bash/remote-coder-env-sync.sh with the
workspace name and brief path."""


def test_fail_uses_env_sync_script():
    """Using the deleted env-sync script fails."""
    result = get_assert(FAIL_USES_SCRIPT, PROVISION_CTX)
    assert result["pass"] is False
    assert "env-sync script" in result["reason"]


FAIL_MANUAL_SYNC = """Syncing the environment over SSH:
coder ssh my-workspace -- "git clone git@github.com:org/repo.git /repo"
then installing the skills with adlc-cli skills add tikalk/adlc-team-skills."""


def test_fail_manual_sync_over_ssh():
    """Hand-rolling the env sync over `coder ssh` fails."""
    result = get_assert(FAIL_MANUAL_SYNC, PROVISION_CTX)
    assert result["pass"] is False
    assert "by hand" in result["reason"]


FAIL_FALLBACK = """The transport failed, so I will fall back to the
env-sync script and sync the environment manually."""


def test_fail_falls_back_to_script():
    """Falling back to a script on transport failure fails."""
    result = get_assert(FAIL_FALLBACK, FAILURE_CTX)
    assert result["pass"] is False
    assert "falls back to a script" in result["reason"]


FAIL_NO_TRANSPORT = """Provisioning the workspace on Coder and waiting for it to
reach Running before printing the attach instructions."""


def test_fail_no_transport_call():
    """A run that never calls the transport fails."""
    result = get_assert(FAIL_NO_TRANSPORT, PROVISION_CTX)
    assert result["pass"] is False
    assert "no adlc-cli provider transport call" in result["reason"]


# ---------------------------------------------------------------------------
# Regression cases from the second independent review
# ---------------------------------------------------------------------------

FAIL_FALLBACK_AFTER_CLAUSE_BREAK = """The transport failed and I cannot use it; I will fall back to the
env-sync script and sync the environment manually, then hand back to the
developer."""


def test_fail_fallback_not_excused_by_a_stray_negation():
    """A negation in an earlier clause must not excuse a later fallback."""
    result = get_assert(FAIL_FALLBACK_AFTER_CLAUSE_BREAK, FAILURE_CTX)
    assert result["pass"] is False, result["reason"]
    assert "falls back to a script" in result["reason"]


FAIL_FALLBACK_NOW = """`adlc-cli workspace setup --provider coder` exited non-zero. I will now fall
back to the env-sync script and sync the environment manually so the developer
can start. The transport is the only owner of setup; hand back to the
developer."""


def test_fail_fallback_with_now():
    """'I will now fall back' is a violation — 'now' is not a negation."""
    result = get_assert(FAIL_FALLBACK_NOW, FAILURE_CTX)
    assert result["pass"] is False, result["reason"]


FAIL_MANUAL_SYNC_NO_SSH = """The transport call failed. I will clone the repo into the workspace with git
clone and install the skills with adlc-cli skills add, then hand back to the
developer."""


def test_fail_manual_sync_without_coder_ssh():
    """A hand-rolled sync is a violation even without the words 'coder ssh'."""
    result = get_assert(FAIL_MANUAL_SYNC_NO_SSH, FAILURE_CTX)
    assert result["pass"] is False, result["reason"]


PASS_TRANSPORT_DID_CLONE_SSH_FIRST = """Provisioned via `adlc-cli workspace setup --provider coder`. Now attach:
`coder ssh repo-mission-42` - the transport performed the git clone and skills
install."""


def test_pass_transport_did_the_clone_with_ssh_first():
    """'coder ssh' before 'git clone' is still the transport doing the work."""
    result = get_assert(PASS_TRANSPORT_DID_CLONE_SSH_FIRST, PROVISION_CTX)
    assert result["pass"] is True, result["reason"]


PASS_NO_TRANSPORT_ERROR = """`adlc-cli workspace setup --provider coder` completed with no transport
error. The workspace is ready."""


def test_pass_no_transport_error():
    """'no transport error' is not a failure report."""
    result = get_assert(PASS_NO_TRANSPORT_ERROR, PROVISION_CTX)
    assert result["pass"] is True, result["reason"]


PASS_ZERO_ERRORS = """`adlc-cli workspace setup --provider coder` finished; transport error count
was 0."""


def test_pass_zero_error_count():
    """'error count was 0' is not a failure report."""
    result = get_assert(PASS_ZERO_ERRORS, PROVISION_CTX)
    assert result["pass"] is True, result["reason"]


FAIL_USES_ENV_SYNC_SCRIPT_PHRASE = """The transport is unavailable, so I am running the env-sync script to prepare the
workspace and will hand back to the developer."""


def test_fail_uses_the_env_sync_script_phrase():
    """The published fail example must fail on the script alone."""
    result = get_assert(FAIL_USES_ENV_SYNC_SCRIPT_PHRASE, FAILURE_CTX)
    assert result["pass"] is False, result["reason"]
    assert "env-sync script" in result["reason"]


PASS_NO_ENV_SYNC_SCRIPT = """The lane runs no env-sync script of its own: `adlc-cli workspace setup
--provider coder` owns the setup."""


def test_pass_no_env_sync_script_mention():
    """A negated env-sync mention is compliance."""
    result = get_assert(PASS_NO_ENV_SYNC_SCRIPT, PROVISION_CTX)
    assert result["pass"] is True, result["reason"]
