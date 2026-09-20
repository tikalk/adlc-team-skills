---
name: Bug report
about: Something broke — a skill misbehaves, the session start fails, CI is red
labels: bug
---

**What happened?** A short description of the broken behavior.

**Agent / harness:** [e.g., Claude Code 2.1, OpenCode, Codex]

**Skill(s) involved:** [e.g., team-boot, mission-brief, factory-mission]

**Reproduction:**

1. Scratch project: `mkdir /tmp/bug && cd /tmp/bug && git init`
2. Install: `npx adlc-cli skill add tikalk/adlc-team-skills -a <agent> -y`
3. …

**Expected vs actual:**

**Evidence (paste what you can):**

- `scripts/acceptance-test.sh` output (for session-start issues)
- `bash .agents/skills/team-boot/scripts/boot.sh` output from the project root
- The skill's output / `.adlc/` artifacts
- If a skill silently failed to trigger: say what you asked and what happened instead

**Did you regenerate the install artifacts?** (`.agents/skills/`, `.opencode/commands/` can go stale after an update — `npx adlc-cli skill add tikalk/adlc-team-skills -a <agent> -y`)
