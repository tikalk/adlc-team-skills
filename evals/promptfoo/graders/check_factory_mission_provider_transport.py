import re


def get_assert(output: str, context: dict = None) -> dict:
    """Grader for EVAL-014: factory-mission remote lane delegates workspace setup.

    Asserts that a factory-mission run on the `remote:coder` lane sets the
    remote workspace up through the adlc-cli provider transport
    (`adlc-cli workspace setup --provider coder`) instead of a skill-side
    env-sync script, and that a transport failure halts the run rather than
    falling back to a script.

    Pass: output names the adlc-cli provider transport for setup, does not
    run a skill-side sync script, and halts (without a script fallback) when
    the transport reports failure.

    Fail: output syncs the environment itself (env-sync script, manual
    `coder ssh` clone/skills-install steps), or falls back to a script when
    the transport fails.
    """
    reasons = []
    text = output or ""

    # 1. The transport owns setup.
    transport = re.search(
        r"(adlc-cli\s+(workspace|agent|workflow)\b[^\n]{0,120}--provider\s+coder"
        r"|--provider\s+coder[^\n]{0,80}adlc-cli"
        r"|adlc-cli[^\n]{0,40}--provider[= ]coder)",
        text,
        re.IGNORECASE,
    )
    if not transport:
        reasons.append(
            "no adlc-cli provider transport call (adlc-cli workspace setup --provider coder)"
        )

    # 2. No skill-side env sync.
    script_fallback = re.search(
        r"(remote-coder-env-sync|env-sync\.sh|remote-coder-env-sync-fallback"
        r"|coder-environment-preparation-clone)",
        text,
        re.IGNORECASE,
    )
    if script_fallback:
        reasons.append("uses a skill-side env-sync script instead of the transport")

    manual_sync = re.search(
        r"(coder\s+ssh[^\n]{0,120}(clone|git\s+clone|skills\s+add)"
        r"|(git\s+clone|skills\s+add|cat\s+>\s*\S*brief)[^\n]{0,60}coder\s+ssh)",
        text,
        re.IGNORECASE,
    )
    if manual_sync:
        reasons.append("performs the environment sync by hand over `coder ssh`")

    # 3. Transport failure halts, never falls back to a script.
    # Only judged when the output actually reports a transport failure.
    reports_failure = re.search(
        r"(fail(ed|s|ure)?|non-?zero|exit(ed)?\s+(code\s+)?[1-9]|"
        r"not implemented: live coder transport|unavailable|error)",
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

    fallback_on_failure = re.search(
        r"(fall\s?back|fallback|retry(?:ing)? with)[\s\S]{0,120}"
        r"(env-sync|script|remote-coder|coder\s+ssh)",
        text,
        re.IGNORECASE,
    )
    if fallback_on_failure:
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
