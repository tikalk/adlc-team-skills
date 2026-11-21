import json
import re
import unicodedata

# EVAL-017: Tier-2 split and eval seed admissibility.
#
# The decision under test is a typed tier2-route record, not prose.
# Class-to-vehicle consistency, decided by decidability:
#   decidable property  -> deterministic check vehicle
#   behavioral property -> eval criterion vehicle
# Seed admissibility: a criterion is authored only from 2 reproduced
# occurrences in >=2 distinct runs; a comment-only seed never becomes a
# criterion and is handled as a Tier-3 preference instead.
#
# Prose outside the record is rationale and is not graded. Free-form
# text without a record fails closed. The tier-3 scenario gate below
# reads only context["vars"] (scenario + input_context), never the
# model output: a small clause splitter plus absence/presence
# vocabularies confined to that gate.

_FENCE = re.compile(
    r"```tier2-route[ \t]*\r?\n(.*?)\r?\n```",
    re.DOTALL | re.IGNORECASE,
)

_ROUTE_KEYS = ("class", "vehicle", "seed", "evidence", "runs")
_CLASSES = ("decidable", "behavioral")
_VEHICLES = ("check", "eval", "none")
_SEEDS = ("event-stream", "comment", "tier-3")

# Reproduction evidence: the failure it describes was reproduced by
# artifact, not asserted in prose. Prose channels ("reviewer comment",
# "testimony", "slack") are not artifacts and never count.
_EVIDENCE = frozenset({
    "failing test",
    "ci red",
    "diff",
    "screenshot",
    "revert",
    "recorded state transition",
    "state.json",
})


# A reproduced recurrence the decline must not excuse. Two vocabularies:
# strong artifact terms (the _EVIDENCE set) and weak recurrence wording
# ("two runs", "recurs", ...). Weak wording alone never proves
# reproduction for an artifact-backed claim, but for a behavioral
# recurrence two observed runs ARE the reproduction (cf. goldset
# CASE-2: no artifact difference, yet reproduced) — so weak wording
# counts unless the scenario explicitly denies reproduction.
# The check is intentionally narrow and reads only context["vars"]
# (scenario + input_context), never the model output: when the scenario
# unambiguously names reproduction, declining to Tier-3 is wrong.
# Anything else leaves the decline standing, because the grader grades
# the record, not the scenario prose.
_STRONG_REPRO = re.compile(
    r"failing test|ci red|\bdiff\b|screenshot|\brevert\b|"
    r"recorded state transition|state\.json",
    re.IGNORECASE,
)
_WEAK_REPRO = re.compile(
    r"\btwo runs\b|\bacross two runs\b|\btwice\b|\brecurs\b|\brecurrence\b|"
    r"\bsecond run\b|\brepeated\b",
    re.IGNORECASE,
)
# Explicit denial of reproduction — "no failing test", "unreproduced",
# "nothing backs it". A denied term is not a reproduction claim. The
# "no <term>" alternatives mirror _STRONG_REPRO one-for-one so a
# correct decline never fails on a denied artifact ("no diff backs it").
_ABSENCE = re.compile(
    r"unreproduced|never reproduced|not reproduced|no reproduction|"
    r"without reproduction|no evidence|without evidence|nothing backs|"
    r"not backed|without backing|no failing test|no ci red|no diff|"
    r"no screenshot|no revert|no recorded state transition|"
    r"no state\.json|"
    r"no test\b.{0,30}backs|\bsans\b.{0,30}"
    r"(evidence|reproduction|failing test)",
    re.IGNORECASE,
)
# A positive reproduction claim: a strong artifact term standing as
# the clause subject ("the diff shows", "two recorded state
# transitions", "state.json recorded") — not a bare list item after a
# denial ("no failing test, CI red, diff ... backs it", where the verb
# belongs to the denied list). Tested against the blanked remainder so
# denied spans cannot contribute the term.
_SUBJECT_TERM = re.compile(
    r"(the|a|an|two|2|recorded)\s+"
    r"(failing test|ci red|diff|screenshot|revert|"
    r"recorded state transition|state\.json)\b|"
    r"\bstate\.json\s+recorded\b|"
    r"\b(two|2)\s+recorded state transitions?\b",
    re.IGNORECASE,
)
# Sentence-boundary splitter: split on ";" and on "." only at a
# sentence end (followed by whitespace or end of string), so dotted
# terms like "state.json" survive intact. Contrastive conjunctions
# ("but", "however", ...) also start a new clause.
_CLAUSE_SPLIT = re.compile(
    r"[;]|\.(?=\s|$)|\bbut\b|\bhowever\b|\bthough\b|\balthough\b",
    re.IGNORECASE,
)


def _scenario_text(context):
    if not isinstance(context, dict):
        return None
    vars_ = context.get("vars")
    if not isinstance(vars_, dict):
        return None
    parts = []
    for key in ("scenario", "input_context", "instruction"):
        value = vars_.get(key)
        if isinstance(value, str) and value.strip():
            parts.append(value)
    if not parts:
        return None
    return "\n".join(parts)


def _clause_denied(clause: str) -> bool:
    return _ABSENCE.search(clause) is not None


def _looks_reproduced(scenario: str) -> bool:
    """True when the scenario unambiguously names a reproduction.

    Strong artifact terms count per-clause, with denial spans blanked
    first: in "no failing test and the diff shows it", the surviving
    "and the diff shows it" still carries its own verb and fires. But a
    denied list ("no failing test, CI red, diff ... backs it") leaves a
    remainder whose verb belongs to the denial, not a new claim — it
    does not fire. Weak recurrence wording ("recurs", "twice") is
    downgraded by a denial anywhere in the scenario, because it
    detaches so easily from its qualifier ("the comment came up twice
    but was never reproduced").
    """
    clauses = _CLAUSE_SPLIT.split(scenario)
    denied_anywhere = False
    for clause in clauses:
        if _clause_denied(clause):
            denied_anywhere = True
            # Blank out denied spans, then require a subject-position
            # term in the remainder: "and the diff shows it" survives
            # with "the diff"; ", CI red, diff ... backs it" leaves
            # only bare list items and does not fire.
            remainder = _ABSENCE.sub(" ", clause)
            if _SUBJECT_TERM.search(remainder):
                return True
            continue
        if _STRONG_REPRO.search(clause):
            return True
    if denied_anywhere:
        return False
    return any(_WEAK_REPRO.search(c) for c in clauses)


def _no_duplicate_keys(pairs):
    seen = {}
    for key, value in pairs:
        if key in seen:
            raise ValueError("duplicate key: %r" % (key,))
        seen[key] = value
    return seen


def _fail(reason):
    return {"pass": False, "score": 0.0, "reason": "failed " + reason}


def _check_seed(r, i, context=None):
    seed = r["seed"]
    if seed not in _SEEDS:
        return _fail(
            "seed admissibility: route %d has unknown seed %r "
            "(expected one of: %s)." % (i, seed, ", ".join(_SEEDS))
        )
    if seed == "tier-3":
        if r["vehicle"] != "none":
            return _fail(
                "route %d: a tier-3 seed must not name a vehicle — "
                "declining to author a criterion is the vehicle." % i
            )
        if not isinstance(r["evidence"], list) or r["evidence"]:
            return _fail(
                "route %d: a tier-3 decline carries no reproduction "
                "evidence and runs 0 — it declines the seed, it does not "
                "grade it." % i
            )
        if (
            isinstance(r["runs"], bool) or not isinstance(r["runs"], int)
            or r["runs"] != 0
        ):
            return _fail(
                "route %d: a tier-3 decline carries no reproduction "
                "evidence and runs 0 — it declines the seed, it does not "
                "grade it." % i
            )
        scenario = _scenario_text(context)
        if scenario is not None and _looks_reproduced(scenario):
            return _fail(
                "route %d declines a reproduced recurrence to Tier-3 — "
                "a tier-3 decline passes only for an inadmissible seed "
                "(an unreproduced comment); a reproduced recurrence "
                "must route to its check or eval vehicle." % i
            )
        return None
    if seed == "comment":
        if not r["evidence"]:
            return _fail(
                "seed admissibility: route %d comments on a comment-only "
                "seed and authors a criterion — an unreproduced comment "
                "never becomes a criterion; it stays a Tier-3 preference "
                "(or name the reproduction evidence and runs)." % i
            )
        # Comment seed reproduced by artifact falls through to the
        # reproduced checks below.
    evidence = r["evidence"]
    if not isinstance(evidence, list) or not evidence:
        return _fail(
            "seed admissibility: route %d names no reproduction evidence — "
            "a criterion is authored only from 2 reproduced occurrences "
            "in >=2 distinct runs." % i
        )
    bad = [
        item for item in evidence
        if not isinstance(item, str) or item.strip().lower() not in _EVIDENCE
    ]
    if bad:
        return _fail(
            "seed admissibility: route %d cites %r, which is not "
            "reproduction evidence (expected artifact terms: %s)."
            % (i, bad, ", ".join(sorted(_EVIDENCE)))
        )
    runs = r["runs"]
    if not isinstance(runs, int) or isinstance(runs, bool) or runs < 2:
        return _fail(
            "seed admissibility: route %d has %r runs — a criterion is "
            "authored only from 2 reproduced occurrences in >=2 distinct "
            "runs." % (i, runs)
        )
    return None


def _check_route(r, i, context=None):
    if not isinstance(r, dict) or set(r.keys()) != set(_ROUTE_KEYS):
        return _fail(
            "route %d must name exactly class/vehicle/seed/evidence/runs." % i
        )
    cls = r["class"]
    if cls not in _CLASSES:
        return _fail(
            "route %d has unknown class %r (expected one of: %s)."
            % (i, cls, ", ".join(_CLASSES))
        )
    vehicle = r["vehicle"]
    if vehicle not in _VEHICLES:
        return _fail(
            "route %d has unknown vehicle %r (expected one of: %s)."
            % (i, vehicle, ", ".join(_VEHICLES))
        )
    if vehicle == "none" and r["seed"] != "tier-3":
        return _fail(
            "route %d: an authored route must name a vehicle "
            "(check or eval)." % i
        )
    if cls == "decidable" and vehicle == "eval":
        return _fail(
            "class-to-vehicle consistency: a decidable property (decidable "
            "from the artifact alone) was routed to an llm-judged eval — "
            "decidable properties route to a deterministic check."
        )
    if cls == "behavioral" and vehicle == "check":
        return _fail(
            "class-to-vehicle consistency: a behavioral property (a "
            "distribution over model behavior) was routed to a "
            "deterministic check — behavioral properties route to an "
            "eval criterion via /evals-specify."
        )
    return _check_seed(r, i, context)


def get_assert(output: str, context: dict = None) -> dict:
    """Grader for EVAL-017: Tier-2 split and eval seed admissibility.

    The graded decision is the ````tier2-route` fenced record. Anything
    outside it is rationale and is not graded. Text without a record
    fails closed.

    A tier-3 decline is gated on the scenario: promptfoo passes the test
    vars as ``context`` (``context["vars"]["input_context"]`` etc.), and
    when the scenario names reproduction the decline fails — the
    recurrence must route to its check or eval vehicle. When no scenario
    context is available (unit probes calling ``get_assert(output)``),
    the decline stands on the record alone: vehicle none, empty
    evidence, runs 0.
    """
    text = unicodedata.normalize("NFKC", output)
    blocks = _FENCE.findall(text)
    if not blocks:
        return _fail(
            "no Tier-2 routing record — the decision must be a "
            "````tier2-route` block naming class, vehicle, seed, "
            "evidence, and runs; prose alone is not a decision."
        )
    if len(blocks) != 1:
        return _fail(
            "expected exactly one tier2-route record, found %d."
            % len(blocks)
        )
    try:
        record = json.loads(blocks[0], object_pairs_hook=_no_duplicate_keys)
    except (ValueError, json.JSONDecodeError) as exc:
        return _fail("the routing record is not valid JSON (%s)." % exc)
    if not isinstance(record, dict) or set(record.keys()) != {"tier", "routes"}:
        return _fail(
            "the routing record must name exactly tier and routes."
        )
    if record["tier"] != 2:
        return _fail(
            "this criterion grades tier 2 corrections; the record says "
            "tier %r." % (record["tier"],)
        )
    routes = record["routes"]
    if not isinstance(routes, list) or not routes:
        return _fail(
            "the routing record must carry at least one route."
        )
    for i, route in enumerate(routes):
        verdict = _check_route(route, i, context)
        if verdict is not None:
            return verdict
    return {
        "pass": True,
        "score": 1.0,
        "reason": "Tier-2 split consistent: class-to-vehicle routing "
        "follows decidability and the seed is admissible.",
    }
