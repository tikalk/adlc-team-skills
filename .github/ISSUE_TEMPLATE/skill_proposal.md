---
name: Skill proposal
about: Propose a new skill or a change to an existing skill's behavior
labels: enhancement
---

> New skills must be agreed in an issue before a PR (CONTRIBUTING). This
> template is that agreement.

**The problem:** What does the agent get wrong today — verbatim, from a real
session? (Per the writing-skills Iron Law: no skill without a failing
baseline. If you haven't watched an agent fail without it, say so — we'll
help you run the baseline first.)

**The baseline transcript:** Paste what the agent actually did without the
skill, including its rationalizations.

**Proposed skill:**

- **Name** (verb-first, hyphens): 
- **Trigger** ("Use when…" — conditions only, never a workflow summary): 
- **Type**: discipline / technique / pattern / reference
- **Why not an existing skill or a deterministic check?** (If it's
  enforceable with a test/lint, we'll want the check, not the prose.)

**Eval criterion sketch:** What pass/fail condition would prove the skill
works? (Every merged skill ships with a goldset criterion + binary grader.)

**Non-goals:** What should this skill explicitly NOT do?
