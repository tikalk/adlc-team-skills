import re

# Tier 1: concrete structural OPERATION + route in the SAME clause.
# Both searches are sentence-scoped: the operation and the
# /architect-specify|ADR mention must co-occur within one sentence
# ([^.!?;] spans), so a route attached to another issue cannot qualify.
# A bare type name does NOT qualify, and neither does an operation on
# unrelated text (docs, references).
_STRUCT_OP = (
    r"((replac\w+|remov\w+|eliminat\w+|introduc\w+|convert\w+|"
    r"migrat\w+|restrict\w+|narrow\w+|split\w+)"
    r"(?![^.!?;]{0,40}?\b(documentation|discussion|explanation|"
    r"reference from the documentation|comment))\s+"
    r"(the |a |an |this |that |its |their )"
    r"[^.!?;]{0,40}?"
    r"(sum type|union type|newtype|opaque type|nullable|"
    r"invalid state|unrepresentable|variant)|"
    r"make[^.!?;]{0,40}?invalid state[^.!?;]{0,40}?unrepresentable)"
)
_ROUTE_T1 = r"(/architect-specify|\bADR\b)"

# Distancing markers: the route/ADR mention is explicitly about something else.
_DISTANCING = re.compile(
    r"\b(separately|another issue|unrelated|other issue|"
    r"different issue|possible route|just mention|merely mention)\b",
    re.IGNORECASE,
)
# Routing verb near the route token: proves the route applies to this change.
_ROUTE_VERB = re.compile(r"\b(rout\w+|capture|record\w*)\b", re.IGNORECASE)
# Bare "grader" alone is excluded — only "binary grader" counts.
_VEHICLE = (
    r"(REVIEW\.md pass|CI (?:job|check|workflow)|lint(?:er| rule)|"
    r"unit test|pytest|pre-?commit(?: hook)?|binary grader|"
    r"deterministic check|action P|/evals-specify)"
)
_ACTION = r"(add|creat\w+|implement|introduc\w+|enforce|requir\w+|mandate|block|rout\w+|wir\w+|land|ship|use)"
# Hedge/secondary markers: the vehicle is mentioned, not enacted.
_HEDGE = re.compile(
    r"\b(could|might|consider|maybe|possibly|later|secondary|"
    r"evidence|mention|remember|potential|optionally|usually)\b",
    re.IGNORECASE,
)
# Verb governs vehicle: "add <vehicle>", no sentence break, no hedge between.
# Vehicle framed as enforcing: "<vehicle> ... failing/blocks ...".
# Both use the same named group "gap" for the intervening text so the
# hedge filter always reads the gap — never a verb capture group.
_LINK_VERB_VEHICLE = re.compile(
    _ACTION + r"(?P<gap>[^.!?;]{0,50}?)" + _VEHICLE, re.IGNORECASE
)
_LINK_VEHICLE_FAILS = re.compile(
    _VEHICLE + r"(?P<gap>[^.!?;]{0,60}?)" + r"(?:fail\w*|block\w*)",
    re.IGNORECASE,
)

# Prose CDR declared primary: broad phrasing, either order.
_PROSE_PRIMARY = re.compile(
    r"(\bprimary\b.{0,60}\b(CDR|context rule)\b|"
    r"\b(CDR|context rule|prose CDR)\b.{0,60}"
    r"\b(primary|principal|main mechanism|remains|instead of|rather than|"
    r"remember|enforce)\b)",
    re.IGNORECASE,
)


def _tier1(output: str) -> bool:
    op = re.compile(_STRUCT_OP, re.IGNORECASE)
    route = re.compile(_ROUTE_T1, re.IGNORECASE)
    for sent in re.split(r"[.!?]", output):
        # Semicolon clauses: a distancing marker detaches the route —
        # check each semicolon segment on its own.
        segs = re.split(r";", sent) if ";" in sent else [sent]
        for seg in segs:
            if op.search(seg) and route.search(seg) and not _DISTANCING.search(seg):
                return True
        # Full sentence still qualifies when its route clause is attached:
        # operation and route co-occur, no distancing marker sits between
        # them, and a routing verb governs the route token.
        m_op, m_route = op.search(sent), route.search(sent)
        if m_op and m_route and not _DISTANCING.search(
            sent[min(m_op.start(), m_route.start()):max(m_op.end(), m_route.end())]
        ):
            span = sent[min(m_op.start(), m_route.start()):max(m_op.end(), m_route.end())]
            if _ROUTE_VERB.search(span):
                return True
    return False


def _tier2(output: str) -> bool:
    for pat in (_LINK_VERB_VEHICLE, _LINK_VEHICLE_FAILS):
        for m in pat.finditer(output):
            if not _HEDGE.search(m.group("gap")):
                return True
    return False


def get_assert(output: str, context: dict = None) -> dict:
    """Grader for EVAL-016: correction-elimination ladder primary-route check.

    Scope: recurring MECHANICALLY CHECKABLE mistakes. Genuine Tier 3
    judgment-only cases are outside this criterion's scope.
    Pass requires the primary correction route to be a concrete vehicle:
      - Tier 1: concrete structural operation (e.g. replace a nullable
        field with a sum type, make an invalid state unrepresentable) +
        /architect-specify/ADR route. Naming the route alone fails, as
        does naming a type with no operation.
      - Tier 2: named enforcement vehicle governed by an action verb
        (added/enforced/blocking — not hedged, secondary, or merely
        descriptive). A thin CDR pointer beside the vehicle is fine.
    A prose CDR declared primary fails even if a vehicle is mentioned
    secondarily. Vague language with no concrete vehicle fails.
    """
    prose_primary = bool(_PROSE_PRIMARY.search(output))
    tier1 = _tier1(output)
    tier2 = _tier2(output)

    if prose_primary:
        return {
            "pass": False,
            "score": 0.0,
            "reason": "Correction-elimination ladder routing failed: "
                      "prose CDR is the primary correction action — "
                      "the elimination vehicle must be primary.",
        }
    if tier1 or tier2:
        tier = "Tier 1 structural" if tier1 else "Tier 2 mechanical"
        return {
            "pass": True,
            "score": 1.0,
            "reason": f"Recurring mistake routed to a concrete {tier} "
                      "elimination vehicle as the primary correction.",
        }
    return {
        "pass": False,
        "score": 0.0,
        "reason": "Correction-elimination ladder routing failed: "
                  "no concrete elimination vehicle as the primary action "
                  "(named type/schema change, REVIEW.md pass, CI job, "
                  "lint rule, unit test, pre-commit hook, or binary grader).",
    }
