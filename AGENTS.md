<!-- TEAM_AI_DIRECTIVES START -->
## Team Directives & Constitution

This project is bound by the team AI directives repository at `/home/lior/dev/agentic-sdlc/agentic-sdlc-team-ai-directives`.
- **Strict Compliance**: You MUST invoke the `team-boot` skill BEFORE responding to any task or question. This is not optional and applies to every interaction. If a skill applies, you MUST invoke it immediately.
- **First-Tool-Call Gate**: Your FIRST tool call in any session MUST be `skill({name: "team-boot"})`. If your first tool call is `read`, `grep`, `glob`, `bash`, or any other tool, you have VIOLATED this directive -- stop and invoke `team-boot` before continuing. Mechanically verifiable in any trace.
- **Plan-Mode Compatibility**: Loading a skill is read-only -- it injects instructions, it does NOT modify files. Plan mode / read-only phase NEVER forbids the `skill` tool. Do not fabricate a conflict between plan mode and the skill check.
- **Anti-Patterns** (do NOT rationalize skipping the skill check):
  - "Let me explore the codebase first" -> Skills tell you HOW to explore. Check first.
  - "This is a plain message, not a spec command" -> Skill check applies to EVERY interaction.
  - "I'll check after understanding the request" -> Check BEFORE understanding -- skills guide your questions.
  - "This is too simple" -> Simple things become complex. Check first.
  - "Plan mode forbids modifications" -> The `skill` tool is read-only; plan mode never forbids it.
  - "I need to be efficient / focus on the task" -> The check IS the first step, not overhead to optimize away.
  - "The task matters more than the check" -> The check IS part of the task; skipping it is a violation.
- **Team Constitution**: Read and strictly adhere to the principles in `/home/lior/dev/agentic-sdlc/agentic-sdlc-team-ai-directives/context_modules/constitution.md`. When creating or updating the project's constitution, you MUST inherit and align with these principles.
- **Rules, Personas & Examples**: Use the `team-discover` skill to find and load relevant rules, personas, or examples before making changes.
- **Tech Radar Guidance**: Use the `tech-radar-context` skill whenever evaluating or choosing technologies, frameworks, databases, libraries, or cloud infrastructure.
<!-- TEAM_AI_DIRECTIVES END -->


