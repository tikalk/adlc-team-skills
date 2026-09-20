# Testing Skills

How to actually run the RED-GREEN-REFACTOR cycle from
`../SKILL.md`. The methodology adapts subagent-based pressure testing
(pioneered by superpowers' writing-skills) to this repo's eval culture.

## Pressure Scenarios

A pressure scenario is a realistic task plus a pressure that tempts the
agent to skip the correct behavior. Run each scenario in a FRESH session
(or subagent) — contaminated context hides failures.

**Pressure types:**

| Pressure | Prompt flavor |
|---|---|
| Time | "this is urgent, skip the ceremony" |
| Sunk cost | "we already wrote the code, just add the skill" |
| Authority | "the tech lead said just do it" |
| Exhaustion | late in a long multi-task session |
| Ambiguity | underspecified request inviting invention |

For discipline skills (rules/requirements), combine 3+ pressures in one
scenario — single-pressure tests pass trivially.

## Baseline (RED) Protocol

1. Write the scenario BEFORE reading any existing skill that covers the
   area (avoid anchoring).
2. Run it WITHOUT the skill loaded. Save the transcript.
3. Record verbatim: what the agent did, the exact rationalization wording,
   which pressures flipped it.
4. If the agent complies without the skill — stop. No skill needed. File
   the finding instead.

## Verification (GREEN) Protocol

1. Run the SAME scenario with the skill loaded.
2. The agent must comply under the same pressures that broke the baseline.
3. Compliance in a calm scenario proves nothing — re-add the pressures.

## Micro-Testing Wording

Full scenarios are slow (minutes each). Before running them, verify the
wording itself:

- One fresh-context sample per call — a raw API call or a single-shot
  subagent. System prompt = the realistic context the guidance will live
  in (the full skill, not the guidance in isolation).
- **Always include a no-guidance control.** If the control doesn't
  exhibit the failure, there is nothing to fix — stop.
- 5+ reps per variant. Single samples lie.
- Read every flagged match manually. Template echoes and quoted
  counter-examples masquerade as hits; automated counts alone overstate
  both failure and success.
- Variance is a metric: five different interpretations across five reps
  means the wording isn't binding — tighten the form before adding words.

## From Scenario to Eval Criterion

A pressure scenario that the baseline failed and the skill fixes becomes a
permanent eval criterion (CONTRIBUTING requires this for new skills):

1. Write it as a goldset criterion (see `evals/promptfoo/goldset.md`
   format: frontmatter, pass/fail conditions, example).
2. Implement the binary grader: plain assertions where code can check
  (`{"pass": bool, "score": 1.0|0.0, "reason": ...}`) — never Likert.
   LLM judges only for what static checks can't verify.
3. Unit-test the grader against goldset examples
   (`evals/promptfoo/tests/test_check_*.py`).
4. Wire the scenario in `evals/promptfoo/config.js`.

This is how a hard-won pressure test stops being a one-time check and
becomes a regression guard.
