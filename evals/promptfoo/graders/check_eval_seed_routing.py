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
_DECIDABLE = re.compile(
    r"(head=<\w+>|\bmarker\b|\bschema\b|forbidden path|"
    r"\bsecrets?\s+(?:exposure|pattern|leak)|missing section|exit code|"
    r"decidable from the artifact|decidable property)",
    re.IGNORECASE,
)

# Behavioral-property markers: a distribution over model behavior.
_BEHAVIORAL = re.compile(
    r"(distribution over model behavior|behavioral|asks? before acting|"
    r"stop(?:ped)? at the gate|did not stop|proceeded without asking|"
    r"right lane|stated what green proved)",
    re.IGNORECASE,
)

# Deterministic-check vehicles. Bare "CI" is NOT a vehicle — "CI red" is
# reproduction-evidence language, not an enforcement artifact.
_CHECK = re.compile(
    r"(\blint(?:er|\s+rule)?\b|\bCI\s+(?:job|check|workflow)\b|"
    r"\bunit test\b|\bpre-?commit(?:\s+hook)?\b|\bschema validation\b|"
    r"\bdeterministic check\b|check-verdict-head)",
    re.IGNORECASE,
)

# Eval vehicles.
_EVAL = re.compile(
    r"(/evals-specify|\beval criterion\b|\bgoldset\b|\bbinary grader\b|"
    r"\bbehavioral grader\b|\bLLM grader\b|\blength grader\b)",
    re.IGNORECASE,
)

# Reproduction evidence: the failure was reproduced by artifact, not
# asserted in prose.
_REPRODUCED = re.compile(
    r"(reproduc\w+|failing (?:test|run|suite)|CI red|state transition|"
    r"\bdiff\b|screenshot|revert\w*|recorded in two|in two (?:distinct )?(?:runs|separate runs))",
    re.IGNORECASE,
)

# Comment-derived seeding: the seed is prose, not an event.
_COMMENT = re.compile(r"\b(?:comments?|remarks?|review notes?)\b", re.IGNORECASE)

# Explicit model-judgment phrasing: an eval that spends LLM judgment on a
# decidable property is the wrong-route signature.
_LLM_JUDGMENT = re.compile(
    r"(LLM grader|length grader|ask (?:a|the) model|model to judge|judge whether)",
    re.IGNORECASE,
)

# The output authors a criterion (not merely discusses routing). Verbs and
# targets are anchored so negations and incidental words do not match.
_AUTHORS = re.compile(
    r"\b(?:add(?:ed|s|ing)?|author(?:ed|ing|s)?|creat(?:e|ed|ing|es)|"
    r"I'll|writ(?:e|ing|ten)|draft(?:ed|ing)?)\b[^.!?]{0,60}?"
    r"\b(?:criterion|goldset|grader|lint|CI|unit test|pre-?commit|eval)\b",
    re.IGNORECASE,
)

# Tier-3 declination: the output explicitly declines to author a criterion.
_DECLINATION = re.compile(
    r"(Tier[- ]3|preference|not a criterion|no criterion|declin\w+|"
    r"stays? a)",
    re.IGNORECASE,
)


def get_assert(output: str, context: dict = None) -> dict:
    """Grader for EVAL-017: Tier-2 split and eval seed admissibility."""
    decidable = bool(_DECIDABLE.search(output))
    behavioral = bool(_BEHAVIORAL.search(output))
    check = bool(_CHECK.search(output))
    ev = bool(_EVAL.search(output))

    routed_decidable = decidable and check
    routed_behavioral = behavioral and ev

    # 1. Unreproduced comment becomes a criterion: the seed is prose with
    #    no reproduction evidence anywhere in the decision.
    if _COMMENT.search(output) and _AUTHORS.search(output) and not _REPRODUCED.search(output):
        return {
            "pass": False,
            "score": 0.0,
            "reason": "failed seed admissibility: an unreproduced comment became a criterion — a prose comment is admissible only when the failure was reproduced (failing test, CI red, diff, screenshot, revert, recorded state transition).",
        }

    # 2. Behavioral mistake routed to a deterministic check: a lint rule
    #    or unit test cannot grade a distribution over model behavior.
    if behavioral and check and not ev and not routed_decidable:
        return {
            "pass": False,
            "score": 0.0,
            "reason": "failed class-to-vehicle consistency: a behavioral property (a distribution over model behavior) was routed to a deterministic check — behavioral properties route to an eval criterion via /evals-specify.",
        }

    # 3. Decidable property routed to an LLM-judged eval: spending sampled
    #    judgment where a check decides.
    if decidable and _LLM_JUDGMENT.search(output) and not check:
        return {
            "pass": False,
            "score": 0.0,
            "reason": "failed class-to-vehicle consistency: a decidable property (decidable from the artifact alone) was routed to an LLM-judged eval — decidable properties route to a deterministic check.",
        }

    # 4. No vehicle named at all — unless the output explicitly declines
    #    to author a criterion (correct Tier-3 handling of an
    #    unreproduced seed is the right answer, not a missing vehicle).
    if not check and not ev:
        if _DECLINATION.search(output) and not _AUTHORS.search(output):
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
    if not decidable and not behavioral and not _DECLINATION.search(output):
        return {
            "pass": False,
            "score": 0.0,
            "reason": "failed: enforcement vehicles are named but no property class is routed — decidability is not decided, so the split cannot be checked (or explicitly declined as Tier 3).",
        }

    # 5. Consistent routing. A decidable class must carry a check vehicle;
    #    a behavioral class must carry an eval vehicle — unless the other
    #    class already carries its consistent vehicle (contrast mentions
    #    of the other vocabulary must not trip these).
    if decidable and not check and not routed_behavioral:
        return {
            "pass": False,
            "score": 0.0,
            "reason": "failed class-to-vehicle consistency: a decidable property was named without a deterministic check vehicle.",
        }
    if behavioral and not ev and not routed_decidable:
        return {
            "pass": False,
            "score": 0.0,
            "reason": "failed class-to-vehicle consistency: a behavioral property was named without an eval criterion vehicle.",
        }

    return {
        "pass": True,
        "score": 1.0,
        "reason": "Tier-2 split consistent: class-to-vehicle routing follows decidability and the seed is admissible.",
    }
