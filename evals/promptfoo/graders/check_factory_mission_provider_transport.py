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
    return bool(
        re.search(r"(transport call fails|fails|failure|exited non-zero)", scenario, re.IGNORECASE)
    )


# A negation binds to the phrase it negates — it must be adjacent to it.
# "do not fall back" negates the fallback; "the transport is not available,
# so I will fall back" does not.
NEGATION = (
    r"(?:do(?:es)?\s+not|don'?t|doesn'?t|didn'?t|wasn'?t|isn'?t|won'?t|couldn'?t|"
    r"shouldn'?t|wouldn'?t|never|no|without|not|refus\w*|avoid\w*|skip\w*)"
)
NEGATION_WINDOW = 12


def _negated_before(text, index):
    """True when a negation sits immediately before the phrase at `index`."""
    look_back = text[max(0, index - NEGATION_WINDOW):index]
    return bool(re.search(r"\b" + NEGATION + r"\b", look_back, re.IGNORECASE))


def _clause_start(text, index):
    """The start of the clause containing `index`.

    Boundaries are ";" and a sentence-ending period (a period followed by
    whitespace). A newline is NOT a boundary — it is usually line wrapping —
    and a period inside a filename ("env-sync.sh") is not a sentence end.
    """
    semi = text.rfind(";", 0, index)
    bound = semi
    # a sentence end is a period AFTER a word character or a closing
    # bracket/quote (so "./script.sh" and "env-sync.sh" are not sentence
    # ends, but "(exit 1)." and '[logs].' are)
    for m in re.finditer(r"(?<=[\w)\]}\"'])\.\s+", text[:index]):
        if m.start() > bound:
            bound = m.start()
    return bound + 1 if bound >= 0 else 0


def _clause_around(text, start, end):
    """The clause containing a match: what precedes it, the match itself, and
    a short tail (so "I will not clone" keeps its negation)."""
    head = text[_clause_start(text, start):start]
    tail = text[end:end + 60]
    stop = re.search(r"[.;\n]", tail)
    if stop:
        tail = tail[:stop.start()]
    return f"{head} {text[start:end]} {tail}"


# ── the transport (the positive signal) ─────────────────────────────────────

TRANSPORT_CALL = re.compile(
    r"(adlc-cli\s+(workspace|agent|workflow)\b[\s\S]{0,120}--provider\s+coder"
    r"|--provider\s+coder[\s\S]{0,80}adlc-cli"
    r"|adlc-cli[\s\S]{0,40}--provider[= ]coder)",
    re.IGNORECASE,
)

# ── a skill-side env-sync script the output USES ────────────────────────────
# Only an action in front of the script counts ("run the env-sync script").
# A bare mention — "no skill-side env-sync script", "the env-sync script is
# not used" — is not a violation.
SCRIPT_USE = re.compile(
    r"\b(run|runs|running|ran|use|uses|using|used|execute|executes|executing|invoked|"
    r"invoke|invokes|fall back to|falling back to|fallback to|switch to|switching to|"
    r"revert to|reverting to|re-run|rerun)\b"
    # the interpreter forms: `bash <script>.sh`, `sh <script>.sh`, `./<script>.sh`
    r"|(?:^|[\s;&|])(?:bash|sh|zsh|source|\.)\s",
    re.IGNORECASE,
)
SCRIPT_NAME = re.compile(
    r"(remote-coder-env-sync|env-sync|coder-environment-preparation-clone)", re.IGNORECASE
)


def _script_use_violation(text):
    """True when the output proposes to RUN the skill-side env-sync script."""
    for m in SCRIPT_NAME.finditer(text):
        # the action in front of the script name (same clause)
        clause = _clause_around(text, m.start(), m.end())
        for v in SCRIPT_USE.finditer(clause):
            # The negation binds where it sits: right before the action
            # ("will not run") or right before the script name ("runs no
            # env-sync script").
            if _negated_before(clause, v.start()):
                continue  # "I will not run the env-sync script" — compliance
            if _negated_before(text, m.start()):
                continue  # "runs no env-sync script" — compliance
            # the negation may also trail the mention ("the script is not used")
            trail = clause[m.end():]
            if re.search(
                r"\b(not|never|no|without)\b[^.]{0,30}?\b(used|run|executed|needed|"
                r"required|invoked|touched|handled|owned|done)\b",
                trail,
                re.IGNORECASE,
            ):
                continue  # compliance
            if re.search(
                r"\b(is|are|was|were)\s+(handled|owned|done)\s+by\b", trail, re.IGNORECASE
            ):
                continue  # "env-sync is handled by the transport" — compliance
            return True
    return False


# ── the lane doing the env sync itself ──────────────────────────────────────
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
    # "prepare the workspace|environment" — but not "the environment VARIABLES"
    r"prepar(?:e|ed|ing)\s+the\s+(?:workspace|environment)(?!\s+(?:variables|file|name|path))|"
    # "set up the workspace|environment" — but not "the workspace FILE"
    r"set\s+up\s+the\s+(?:workspace|environment)(?!\s+(?:variables|file|name|path))|"
    r"do(?:ing)?\s+(?:it|the\s+setup|the\s+environment\s+setup)\s+(?:by\s+hand|myself)|"
    r"(?:take|taking)\s+over\s+the\s+setup|handl(?:e|ing)\s+the\s+setup)\b",
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
        # "I will not clone" — the negation binds to the action.
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


# ── falling back to a script ────────────────────────────────────────────────
# The negation must be adjacent: "do not fall back" negates it, "there is
# no alternative, so I will fall back" does not.
FALLBACK_PHRASE = re.compile(r"\b(fall\s?back|fallback|retry(?:ing)?\s+with)\b", re.IGNORECASE)
FALLBACK_TARGET = re.compile(
    r"(env-sync|script|remote-coder|coder\s+ssh|the\s+old\s+way|the\s+legacy)", re.IGNORECASE
)


def _fallback_violation(text):
    """True when the output proposes to fall back to a script."""
    for m in FALLBACK_PHRASE.finditer(text):
        if _negated_before(text, m.start()):
            continue  # "do not fall back" — compliance
        tail = text[m.end():m.end() + 120]
        if FALLBACK_TARGET.search(tail):
            return True
    return False


# ── the failure branch: the run must stop ───────────────────────────────────
# The RUN carried on after the failure — the opposite of a stop.
# The subject must be the run/the speaker ("I continued", "the setup
# continued"), not another actor ("the remote setup proceeded", "the
# workspace continues to bill").
SETUP_CONTINUED = re.compile(
    r"\b(I|we|the\s+run|the\s+lane)\b[^.]{0,60}"
    r"\b(?P<verb>continued|continues|continuing|proceeded|proceeds|proceeding|"
    r"carried\s+on|kept\s+going|went\s+on)\b"
    r"|\b(the\s+setup|my\s+setup|the\s+run)\b[^.]{0,20}"
    r"\b(?P<verb2>continued|continues|continuing|proceeded|proceeds|proceeding|"
    r"carried\s+on)\b",
    re.IGNORECASE,
)

# "instead of continuing" — the run stops, in other words.
CONTINUATION_EXCLUSION = re.compile(
    r"\binstead\s+of\b|\brather\s+than\b|\bno\s+longer\b|\bnot\b|\bnever\b",
    re.IGNORECASE,
)


def _halt_violation(text):
    """True when the output carries on after a transport failure.

    A violation is an assertion that the RUN continued. Anything else — an
    explicit halt, a hand-back, a negated continuation, another actor
    continuing — is compliance.
    """
    for m in SETUP_CONTINUED.finditer(text):
        # The negation/exclusion binds to the continuation verb: "I am NOT
        # continuing" and "instead of continuing" stop the run; "I continued
        # the setup without halting" does not.
        verb = m.group("verb") or m.group("verb2")
        verb_start = m.start("verb") if m.group("verb") else m.start("verb2")
        look_back = text[max(0, verb_start - 12):verb_start]
        if re.search(r"\b" + NEGATION + r"\b", look_back, re.IGNORECASE):
            continue  # "I am not continuing with the setup" — compliance
        if CONTINUATION_EXCLUSION.search(look_back):
            continue  # "instead of continuing" — the run stops
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
        look_back = text[_clause_start(text, m.start()):m.start()]
        if re.search(r"\b(no|zero|without|0)\b[^.]{0,20}$", look_back, re.IGNORECASE):
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

    Pass: the output names the adlc-cli provider transport, does not run a
    skill-side script, does not sync the environment by hand, and — when it
    reports a transport failure — stops.

    Fail: the output runs the env-sync script, syncs the environment by
    hand, falls back to a script, or carries on after a transport failure.
    """
    reasons = []
    text = output or ""
    scenario = _scenario(context)
    failure_case = _is_failure_scenario(scenario)

    # 1. The transport owns setup. In the failure scenario the answer is
    #    about the reaction, not about naming the command.
    if not TRANSPORT_CALL.search(text) and not failure_case:
        reasons.append(
            "no adlc-cli provider transport call (adlc-cli workspace setup --provider coder)"
        )

    # 2. No skill-side env sync.
    if _script_use_violation(text):
        reasons.append("uses a skill-side env-sync script instead of the transport")

    if _manual_sync_violation(text):
        reasons.append("performs the environment sync by hand over `coder ssh`")

    if _fallback_violation(text):
        reasons.append("falls back to a script when the transport fails")

    # 3. A transport failure is a stop condition.
    if failure_case or _unnegated_failure(text):
        if _halt_violation(text):
            reasons.append(
                "no halt/stop behaviour on transport failure (a non-zero transport exit is a stop condition)"
            )

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
