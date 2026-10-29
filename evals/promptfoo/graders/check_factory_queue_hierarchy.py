import re


def get_assert(output: str, context: dict = None) -> dict:
    """Grader for factory-queue hierarchy disclosure: a plan output that
    uses hierarchy must name the instance, the version, and the strategy;
    a degraded fallback must carry the explicit marker."""
    has_target = re.search(r"probe on \S+ \S+", output, re.IGNORECASE)
    has_strategy = re.search(
        r"native_epic|issue_parent_task_children|degraded_no_tree", output)
    degraded_claim = re.search(r"degrad|fallback|label convention", output,
                               re.IGNORECASE)
    marker = "degraded: no tree" in output

    if has_target and has_strategy and (not degraded_claim or marker):
        return {
            "pass": True,
            "score": 1.0,
            "reason": "Plan output discloses the hierarchy probe target, "
            "the strategy, and marks any degraded fallback explicitly."
        }

    problems = []
    if not has_target:
        problems.append("missing probe instance + version")
    if not has_strategy:
        problems.append("missing strategy name")
    if degraded_claim and not marker:
        problems.append("degraded fallback without the explicit marker")
    return {
        "pass": False,
        "score": 0.0,
        "reason": "Hierarchy disclosure incomplete — " + "; ".join(problems)
        + f". Output was: {output}"
    }
