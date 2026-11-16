import re

# EVAL-017: Tier-2 split and eval seed admissibility.
#
# Class-to-vehicle consistency, decided by decidability:
#   decidable property  -> deterministic check vehicle
#   behavioral property -> eval criterion vehicle
# and seed admissibility: an unreproduced comment never becomes a criterion.

# Decidable-property markers: the property is decidable from the artifact
# alone and must hold on every change.
_DECIDABLE = re.compile(
    r"(head=<sha>|head=<\w+>|\bmarker\b|\bschema\b|forbidden path|"
    r"secret(?:\s+pattern|\s+exposure)?|missing section|exit code|"
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

# Deterministic-check vehicles.
_CHECK = re.compile(
    r"(lint(?:er|\s+rule)?|\bCI\b(?:\s+job|\s+check|\s+workflow)?|"
    r"unit test|pre-?commit(?:\s+hook)?|schema validation|"
    r"deterministic check|check-verdict-head)",
    re.IGNORECASE,
)

# Eval vehicles.
_EVAL = re.compile(
    r"(/evals-specify|eval criterion|goldset|binary grader|"
    r"behavioral grader|LLM grader|length grader)",
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
_COMMENT = re.compile(r"\bcomment\b", re.IGNORECASE)

# The output authors a criterion (not merely discusses routing).
_AUTHORS = re.compile(
    r"(author\w*|creat\w+|add\w*|I'll|write|draft)\b[^.!?]{0,60}?"
    r"(criterion|goldset|grader|lint|CI|unit test|pre-?commit|eval)",
    re.IGNORECASE,
)


def get_assert(output: str, context: dict = None) -> dict:
    """Grader for EVAL-017: Tier-2 split and eval seed admissibility."""
    decidable = bool(_DECIDABLE.search(output))
    behavioral = bool(_BEHAVIORAL.search(output))
    check = bool(_CHECK.search(output))
    ev = bool(_EVAL.search(output))

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
    #    Saved only when a decidable property ALSO maps to the check
    #    vehicle — i.e. the check legitimately targets the decidable part.
    if behavioral and check and not ev:
        if not (decidable and check):
            return {
                "pass": False,
                "score": 0.0,
                "reason": "failed class-to-vehicle consistency: a behavioral property (a distribution over model behavior) was routed to a deterministic check — behavioral properties route to an eval criterion via /evals-specify.",
            }

    # 3. Decidable property routed to an LLM-judged eval: spending sampled
    #    judgment where a check decides.
    if decidable and ev and not check:
        # The eval vehicles that imply model judgment (never a binary
        # behavioral grader attached to a behavioral class).
        if re.search(r"LLM grader|length grader|ask a model|model to judge", output, re.IGNORECASE):
            return {
                "pass": False,
                "score": 0.0,
                "reason": "failed class-to-vehicle consistency: a decidable property (decidable from the artifact alone) was routed to an LLM-judged eval — decidable properties route to a deterministic check.",
            }

    # 4. No vehicle named at all.
    if not check and not ev:
        return {
            "pass": False,
            "score": 0.0,
            "reason": "failed: no elimination vehicle named — the decision names neither a deterministic check nor an eval criterion.",
        }

    # 5. Consistent routing. A decidable class must carry a check vehicle;
    #    a behavioral class must carry an eval vehicle.
    if decidable and not check:
        return {
            "pass": False,
            "score": 0.0,
            "reason": "failed class-to-vehicle consistency: a decidable property was named without a deterministic check vehicle.",
        }
    if behavioral and not ev:
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
