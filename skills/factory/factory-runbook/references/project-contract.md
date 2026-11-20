# The project contract — what a consumer project may change in a factory run

A factory run reads several files from the **consumer project** (the repository
the factory works on). This page says what each may and may not do, so a
project can tune the factory without breaking it. The rule behind every row:
**a project may add checks and prohibitions; it may never cancel a step the
factory must do** (post the review verdict, move the lifecycle label, leave the
completion note, open the MR through `open-mr.sh`).

| Project file | What the factory uses it for | May | May not |
|---|---|---|---|
| `REVIEW.md` (repo root) | the review passes, severity weights, skip lists (`factory-review` §1) | point a pass at a project review skill; map that skill's severities to Important / Nit; add checks | change how or whether the verdict is posted; change the verdict marker (`<!-- factory-review:… head=<sha> … -->`, read back by `check-verdict-head.sh`) |
| project review skill named by `REVIEW.md` | checks and severities | add evidence (screenshots, runtime tests) to the verdict | make the verdict a draft, wait for a user, post its own comment instead of the verdict, edit the MR description |
| `AGENTS.md` / `CLAUDE.md` | coding rules for the mission | require tests, file lists, conventions; forbid actions | ask the agent to wait for a person or to skip a factory step |
| issue `## Definition of Done` / Mission Brief | what "done" means for this issue | list concrete, checkable items | — (an item that cannot run in a pod is reported as skipped with the reason, never as "pending") |
| `.adlc/issues-provider.yml` | tracker provider and label names | set `provider:`; map label names (then the lane sensors must use the same names) | leave the provider unset |
| `.adlc/workspace.yml` | which skills (and which commit) the pod installs | pin `adlc-team-skills` to a released commit; add skill sources | install factory skills unpinned in production lanes |
| `.adlc/workflows/factory/workflow.yml` (override) | replaces adlc-cli's bundled `factory` workflow | add `shell` steps that call the factory-runbook scripts; add gates and proof-of-work checks | call skills or helper paths that do not exist at the pinned commit (check them in CI); drop the steps that open the MR or record completion |

**Interactive wording in project files.** Project skills are often written for a
person at a keyboard ("propose comments; post when the user says so"). In a
factory run nobody answers, so such wording is ignored by the factory skills
(`factory-review` "In a factory run — these rules win"; `factory-mission`
"Project instructions in a factory run"; tracker-integration Safety
Constraint 1). Project authors should still mark the split explicitly with a
short "Factory mode" section, so a human reader sees it too.
