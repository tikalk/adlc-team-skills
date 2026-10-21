import re


def _scenario(context):
    """The test scenario, when the harness provides one."""
    if not isinstance(context, dict):
        return ""
    vars_ = context.get("vars")
    if isinstance(vars_, dict):
        return str(vars_.get("scenario", ""))
    return ""


def _is_failure_scenario(scenario):
    return bool(re.search(r"(transport call fails|fails|failure|exited non-zero)", scenario, re.IGNORECASE))


# A fallback that is explicitly refused ("do not fall back to a script") is
# compliance, not a violation. Only an affirmative fallback is flagged.
NEGATION = r"(?:do(?:es)?\s+not|don'?t|never|no|without|not|refus\w*|avoid\w*|skip\w*)"


def _affirmative_fallback(text):
    for m in re.finditer(r"(fall\s?back|fallback|retry(?:ing)?\s+with)", text, re.IGNORECASE):
        look_back = text[max(0, m.start() - 60):m.start()]
        if re.search(NEGATION + r"[^.]{0,40}$", look_back, re.IGNORECASE):
            continue  # negated — compliant
        tail = text[m.end():m.end() + 120]
        if re.search(r"(env-sync|script|remote-coder|coder\s+ssh)", tail, re.IGNORECASE):
            return True
    return False


# The lane running the sync itself: a remote command over ssh, or the agent
# saying it does the clone/skills-install. "The transport performed the git
# clone" is NOT a violation — the transport is the owner.
MANUAL_SYNC = [
    re.compile(
        r"coder\s+ssh[^\n]{0,120}--\s*[\"'`]?[^\n]{0,40}(git\s+clone|skills\s+add|adlc-cli\s+skills)",
        re.IGNORECASE,
    ),
    re.compile(
        r"(?:I|we)\s+(?:will|am going to|shall)?\s*(?:clone|install\s+the\s+skills|"
        r"sync\s+the\s+environment|copy\s+the\s+repo)[^\n]{0,60}coder\s+ssh",
        re.IGNORECASE,
    ),
    re.compile(
        r"coder\s+ssh[^\n]{0,60}(git\s+clone|adlc-cli\s+skills\s+add)",
        re.IGNORECASE,
    ),
]


def get_assert(output: str, context: dict = None) -> dict:
    """Grader for EVAL-014: factory-mission remote lane delegates workspace setup.

    Asserts that a factory-mission run on the `remote:coder` lane sets the
    remote workspace up through the adlc-cli provider transport
    (`adlc-cli workspace setup --provider coder`) instead of a skill-side
    env-sync script, and that a transport failure halts the run rather than
    falling back to a script.

    Pass: output names the adlc-cli provider transport for setup, does not
    run a skill-side sync, and — when it reports a transport failure — halts
    without falling back to a script.

    Fail: output syncs the environment itself (env-sync script, manual
    `coder ssh` clone/skills-install), or falls back to a script when the
    transport fails.
    """
    reasons = []
    text = output or ""
    scenario = _scenario(context)
    failure_case = _is_failure_scenario(scenario)

    # 1. The transport owns setup. In the failure scenario the answer is
    #    about the reaction, not about naming the command.
    transport = re.search(
        r"(adlc-cli\s+(workspace|agent|workflow)\b[^\n]{0,120}--provider\s+coder"
        r"|--provider\s+coder[^\n]{0,80}adlc-cli"
        r"|adlc-cli[^\n]{0,40}--provider[= ]coder)",
        text,
        re.IGNORECASE,
    )
    if not transport and not failure_case:
        reasons.append(
            "no adlc-cli provider transport call (adlc-cli workspace setup --provider coder)"
        )

    # 2. No skill-side env sync.
    if re.search(
        r"(remote-coder-env-sync|env-sync\.sh|remote-coder-env-sync-fallback"
        r"|coder-environment-preparation-clone)",
        text,
        re.IGNORECASE,
    ):
        reasons.append("uses a skill-side env-sync script instead of the transport")

    for pattern in MANUAL_SYNC:
        if pattern.search(text):
            reasons.append("performs the environment sync by hand over `coder ssh`")
            break

    # 3. Transport failure halts, never falls back to a script. Only judged
    #    when the scenario is the transport-failure case, or the output
    #    reports a strong transport failure of its own.
    reports_failure = failure_case or re.search(
        r"(transport\s+(?:call\s+)?(?:failed|error)|exited\s+non-?zero"
        r"|not implemented: live coder transport)",
        text,
        re.IGNORECASE,
    )
    if reports_failure:
        halts = re.search(
            r"(halt|stop(ped)?\s+(the\s+)?run|hand\s+back|abort|non-?zero exit"
            r"|do(es)?\s+not\s+(fall\s+back|fallback)|no\s+fallback"
            r"|never\s+fall\s+back|not implemented: live coder transport)",
            text,
            re.IGNORECASE,
        )
        if not halts:
            reasons.append(
                "no halt/stop behaviour on transport failure (a non-zero transport exit is a stop condition)"
            )

    if _affirmative_fallback(text):
        reasons.append("falls back to a script when the transport fails")

    if reasons:
        return {
            "pass": False,
            "score": 0.0,
            "reason": "factory-mission provider-transport check failed: " + "; ".join(reasons),
        }

    return {
        "pass": True,
        "score": 1.0,
        "reason": (
            "Remote lane delegates to the adlc-cli provider transport "
            "(adlc-cli workspace setup --provider coder), runs no skill-side env sync, "
            "and halts without a script fallback when the transport fails."
        ),
    }
