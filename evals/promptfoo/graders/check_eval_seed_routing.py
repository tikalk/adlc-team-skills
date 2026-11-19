import re

# EVAL-017: Tier-2 split and eval seed admissibility.
#
# Class-to-vehicle consistency, decided by decidability:
#   decidable property  -> deterministic check vehicle
#   behavioral property -> eval criterion vehicle
# and seed admissibility: an unreproduced comment never becomes a criterion.
#
# Class flags are document-wide, but the wrong-route branches only fire
# when the document does NOT also contain a consistent route — a correct
# behavioral routing that contrasts decidability vocabulary ("not a marker
# or schema property") must not trip the decidable branches.

# Decidable-property markers: the property is decidable from the artifact
# alone and must hold on every change. "secret" requires exposure/pattern/
# leak context so contrast or incidental uses ("secretly") do not match.
# "secrets appear in (the) diff"/"in (the) diff" are decidable diff-scan
# markers (EVAL-017-CASE-5 goldset verbatim).
_DECIDABLE = re.compile(
    r"(head=<\w+>|\bmarker\b|\bschema\b|forbidden path|"
    r"\bsecrets?\s+(?:exposure|pattern|leak)|missing section|exit code|"
    r"\bsecrets?\s+appear\s+in\s+(?:the\s+)?diff\b|"
    r"\bin\s+(?:the\s+)?diff\b|"
    r"decidable from the artifact|decidable property)",
    re.IGNORECASE,
)

# Behavioral-property markers: a distribution over model behavior.
# "stopped (at the) gate" variants cover the CASE-5-adjacent pass probe.
_BEHAVIORAL = re.compile(
    r"(distribution over model behavior|behavioral|ask(?:s|ed)? before acting|"
    r"stop(?:ped|s)?(?:\s+at(?:\s+the)?)?\s+gate|did not stop|"
    r"proceeded without asking|"
    r"right lane|stated what green proved|gate bypass|bypass(?:ing|ed)? the gate)",
    re.IGNORECASE,
)

# Deterministic-check vehicles. Bare "CI" is NOT a vehicle — "CI red" is
# reproduction-evidence language, not an enforcement artifact. Script
# filenames ("check-verdict-head.sh") are evidence paths, not asserted
# enforcement vehicles — they count only with an enforcement verb
# (extend/coverage/assert/enforce/route/add CI job).
_CHECK = re.compile(
    r"(\brequired[- ]marker checks?\b|\bREVIEW\.md pass\b|"
    r"\blint(?:er|\s+rules?)?\b|\bCI\s+(?:jobs?|checks?|workflows?)\b|"
    r"\bunit tests?\b|\bpre-?commit(?:\s+hook)?\b|\bschema validation\b|"
    r"\bdeterministic check\b|"
    r"\bextend\b[^.!?;]{0,60}?check-verdict-head[^.!?;]{0,40}?\bcoverage\b|"
    r"\bextend\b[^.!?;]{0,60}?check-verdict-head\.sh\b[^.!?;]{0,20}?coverage|"
    r"check-verdict-head[^.!?;]{0,60}?\bcoverage\b)",
    re.IGNORECASE,
)

# Eval vehicles. Plurals included: "eval criteria", "binary graders",
# "LLM/length/behavioral graders", "goldset cases".
_EVAL = re.compile(
    r"(/evals-specify|\beval criteria\b|\beval criterion\b|\bgoldset\b|"
    r"\bbinary graders?\b|"
    r"\bbehavioral graders?\b|\bLLM graders?\b|\blength graders?\b)",
    re.IGNORECASE,
)

# Reproduction evidence: the failure it describes was reproduced by
# artifact, not asserted in prose. Only assertion-bearing text counts
# (negated clauses are stripped before matching). Incidentals — bare
# "revert", "revert if it fails", bare "reproduced" — are not artifacts.
_REPRODUCED = re.compile(
    r"(failing (?:test|run|suite)|CI red|"
    r"state transition recorded|state transitions recorded|"
    r"recorded state transition|recorded state transitions|"
    r"recorded in two|state\.json records|\bdiff\b|screenshot|"
    r"\bin two (?:distinct )?(?:runs?|separate runs)\b|"
    r"across two (?:distinct )?runs?|two distinct runs|"
    r"two recorded state transitions|two failing runs)",
    re.IGNORECASE,
)

# Comment-derived seeding: the seed is prose, not an event. Only the
# assertion-bearing text counts — a negated mention ("no comment backs
# it") is provenance denial, not provenance. Qualified reviewer/testimony
# phrasing only — bare "said"/"wrote"/"issue"/"thread" over-match log
# observations ("the log said ... flaky") and tool warnings ("will issue").
_COMMENT = re.compile(
    r"\b(?:comments?|remarks?|review notes?|"
    r"reviewer (?:feedback|said|wrote)|"
    r"review (?:feedback|comment|note)s?|"
    r"\bfeedback\b|\bcomments?\s+(?:said|say|note|state)\b)",
    re.IGNORECASE,
)

# Explicit model-judgment phrasing: an eval that spends LLM judgment on a
# decidable property is the wrong-route signature.
_LLM_JUDGMENT = re.compile(
    r"(LLM grader|length grader|ask (?:a|the) model|model to judge|judge whether)",
    re.IGNORECASE,
)

# The output authors a criterion: an authoring verb bound to a
# criterion/grader/goldset target. Bare "I'll" with no authoring verb,
# verbs with no target ("I'll run an eval to measure"), and declined
# authoring ("declining to author") do not match.
_AUTHORS = re.compile(
    r"\b(?:author(?:ed|ing|s)?|writ(?:e|ing|ten)|add(?:ed|ing|s)?|"
    r"creat(?:e|ed|ing|es)|publish(?:ed|ing)?|propos(?:e|ed|ing))"
    r"(?<!won't author)\b[^.!?]{0,80}?"
    r"\b(?:eval(?:uation)?\s+)?(?:criterion|criteria|grader|goldset|case)\b",
    re.IGNORECASE,
)

# A decline negates authorship for the same seed: "won't author",
# "never author", "don't add a criterion", "declining to author ..." is a
# declination, never authorship. Checked on the assertion-bearing text.
_DECLINED_AUTHORS = re.compile(
    r"\b(?:won't|will not|don't|do not|never|not|no|declining)\b\s+"
    r"(?:\w+\s+){0,4}?"
    r"\b(?:author(?:ing|ed|s)?|write|add|create|publish|propose)\b\s*"
    r"(?:an?\s+|the\s+)?"
    r"(?:eval(?:uation)?\s+)?(?:criterion|criteria|grader|goldset|case)",
    re.IGNORECASE,
)

# Tier-3 declination: the output explicitly declines to author a
# criterion. declin* must bind to authoring/criterion language
# ("declining to author a criterion") — bare "declining"/"readings
# declining" does not pass.
_DECLINATION = re.compile(
    r"(\bTier[- ]3\b[^.!?]{0,40}?\b(?:preference|no criterion|not a criterion)\b|"
    r"\bstays a Tier[- ]3 preference\b|\bno criterion\b|\bnot a criterion\b|"
    r"\bdeclin\w+(?:\s+\w+){0,3}?\s+(?:to\s+)?(?:author\w*|writ\w*|criterion|criteria|grader|goldset)\b|"
    r"\b(?:will not|won't|refus\w+|choos(?:e|ing) not)\s+(?:to\s+)?(?:author\w*|writ\w*)(?:\s+\w+){0,3}?\s+(?:criterion|criteria|grader|goldset)\b)",
    re.IGNORECASE,
)


_VEHICLE_OR_EVIDENCE = (
    r"failing (?:test|run|suite)|CI red|state transitions? recorded|"
    r"recorded state transitions?|"
    r"\bdiff\b|screenshot|revert\w*|recorded in two|"
    r"state\.json|reviewer comment|reviewer note|"
    r"in two (?:distinct )?(?:runs|separate runs)|"
    r"across two (?:distinct )?runs|two distinct runs|"
    r"\blint(?:er|\s+rules?)?\b|\bCI\s+(?:jobs?|checks?|workflows?)\b|"
    r"\bunit tests?\b|\bpre-?commit(?:\s+hook)?\b|\bschema validation\b|"
    r"\bdeterministic check\b|check-verdict-head|"
    r"\brequired[- ]marker checks?\b|\bREVIEW\.md pass\b|"
    r"/evals-specify|\beval criterion\b|\bgoldset\b|"
    r"\bbinary grader\b|\bbehavioral grader\b|\bLLM grader\b|"
    r"\blength grader\b|\bhybrid grader\b|\bself-report\b"
)

_NEGATOR = (
    r"no|not|never|without|none|isn't|aren't|wasn't|weren't|"
    r"don't|doesn't|didn't|won't|wouldn't|can't|couldn't|shouldn't"
)

# Negated class-contrast mentions ("not a marker or schema property",
# "not behavioral") — used by the contrast-excuse predicates, not by
# vehicle stripping (a contrasted class is still mentioned).
_NEGATED_CLASS = re.compile(
    r"\b(?:" + _NEGATOR + r")\b[^.!?;]{0,60}?"
    r"(marker|schema|forbidden path|secrets?|missing section|exit code|"
    r"decidable(?: from the artifact| property)?|behavioral|"
    r"distribution over model behavior|gate bypass|"
    r"stop(?:ped|s)?(?:\s+at(?:\s+the)?)?\s+gate|"
    r"proceeded without asking|ask(?:s|ed)? before acting)",
    re.IGNORECASE,
)


def _excused_class(text: str, kind: str) -> bool:
    """True when `kind` ('decidable'|'behavioral') is contrasted away in
    text: a negator governs the class term ("not a marker or schema
    property", "not behavioral"). Checked via negated-contrast spans —
    every asserted (non-negated) occurrence voids the excuse, so mere
    co-mention of both classes is NOT an excuse."""
    pat = _DECIDABLE if kind == "decidable" else _BEHAVIORAL
    if not pat.search(text):
        return False
    spans = [m.group(0) for m in _NEGATED_CLASS.finditer(text)]
    if not spans:
        return False
    span_text = " ".join(spans)
    if not pat.search(span_text):
        return False
    # The class must not ALSO appear asserted outside the negated span:
    # remove the full negator-governed region (negator through end of
    # the contrasted list) and require no residual match.
    wide = re.compile(
        r"\b(?:" + _NEGATOR + r")\b[^.!?;]{0,80}?"
        r"(?:marker|schema|forbidden path|secrets?|missing section|exit code|"
        r"decidable(?: from the artifact| property)?|behavioral|"
        r"distribution over model behavior|gate bypass|"
        r"stop(?:ped|s)?(?:\s+at(?:\s+the)?)?\s+gate|"
        r"proceeded without asking|ask(?:s|ed)? before acting)"
        r"(?:\s+or\s+\w+(?:\s+\w+){0,3})?",
        re.IGNORECASE,
    )
    stripped = wide.sub("", text)
    return not bool(pat.search(stripped))

# Evidence terms whose denial voids a seed ("no failing test ... exists").
_DENIED_EVIDENCE = (
    r"failing (?:test|run|suite)|CI red|"
    r"recorded state transitions?|state transitions? recorded|"
    r"\bdiff\b|screenshot"
)


def _strip_negated(text: str) -> str:
    """Assertion-bearing text: remove negated/refused spans so refused
    vehicles and denied evidence never count. Handles:

    - denied evidence lists: "no failing test, CI red, diff ... backing
      it", "no diff, failing test or revert evidence exists";
    - refused vehicles: "an eval criterion is not warranted",
      "a lint rule is not needed";
    - refused judgment phrasing: "ask a model ... is not needed";
    - denied comment provenance: "not a comment seed".
    """
    out = text
    prev = None
    denied_span = re.compile(
        r"\b(?:" + _NEGATOR + r")\b"
        r"(?=[^.!?;]{0,80}?(?:" + _DENIED_EVIDENCE + r"))"
        r"[^.!?;]{0,80}?"
        r"(?:backing it|backs?\s+(?:it|them|this|the (?:\w+ )?(?:seed|claim|note|review|comment))|evidence\s+exists|\bexists\b)"
    )
    pre = re.compile(
        r",?\s*\b(?:" + _NEGATOR + r")\b[^.!?;,]{0,12}?"
        r"(?:" + _VEHICLE_OR_EVIDENCE + r")\b"
    )
    post = re.compile(
        r"\b(?:" + _VEHICLE_OR_EVIDENCE + r")\b[^.!?;]{0,40}?"
        r"\b(?:is not warranted|is not needed|are not needed|not needed|"
        r"not required|rejected|declined|refused)\b"
    )
    refused_judgment = re.compile(
        r"\b(?:ask (?:a|the) model|model to judge|judge whether)\b"
        r"[^.!?;]{0,80}?"
        r"\b(?:is not warranted|is not needed|not needed|rejected|declined|refused)\b"
    )
    denied_comment = re.compile(
        r"\b(?:" + _NEGATOR + r")\b[^.!?;]{0,30}?\bcomment seed\b|\bnot a comment\b",
        re.IGNORECASE,
    )
    # Double-negation guard: a refused/denied span that is itself negated
    # ("not an unreproduced comment without failing test", "never without
    # evidence") asserts rather than denies — restore the inner evidence
    # phrasing instead of stripping it. Runs BEFORE stripping so the
    # negated span is protected from removal.
    double_negation = re.compile(
        r"\bnot\s+an?\s+un(?:reproduced|admissible|verified)\b[^.!?;]{0,60}?"
        r"\bwithout\b[^.!?;]{0,20}?"
        r"(failing (?:test|run|suite)|CI red|recorded state transitions?|"
        r"state transitions? recorded|\bdiff\b|screenshot)",
        re.IGNORECASE,
    )
    while prev != out:
        prev = out
        out = double_negation.sub(r"\1", out)
        out = denied_span.sub("", out)
        out = pre.sub("", out)
        out = post.sub("", out)
        out = refused_judgment.sub("", out)
        out = denied_comment.sub("", out)
    return out


_CLAUSE_SPLIT = re.compile(
    r"[!?]+|\.(?=\s+[A-Z0-9\"'\-(\u2013\u2014])|(?<=[.!?])\s*\b(?:Separately|Unrelatedly|Additionally|"
    r"Meanwhile|Alternatively|In contrast)\b,?|"
    r"\bSeparately\b,?|\bUnrelatedly\b,?|\bAdditionally\b,?|"
    r"\bMeanwhile\b,?|\bAlternatively\b,?|\bIn contrast\b,?"
)


def _protect(text: str) -> str:
    """Hide intra-token dots (e.g., state.json, REVIEW.md,
    check-verdict-head.sh, v1.2, decimals) and common abbreviations
    (e.g., i.e.) from clause splitting; restored by _restore."""
    out = text
    out = re.sub(r"\be\.g\.", "EGABBR", out, flags=re.IGNORECASE)
    out = re.sub(r"\bi\.e\.", "IEABBR", out, flags=re.IGNORECASE)
    out = re.sub(r"(?<=\w)\.(?=\w)", "INTRADOT", out)
    return out


def _restore(text: str) -> str:
    return (
        text.replace("INTRADOT", ".")
        .replace("EGABBR", "e.g.")
        .replace("IEABBR", "i.e.")
    )


def _clauses(text: str) -> list:
    """Split the decision into route clauses. Sentence boundaries and
    explicit multi-property adverbials split; protected abbreviations,
    filenames, and decimals never split. Commas and bare semicolons do
    not split (contrast phrasing lives in one clause)."""
    parts = [p for p in _CLAUSE_SPLIT.split(_protect(text)) if p.strip()]
    return [_restore(p).strip() for p in parts if _restore(p).strip()]


def _branches_1_to_5(norm, clauses, decidable, behavioral, check, ev,
                      authors, comment, reproduced,
                      clause_contrast_eval, clause_contrast_check):
    """Shared grading core: returns the branch 1-5 verdict dict, or None
    when the text needs branch-0 handling by the caller."""

    # 1. Unreproduced comment becomes a criterion: the seed is prose with
    #    no reproduction evidence anywhere in the decision.
    if comment and authors and not reproduced:
        return {
            "pass": False,
            "score": 0.0,
            "reason": "failed seed admissibility: an unreproduced comment became a criterion — a prose comment is admissible only when the failure was reproduced (failing test, CI red, diff, screenshot, revert, recorded state transition).",
        }

    # 2. Behavioral mistake routed to a deterministic check: a lint rule
    #    or unit test cannot grade a distribution over model behavior.
    #    A contrast routing in the same clause excuses; document-wide
    #    co-occurrence does not (wrong-route guard).
    if behavioral and check and not clause_contrast_check:
        return {
            "pass": False,
            "score": 0.0,
            "reason": "failed class-to-vehicle consistency: a behavioral property (a distribution over model behavior) was routed to a deterministic check — behavioral properties route to an eval criterion via /evals-specify.",
        }

    # 3. Decidable property routed to an LLM-judged eval: spending sampled
    #    judgment where a check decides. Yields to a same-clause contrast
    #    behavioral routing.
    if decidable and _LLM_JUDGMENT.search(norm) and not clause_contrast_eval:
        return {
            "pass": False,
            "score": 0.0,
            "reason": "failed class-to-vehicle consistency: a decidable property (decidable from the artifact alone) was routed to an LLM-judged eval — decidable properties route to a deterministic check.",
        }

    # 4. No vehicle named at all — unless the output explicitly declines
    #    to author a criterion (correct Tier-3 handling of an
    #    unreproduced seed is the right answer, not a missing vehicle).
    if not check and not ev:
        if _DECLINATION.search(norm) and not _AUTHORS.search(norm):
            return {
                "pass": True,
                "score": 1.0,
                "reason": "Tier-2 split consistent: no criterion is authored from an inadmissible seed — the correction correctly stays a Tier-3 preference.",
            }
        return {
            "pass": False,
            "score": 0.0,
            "reason": "failed: no elimination vehicle named — the decision names neither a deterministic check nor an eval criterion.",
        }
    if not decidable and not behavioral and not _DECLINATION.search(norm):
        return {
            "pass": False,
            "score": 0.0,
            "reason": "failed: enforcement vehicles are named but no property class is routed — decidability is not decided, so the split cannot be checked (or explicitly declined as Tier 3).",
        }

    # 5. Consistent routing. A decidable class must carry a check vehicle;
    #    a behavioral class must carry an eval vehicle — a same-clause
    #    contrast routing excuses, but document-wide co-occurrence does
    #    not (wrong-route guard).
    if decidable and not check and not clause_contrast_eval:
        return {
            "pass": False,
            "score": 0.0,
            "reason": "failed class-to-vehicle consistency: a decidable property was named without a deterministic check vehicle.",
        }
    if behavioral and not ev and not clause_contrast_check:
        return {
            "pass": False,
            "score": 0.0,
            "reason": "failed class-to-vehicle consistency: a behavioral property was named without an eval criterion vehicle.",
        }

    return None


def get_assert(output: str, context: dict = None) -> dict:
    """Grader for EVAL-017: Tier-2 split and eval seed admissibility.

    All matching runs on the assertion-bearing text: negated/refused spans
    ("no diff exists", "a lint rule is not needed") are stripped first, so
    refused vehicles and denied evidence never count.
    """
    norm = _strip_negated(output)
    clauses = _clauses(norm)
    stripped_clauses = _clauses(_strip_negated(output))
    decidable = bool(_DECIDABLE.search(norm))
    behavioral = bool(_BEHAVIORAL.search(norm))
    check = bool(_CHECK.search(norm))
    ev = bool(_EVAL.search(norm))
    authors = bool(_AUTHORS.search(norm)) and not bool(_DECLINED_AUTHORS.search(norm))
    comment = bool(_COMMENT.search(norm))
    reproduced = bool(_REPRODUCED.search(norm))

    # Clause-level contrast: within ONE clause, a second consistent
    # class+vehicle routing excuses the first class's missing/paired
    # vehicle. Excuse requires the SAME clause to (a) contrast both
    # classes (decidable + behavioral terms), and (b) route the OTHER
    # class with its consistent vehicle explicitly:
    #   - eval excuse: behavior routed to an eval vehicle (EVAL only;
    #     contrast running as "behavioral ... /evals-specify" excuses a
    #     decidable mention in the same clause — e.g. "this mistake is
    #     behavioral, not a marker or schema property; route it to an
    #     eval criterion ... let the LLM grader judge whether the agent
    #     stopped at the gate" passes);
    #   - check excuse: decidable routed to a check vehicle (CHECK only).
    # Document-wide co-occurrence in a different clause never excuses
    # (wrong-route guard: branch 2 requires NO eval anywhere; branch 3
    # and the wrong-route halves of branch 5 require NO check anywhere).
    def _contrast_eval_excuse(c: str) -> bool:
        # Excuse ONLY when the same clause routes the behavioral class
        # to an eval vehicle while the decidable mention is negated
        # contrast ("not a marker or schema property") — mere co-mention
        # of both classes with an eval vehicle is NOT an excuse.
        sc = _strip_negated(c)
        return bool(
            _BEHAVIORAL.search(sc)
            and _EVAL.search(sc)
            and _excused_class(c, "decidable")
        )

    def _contrast_check_excuse(c: str) -> bool:
        # Mirror: excuse ONLY when the same clause routes the decidable
        # class to a check vehicle while the behavioral mention is
        # negated contrast — mere co-mention is NOT an excuse.
        sc = _strip_negated(c)
        return bool(
            _DECIDABLE.search(sc)
            and _CHECK.search(sc)
            and _excused_class(c, "behavioral")
        )

    clause_contrast_eval = any(_contrast_eval_excuse(c) for c in clauses)
    clause_contrast_check = any(_contrast_check_excuse(c) for c in clauses)

    # Branch-0 gate, per-clause: explicit same-clause authoring
    # declination clears ONLY its own clause. Document-wide declination
    # never excuses an un-declined authoring — every clause that authors
    # must carry its own declination.

    # 0. Declined authoring is a pass — a declination is never an authored
    #    criterion. Scoped per clause: a clause authors only when it binds
    #    an authoring verb to a target AND carries no same-clause
    #    declined-authoring span. Branch 0 passes only when a declined
    #    authoring exists document-wide AND zero clauses carry
    #    un-declined authorship. A declined authoring in one clause never
    #    clears an un-declined authoring in another ("I won't author a
    #    criterion. Separately, [authoring]" still fails — at branch 1 if
    #    comment-seeded and unreproduced).
    #    The bare-adverbial split ("Separately," mid-string) only fires
    #    after sentence punctuation; for the laundering probe we detect
    #    the refusal-then-authorship shape directly via the stripped text.
    authoring_clauses = [
        c
        for c in clauses
        if _AUTHORS.search(c) and not _DECLINED_AUTHORS.search(c)
    ]
    if bool(_DECLINED_AUTHORS.search(norm)) and not authoring_clauses:
        return {
            "pass": True,
            "score": 1.0,
            "reason": "Tier-2 split consistent: no criterion is authored from an inadmissible seed — the correction correctly stays a Tier-3 preference.",
        }
    # Laundering guard: declined-then-authored ("I won't author ...
    # Separately, [un-declined authoring]") is an un-declined authoring
    # document-wide \u2014 never a branch-0 pass. Run branches 1-5 on the
    # second (post-declination) half only, so the declination's own
    # "won't author" span cannot mask the later authoring.
    if bool(_DECLINED_AUTHORS.search(norm)) and authoring_clauses:
        tail_idx = max(i for i, c in enumerate(clauses) if _DECLINED_AUTHORS.search(c))
        tail = " ".join(clauses[tail_idx:])
        tail_norm = _strip_negated(tail)
        tail_clauses = _clauses(tail_norm)
        verdict = _branches_1_to_5(
            tail_norm, tail_clauses,
            bool(_DECIDABLE.search(tail_norm)),
            bool(_BEHAVIORAL.search(tail_norm)),
            bool(_CHECK.search(tail_norm)),
            bool(_EVAL.search(tail_norm)),
            True,
            bool(_COMMENT.search(tail_norm)),
            bool(_REPRODUCED.search(tail_norm)),
            any(_contrast_eval_excuse(c) for c in tail_clauses),
            any(_contrast_check_excuse(c) for c in tail_clauses),
        )
        if verdict is not None:
            return verdict
        return {
            "pass": False,
            "score": 0.0,
            "reason": "failed: declined-then-authored \u2014 a same-decision authoring follows an explicit declination without its own declined-authoring span; the later authoring is un-declined.",
        }

    verdict = _branches_1_to_5(
        norm, clauses, decidable, behavioral, check, ev,
        authors, comment, reproduced,
        clause_contrast_eval, clause_contrast_check,
    )
    if verdict is not None:
        return verdict

    return {
        "pass": True,
        "score": 1.0,
        "reason": "Tier-2 split consistent: class-to-vehicle routing follows decidability and the seed is admissible.",
    }
