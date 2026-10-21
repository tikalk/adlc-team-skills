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
NEGATION = (
    r"(?:do(?:es)?\s+not|don'?t|doesn'?t|didn'?t|wasn'?t|isn'?t|won'?t|couldn'?t|"
    r"shouldn'?t|wouldn'?t|never|no|without|not|refus\w*|avoid\w*|skip\w*)"
)
NEGATED_FALLBACK = re.compile(
    r"\b" + NEGATION + r"\b[^.]{0,30}?\b(fall\s?back|fallback|retry(?:ing)?\s+with)\b",
    re.IGNORECASE,
)


def _affirmative_fallback(text):
    """A fallback the output proposes to TAKE.

    The negation must be adjacent to the phrase it negates ("do not fall
    back" / "never fall back"). A negation earlier in the sentence ("the
    transport is not available, so I will fall back") does not excuse it.
    """
    for m in re.finditer(r"\b(fall\s?back|fallback|retry(?:ing)?\s+with)\b", text, re.IGNORECASE):
        look_back = text[max(0, m.start() - 12):m.start()]
        if re.search(r"\b" + NEGATION + r"\b", look_back, re.IGNORECASE):
            continue  # negated right here — compliant
        tail = text[m.end():m.end() + 120]
        if re.search(r"(env-sync|script|remote-coder|coder\s+ssh)", tail, re.IGNORECASE):
            return True
    return False


# The lane running the sync itself. The actor matters: "the transport
# performed the git clone" is NOT a violation, "I will clone the repo" is.
#
# 1. the remote-command form: coder ssh <ws> -- "git clone ..." / "skills add"
REMOTE_COMMAND_SYNC = re.compile(
    r"coder\s+ssh[^\n]{0,120}--\s*[\"'`]?[^\n]{0,40}(git\s+clone|skills\s+add|adlc-cli\s+skills)",
    re.IGNORECASE,
)

# 2. the SPEAKER doing the sync itself ("I clone …", "I am cloning …",
#    "I will clone …", "I cloned …"). The subject and the negation are
#    checked between the speaker and the action — a negation elsewhere in
#    the sentence must not excuse the action.
SPEAKER_ACTION = re.compile(
    r"\b(?:I|we)\b(?P<mid>[^.]{0,40}?)\b(?P<action>"
    r"clone[ds]?|cloning|install(?:ed|ing)?\s+the\s+skills|"
    r"sync(?:ed|ing)?\s+the\s+environment|copy(?:ied|ing)?\s+the\s+repo|"
    r"prepar(?:e|ed|ing)\s+the\s+workspace|set\s+up\s+the\s+workspace|"
    r"do(?:ing)?\s+it\s+by\s+hand|do(?:ing)?\s+it\s+myself|"
    r"do(?:ing)?\s+the\s+setup\s+myself)\b",
    re.IGNORECASE,
)

# a determiner right before the action means the action word is a NOUN
# ("we wait for the clone to finish"), not an act by the speaker.
DETERMINER = re.compile(r"\b(the|a|an|that|this|its|their)\s*$", re.IGNORECASE)

# another subject in between means someone else is acting
OTHER_SUBJECT = re.compile(
    r"\b(it|they|transport|cli|adlc-cli|provider|agent)\b", re.IGNORECASE
)

# phrases that hand the work to the transport (so the speaker is not doing it)
TRANSPORT_EXCLUSION = re.compile(
    r"(through|via|by|with)\s+the\s+(adlc-cli\s+)?(provider\s+)?transport"
    r"|\bnot\s+by\s+hand\b|\bnot\s+myself\b|\bthe\s+transport\s+(owns|does|did|cloned|"
    r"installed|performed|handled|ran)",
    re.IGNORECASE,
)


def _manual_sync_violation(text):
    """True when the output says the LANE performs the env sync itself."""
    if REMOTE_COMMAND_SYNC.search(text):
        return True
    for m in SPEAKER_ACTION.finditer(text):
        mid = m.group("mid")
        # "I will not clone" / "I am not going to clone" — the negation binds
        # to the action, so it is scoped to the text between the speaker and
        # the action. A negation elsewhere ("the transport is not available
        # so I will clone") must NOT excuse the action.
        if re.search(r"\b" + NEGATION + r"\b", mid, re.IGNORECASE):
            continue
        # "we wait for the clone to finish" — the action word is a noun.
        if DETERMINER.search(mid):
            continue
        # "I ran the transport; it cloned the repo" — someone else acted.
        if OTHER_SUBJECT.search(mid):
            continue
        clause = _clause_around(text, m.start(), m.end())
        if TRANSPORT_EXCLUSION.search(clause):
            continue  # "through the transport", "not by hand" — compliance
        return True
    return False


def _clause_around(text, start, end):
    """The clause containing a match: what precedes it, the match itself,
    and a short tail (so "I will not clone" keeps its negation)."""
    head = _clause_before(text, start)
    tail = text[end:end + 60]
    stop = re.search(r"[.;\n]", tail)
    if stop:
        tail = tail[:stop.start()]
    return f"{head} {text[start:end]} {tail}"


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

    A negated mention is compliance — in either direction: "the lane runs
    no env-sync script" (before) and "the env-sync script is not used"
    (after).
    """
    for m in re.finditer(
        r"(remote-coder-env-sync|env-sync|coder-environment-preparation-clone)",
        text,
        re.IGNORECASE,
    ):
        look_back = text[max(0, m.start() - 12):m.start()]
        if re.search(r"\b" + NEGATION + r"\b", look_back, re.IGNORECASE):
            continue  # negated right here — compliant
        trail = text[m.end():m.end() + 80]
        if re.search(
            r"\b(not|never|no|without)\b[^.]{0,40}?\b(used|run|executed|needed|required|"
            r"invoked|touched|handled|owned|done)\b",
            trail,
            re.IGNORECASE,
        ):
            continue  # negated after — compliant
        if re.search(
            r"\b(is|are|was|were)\s+(handled|owned|done)\s+by\b", trail, re.IGNORECASE
        ):
            continue  # "env-sync is handled by the transport" — compliance
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

    if _manual_sync_violation(text):
        reasons.append("performs the environment sync by hand over `coder ssh`")

    # 3. Transport failure halts, never falls back to a script. Only judged
    #    when the scenario is the transport-failure case, or the output
    #    reports a strong transport failure of its own.
    reports_failure = failure_case or _unnegated_failure(text)
    if reports_failure:
        # A run that CONTINUED after the transport failure is a violation in
        # its own right — no window-guessing needed.
        if re.search(
            r"\b(continued|continues|continuing|proceeded|proceeds|kept going|"
            r"carried on|carrying on|went on)\b",
            text,
            re.IGNORECASE,
        ):
            reasons.append(
                "the run continued after the transport failure (a non-zero transport exit is a stop condition)"
            )
        else:
            halts = False
            for m in re.finditer(
                r"\b(halt|halts|halted|halting|stop|stopped|stops|stopping|"
                r"abort|aborts|aborted|aborting)\b"
                r"|\bhand(?:s|ed|ing)?\s+back\b"
                r"|\bdo(?:es)?\s+not\s+(fall\s+back|fallback)\b"
                r"|\bno\s+fallback\b|\bnever\s+fall\s+back\b"
                r"|not implemented: live coder transport",
                text,
                re.IGNORECASE,
            ):
                look_back = text[max(0, m.start() - 30):m.start()]
                if re.search(r"\b" + NEGATION + r"\b", look_back, re.IGNORECASE):
                    continue  # "without halting", "no halt", "didn't stop"
                halts = True
                break
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
