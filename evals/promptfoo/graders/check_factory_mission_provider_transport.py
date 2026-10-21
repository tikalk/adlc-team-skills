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
# The negation must be a WORD and must bind to the fallback phrase — an
# unanchored "no"/"not" would let "I cannot use it; I will fall back" pass.
NEGATION = r"(?:do(?:es)?\s+not|don'?t|doesn'?t|never|no|without|not|refus\w*|avoid\w*|skip\w*)"
NEGATED_FALLBACK = re.compile(
    r"\b" + NEGATION + r"\b[^.]{0,30}?\b(fall\s?back|fallback|retry(?:ing)?\s+with)\b",
    re.IGNORECASE,
)


def _affirmative_fallback(text):
    for m in re.finditer(r"\b(fall\s?back|fallback|retry(?:ing)?\s+with)\b", text, re.IGNORECASE):
        # A negation anywhere in the SAME clause before the phrase binds to it.
        look_back = _clause_before(text, m.start())
        if re.search(r"\b" + NEGATION + r"\b", look_back, re.IGNORECASE):
            continue  # negated in this clause — compliant
        tail = text[m.end():m.end() + 120]
        if re.search(r"(env-sync|script|remote-coder|coder\s+ssh)", tail, re.IGNORECASE):
            return True
    return False


# The lane running the sync itself. The actor matters: "the transport
# performed the git clone" is NOT a violation, "I will clone the repo" is.
MANUAL_SYNC = [
    # a remote command form: coder ssh <ws> -- "git clone ..." / "skills add"
    re.compile(
        r"coder\s+ssh[^\n]{0,120}--\s*[\"'`]?[^\n]{0,40}(git\s+clone|skills\s+add|adlc-cli\s+skills)",
        re.IGNORECASE,
    ),
    # the speaker doing it: I/we + verb (+ optional "coder ssh" later)
    re.compile(
        r"\b(?:I|we)\b[^.]{0,40}\b(clone|cloning|install(?:ing)?\s+the\s+skills|"
        r"install\s+the\s+skills|sync(?:ing)?\s+the\s+environment|copy(?:ing)?\s+the\s+repo|"
        r"prepare\s+the\s+workspace\s+myself|set\s+up\s+the\s+workspace\s+myself)\b",
        re.IGNORECASE,
    ),
]


def _clause_before(text, index):
    return text[
        max(
            text.rfind(".", 0, index),
            text.rfind(";", 0, index),
            text.rfind("\n", 0, index),
            0,
        ):index
    ]


def _affirmative_script_mention(text):
    """A skill-side env-sync script the output proposes to USE.

    A negated mention ("the lane runs no env-sync script") is compliance.
    """
    for m in re.finditer(
        r"(remote-coder-env-sync|env-sync|coder-environment-preparation-clone)",
        text,
        re.IGNORECASE,
    ):
        look_back = _clause_before(text, m.start())
        if re.search(r"\b" + NEGATION + r"\b", look_back, re.IGNORECASE):
            continue  # negated — compliant
        return True
    return False


def _unnegated_failure(text):
    """A transport failure the output actually asserts (not "no error", "0 errors")."""
    for m in re.finditer(
        r"(transport\s+(?:call\s+)?(?:failed|error)|exited\s+non-?zero"
        r"|not implemented: live coder transport)",
        text,
        re.IGNORECASE,
    ):
        look_back = _clause_before(text, m.start())
        if re.search(
            r"\b(no|zero|without|0)\b[^.]{0,20}$", look_back, re.IGNORECASE
        ):
            continue  # negated in this clause — not a failure report
        # "transport error count was 0" — the negation can trail the phrase.
        trail = text[m.end():m.end() + 40]
        if re.match(r"\s*(count\s+)?(was\s+|is\s+|=\s*)?(0|zero|no)\b", trail, re.IGNORECASE):
            continue  # a count of zero — not a failure report
        return True
    return False


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
        r"(adlc-cli\s+(workspace|agent|workflow)\b[\s\S]{0,120}--provider\s+coder"
        r"|--provider\s+coder[\s\S]{0,80}adlc-cli"
        r"|adlc-cli[\s\S]{0,40}--provider[= ]coder)",
        text,
        re.IGNORECASE,
    )
    if not transport and not failure_case:
        reasons.append(
            "no adlc-cli provider transport call (adlc-cli workspace setup --provider coder)"
        )

    # 2. No skill-side env sync.
    if _affirmative_script_mention(text):
        reasons.append("uses a skill-side env-sync script instead of the transport")

    for pattern in MANUAL_SYNC:
        if pattern.search(text):
            reasons.append("performs the environment sync by hand over `coder ssh`")
            break

    # 3. Transport failure halts, never falls back to a script. Only judged
    #    when the scenario is the transport-failure case, or the output
    #    reports a strong transport failure of its own.
    reports_failure = failure_case or _unnegated_failure(text)
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
