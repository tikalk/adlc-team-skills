---
name: writing-skills
description: Use when creating a new skill, editing an existing skill, or verifying skills work before deployment
---

# Writing Skills

## Overview

**Writing skills IS Test-Driven Development applied to process documentation.**

A skill is behavior-shaping code, not prose. You write a failing test (a
pressure scenario an agent gets wrong without the skill), watch it fail,
write the minimal skill that fixes it, watch it pass, then close loopholes.

**Core principle:** if you didn't watch an agent fail without the skill, you
don't know whether the skill teaches the right thing — or anything at all.

**The Iron Law:**

```
NO SKILL WITHOUT A FAILING BASELINE FIRST
```

This applies to new skills AND to edits of existing skills. "Simple
addition", "just a section", "docs update" — all the same violation.
Write the skill before testing it? Delete it and start over.

## When to Use

- Creating a new skill for this repo (also read CONTRIBUTING.md — new
  skills must be agreed in an issue first and ship with eval coverage)
- Editing any `skills/**/SKILL.md` content
- Reviewing a PR that changes skill content

**When NOT to use:** for project-specific conventions (those go in the
team-ai-directives repo as CDRs), or for mechanical constraints a script
or test can enforce — automate those, save documentation for judgment
calls.

## Core Process

### RED — Baseline the failure

Run the scenario WITHOUT the skill loaded. Document verbatim:

- What the agent actually did
- The exact rationalizations it used to skip the correct behavior
- Which pressures triggered the failure (time, sunk cost, authority, "it
  works either way")

If the agent already behaves correctly without the skill, **stop — there
is nothing to fix.** A skill that enforces behavior that comes for free is
context noise (this repo exists to fight context noise, not add to it).

### GREEN — Write the minimal skill

Start from the template (`templates/SKILL-template.md` in this directory).
Address only the failures you observed in RED — not hypothetical ones.

Run the same scenario WITH the skill. The agent should now comply.

### REFACTOR — Close the loopholes

New rationalization found? Add an explicit counter, re-test. Loop until
bulletproof under pressure.

### Micro-test wording before full scenarios

Full pressure runs are slow. Verify wording cheaply first: one fresh
API/subagent call per sample, 5+ reps per variant, always including a
no-guidance control. If the control doesn't exhibit the failure, there is
nothing to fix. Read every flagged match manually — automated counts
overstate both failure and success.

## Structure Rules (this repo)

| Rule | Why |
|------|-----|
| Exactly 2 levels deep: `skills/<domain>/<skill>/SKILL.md` | Enforced by `test_skill_directory_depth`; resolves the `skills` CLI depth limit |
| Frontmatter: `name` + `description` required (≤1024 chars total) | Enforced by `test_skill_description_presence_and_length` |
| Optional `scripts:` (`sh:`/`ps:`) and `disable-model-invocation: true` | Mark skills that must not be model-invoked |
| Description = trigger only | See below — the single most common way skills silently break |
| Headings: `Overview` → `When to Use` → `Core Process` → `Red Flags` → `Verification` | Canonical shape; `Configuration` only if the skill has knobs |
| Token budget: aim <500 lines for the SKILL.md body (enforced: warn >500, fail >800 — see test_skill_token_budget) | Heavy reference → `references/`; scripts → `scripts/{bash,powershell}/` |
| New skills ship with eval coverage | Goldset criterion + binary grader (`{"pass": bool, "score": 1.0\|0.0}`) — see `evals/promptfoo/` |

## Skill Discovery Optimization (SDO)

The `description` is the trigger surface: `mission-brief` hands every
skill's name+description to its subagents, and the model decides what to
load from that list.

**Description = when to use. NEVER what the skill does.**

Measured failure mode (see superpowers' writing-skills, which this skill
adapts): when a description summarizes the workflow, agents follow the
*description* instead of reading the skill body — a description saying
"code review between tasks" produced one review where the skill's
flowchart clearly required two.

```yaml
# BAD: workflow summary — agents will follow this shortcut
description: Bootstraps the session by injecting the team context index and pulls rules on demand

# GOOD: trigger only
description: Use when a session starts and the team AI directives context is not yet loaded
```

- Start with "Use when…" and name concrete symptoms and situations
- Third person (it is injected into prompts)
- Keywords an agent would search for: error messages, symptoms, tool names
- Skills with `disable-model-invocation: true` are exempt (not routed by
  the model) but must still not mislead

## Match the Form to the Failure

Before writing guidance, classify the baseline failure. The form that
bulletproofs one failure type backfires on another.

| Baseline failure | Right form | Wrong form |
|---|---|---|
| Skips a rule under pressure (knows better, does it anyway) | Prohibition + rationalization table + red flags | Soft guidance ("prefer…", "consider…") |
| Output has the wrong shape (bloated, buried verdict) | Positive recipe: state what the output IS, its parts in order | Prohibition list ("don't restate", "never narrate") |
| Omits a required element | Structural: a REQUIRED slot in the template | Prose reminders near the template |
| Behavior depends on a condition | Conditional on an observable predicate | Unconditional rule + exemption clauses |

No nuance clauses either way: "don't X unless it matters" reopens
negotiation; a single nuance clause on a winning recipe degrades it.

## Bulletproofing Discipline Skills

For rule-enforcing skills, close every loophole explicitly: forbid the
specific workarounds ("don't keep it as reference — delete means delete"),
add the foundational principle early ("violating the letter of the rules
is violating the spirit"), build the rationalization table from your RED
transcript, and list Red Flags the agent can self-check against.

## Red Flags

- Skill written before the baseline run — delete and start over
- Description summarizes what the skill does instead of when to use it
- "The agent will obviously do the right thing" — that's what RED is for
- Skill grew past ~500 lines and everything is inline instead of `references/`
- New skill shipped without its eval criterion + grader
- Hypothetical failure modes addressed but observed ones missing

**All of these mean: stop, re-run the baseline, fix the skill.**

## Verification

A skill change is done when ALL of these are true:

- [ ] Baseline scenario run WITHOUT the skill; verbatim failures recorded
- [ ] Same scenario passes WITH the skill
- [ ] `pytest tests/unit/test_playbook_integrity.py -q` green (depth,
      frontmatter, description rules)
- [ ] Eval criterion + binary grader added, and the grader has a unit
      test (`evals/promptfoo/tests/`)
- [ ] Regenerated install artifacts are in sync:
      `pytest tests/unit/test_generated_artifacts_sync.py -q`
- [ ] Manual acceptance check in a real agent (CONTRIBUTING "Manual
      testing") — skill triggers when it should, stays silent when it
      shouldn't

## References

- `templates/SKILL-template.md` — starting point for a new skill
- `references/skill-testing.md` — pressure scenarios, pressure types,
  micro-testing methodology
- `CONTRIBUTING.md` — PR process, eval coverage requirement, manual test
  protocol
