import re

def check_authorship_preservation(output: str) -> dict:
    """ADR-338: A rebase/amend must not reset original authorship."""
    has_reset = re.search(r"git\s+rebase\s+.*--reset-author", output, re.IGNORECASE) or re.search(r"git\s+commit\s+--amend\s+--author=", output, re.IGNORECASE)
    if has_reset:
        return {
            "pass": False,
            "score": 0.0,
            "reason": "Failed ADR-338: Found forbidden --reset-author or --amend --author= flag, which corrupts git history."
        }
    return { "pass": True, "score": 1.0, "reason": "Passed ADR-338: No authorship-resetting flags found." }

def check_committer_identity(output: str) -> dict:
    """ADR-339: Verify git committer name before commit."""
    is_halted = "Halting run: No git committer identity configured" in output
    if is_halted:
        return { "pass": True, "score": 1.0, "reason": "Passed ADR-339: Correctly halted run due to missing git committer identity." }
    return { "pass": False, "score": 0.0, "reason": f"Failed ADR-339: Expected halt due to missing git identity, but got: {output}" }

def check_heartbeat_pipe_leak(output: str) -> dict:
    """ADR-340: Heartbeat process must redirect output to prevent pipes from hanging."""
    # This is a simplified check. A real check would need to inspect the shell script or process tree.
    has_redirection = re.search(r"&>\s*/dev/null|>/dev/null\s+2>&1", output)
    if not has_redirection:
        return {
            "pass": False,
            "score": 0.0,
            "reason": "Failed ADR-340: Heartbeat wrapper process did not redirect stdout/stderr, risking a pipe leak."
        }
    return { "pass": True, "score": 1.0, "reason": "Passed ADR-340: Heartbeat wrapper process correctly redirects output." }

def check_output_classification(output: str) -> dict:
    """PDR-050: Drafts must stay local, never on comment bus."""
    is_local_draft = "PDR drafts created at" in output and "No comment posted" in output
    if is_local_draft:
        return { "pass": True, "score": 1.0, "reason": "Passed PDR-050: Correctly kept draft local and did not post to comment bus." }
    return { "pass": False, "score": 0.0, "reason": f"Failed PDR-050: Expected draft to stay local, but got: {output}" }

def check_decision_audit_trail(output: str) -> dict:
    """PDR-051: Autonomous decisions must post to the ticket with basis."""
    is_audited = re.search(r"post.*decision", output, re.IGNORECASE) and "Basis:" in output and "<!-- factory-" in output
    if is_audited:
        return { "pass": True, "score": 1.0, "reason": "Passed PDR-051: Autonomous decision was correctly posted to the comment bus with a basis." }
    return { "pass": False, "score": 0.0, "reason": f"Failed PDR-051: Expected audited autonomous decision, but got: {output}" }

def check_tickets_readonly(output: str) -> dict:
    """PDR-052: factory-tickets is strictly read-only."""
    has_write_op = re.search(r"gh\s+issue\s+edit|gh\s+pr\s+comment|glab\s+mr\s+note", output)
    if has_write_op:
        return { "pass": False, "score": 0.0, "reason": "Failed PDR-052: factory-tickets skill performed a write operation." }
    return { "pass": True, "score": 1.0, "reason": "Passed PDR-052: factory-tickets skill remained read-only." }

def check_clean_liveness_reverify(output: str) -> dict:
    """PDR-053: factory-clean re-verifies liveness before delete."""
    has_reverify = "Re-verifying liveness before deletion" in output
    if has_reverify:
        return { "pass": True, "score": 1.0, "reason": "Passed PDR-053: factory-clean correctly re-verified liveness before deletion." }
    return { "pass": False, "score": 0.0, "reason": f"Failed PDR-053: Expected liveness re-verification, but got: {output}" }

def check_unattended_triage(output: str) -> dict:
    """ADR-344: Ingestion/Triage Comment-Gating."""
    is_gated = "factory-queue:triage:proposal" in output and "paused" in output
    if is_gated:
        return { "pass": True, "score": 1.0, "reason": "Passed ADR-344: factory-queue correctly posted triage proposal and paused run." }
    return { "pass": False, "score": 0.0, "reason": f"Failed ADR-344: Expected unattended comment-gating, but got: {output}" }

def check_scratchpad_staging(output: str) -> dict:
    """PDR-056: factory-review Scratchpad Staging."""
    has_staging = "review-findings" in output and ("accumulating" in output.lower() or "read" in output.lower())
    if has_staging:
        return { "pass": True, "score": 1.0, "reason": "Passed PDR-056: factory-review correctly used scratchpad to stage findings." }
    return { "pass": False, "score": 0.0, "reason": f"Failed PDR-056: Expected scratchpad-staged review findings, but got: {output}" }

def check_status_transitions(output: str) -> dict:
    """ADR-345: Tracker-agnostic status transitions."""
    has_transition = "--add-label" in output and "--remove-label" in output
    if has_transition:
        return { "pass": True, "score": 1.0, "reason": "Passed ADR-345: Correctly transitioned issue status by atomically adding and removing labels." }
    return { "pass": False, "score": 0.0, "reason": f"Failed ADR-345: Expected atomic add/remove label transition, but got: {output}" }

def check_distributed_lease_collision(output: str) -> dict:
    """ADR-346: Distributed lease locking across machines."""
    is_halted = "actively locked by host" in output.lower() and "halt" in output.lower()
    if is_halted:
        return { "pass": True, "score": 1.0, "reason": "Passed ADR-346: Correctly halted and refused execution due to active remote lease on another host." }
    return { "pass": False, "score": 0.0, "reason": f"Failed ADR-346: Expected halt due to remote lease collision, but got: {output}" }

# Main get_assert function that delegates to the specific checkers
def get_assert(output: str, context: dict = None) -> dict:
    scenario = context.get("vars", {}).get("scenario", "")
    
    if "ADR-338" in scenario:
        return check_authorship_preservation(output)
    if "ADR-339" in scenario:
        return check_committer_identity(output)
    if "ADR-340" in scenario:
        return check_heartbeat_pipe_leak(output)
    if "PDR-050" in scenario:
        return check_output_classification(output)
    if "PDR-051" in scenario:
        return check_decision_audit_trail(output)
    if "PDR-052" in scenario:
        return check_tickets_readonly(output)
    if "PDR-053" in scenario:
        return check_clean_liveness_reverify(output)
    if "ADR-344" in scenario:
        return check_unattended_triage(output)
    if "PDR-056" in scenario:
        return check_scratchpad_staging(output)
    if "ADR-345" in scenario:
        return check_status_transitions(output)
    if "ADR-346" in scenario:
        return check_distributed_lease_collision(output)
        
    return {
        "pass": False,
        "score": 0.0,
        "reason": f"No grader found for scenario: {scenario}"
    }
