import re

# Relations accepted in both unicode and ASCII arrow forms.
_ARROW = r"(?:↔|<->)"

RELATIONS = [
    ("PDR↔ADR", "PDR", "ADR"),
    ("PDR↔code", "PDR", "code"),
    ("ADR↔code", "ADR", "code"),
    ("ChDR↔code", "ChDR", "code"),
]

_LAYER_TAG = r"\[layer:\s*(?:product|architecture|change|cross)\]"
_RECORD_ID = r"(?:PDR|ADR|ChDR)-\d+"
# A path citation must start with a known code/doc root — bare slash phrases
# like "product/architecture teams" are not citations.
_PATH = r"(?:\.[\w.-]+|src|lib|app|apps|pkg|cmd|internal|test|tests|doc|docs|scripts|skills|spec|specs|evals|templates)/"
# A filename citation needs a 2-4 letter extension — "e.g." or "v1.2" don't count.
_FILENAME = r"\b\w+\.[a-zA-Z]{2,4}\b"


def _relation_body(output: str, left: str, right: str) -> str:
    """Extract the section body of a relation heading (to the next ##/### heading)."""
    m = re.search(
        rf"^###?\s*{left}\s*{_ARROW}\s*{right}\b[^\n]*\n(.*?)(?=^#{{2,3}}\s|\Z)",
        output,
        re.MULTILINE | re.DOTALL | re.IGNORECASE,
    )
    return m.group(1) if m else ""


def get_assert(output: str, context: dict = None) -> dict:
    """Grader for PDR-072: factory-init coverage matrix format integrity.

    Asserts the sweep output contains:
      - a Pivot section whose table header has Area, PDR, ADR, and ChDR columns
      - the four traceability relation sections (PDR↔ADR, PDR↔code, ADR↔code,
        ChDR↔code) — unicode ↔ or ASCII <-> accepted
      - a 'Coverage: N%' line inside every relation section
      - gap lines that each carry a [layer: ...] tag AND a citation
        (record ID or file path) — no fabricated, unprovenanced cells
      - a Drift section (or Baseline on first sweep)
    """
    reasons = []

    # 1. Pivot heading + table header columns
    if not re.search(r"^#{2,3}\s.*Pivot\b", output, re.MULTILINE | re.IGNORECASE):
        reasons.append("missing Pivot section heading")
    else:
        header_line = next(
            (ln for ln in output.splitlines()
             if ln.strip().startswith("|") and "area" in ln.lower()),
            "",
        )
        if not header_line:
            reasons.append("pivot table header row not found")
        else:
            for col in ("area", "pdr", "adr", "chdr"):
                if col not in header_line.lower():
                    reasons.append(f"pivot header missing column: {col}")

    # 2-3. Four relations, each with a Coverage percentage
    for name, left, right in RELATIONS:
        heading = re.search(
            rf"^###?\s*{left}\s*{_ARROW}\s*{right}\b",
            output,
            re.MULTILINE | re.IGNORECASE,
        )
        if not heading:
            reasons.append(f"missing relation section: {name}")
            continue
        body = _relation_body(output, left, right)
        if not re.search(r"Coverage:\s*\d{1,3}\s*%", body, re.IGNORECASE):
            reasons.append(f"relation {name} has no 'Coverage: N%' line")

    # 4. Every gap line must carry a layer tag and a citation
    for line in output.splitlines():
        if re.match(r"\s*-\s*[Gg]ap\b", line):
            if not re.search(_LAYER_TAG, line, re.IGNORECASE):
                reasons.append(f"gap line missing [layer:] tag: {line.strip()[:60]}")
            if not re.search(_RECORD_ID, line, re.IGNORECASE) \
                    and not re.search(_PATH, line) \
                    and not re.search(_FILENAME, line):
                reasons.append(f"gap line missing record/path citation: {line.strip()[:60]}")

    # 5. Drift or Baseline section
    if not re.search(r"^#{2,3}\s.*\b(?:Drift|Baseline)\b", output,
                     re.MULTILINE | re.IGNORECASE):
        reasons.append("no Drift (or Baseline on first sweep) section")

    if reasons:
        return {
            "pass": False,
            "score": 0.0,
            "reason": "Coverage matrix check failed: " + "; ".join(reasons),
        }

    return {
        "pass": True,
        "score": 1.0,
        "reason": "Matrix has pivot with all layer columns, four relations with coverage "
                  "percentages, layer-tagged and cited gaps, and a Drift/Baseline section.",
    }
