# Mode 2: Pick explicitly

The deterministic path — used when the user declines the heuristic, there
is no git remote, the tracker has no remote signal (Linear/Jira), the user
is switching trackers, or a headless run preselected `--provider`.

## Steps

1. Present the four providers (`github`, `gitlab`, `linear`, `jira`) and ask
   for a pick. Headless runs skip asking and use the `--provider` literal
   (already validated to the same four by the CLI).
2. If a `.adlc/issues-provider.yml` already exists (tracker switch): show
   the current `provider:` value, state that continuing rewrites the file,
   and require explicit "yes, switch" confirmation before proceeding.
3. Optionally collect field mappings for the chosen provider (project ID,
   team ID, project key) — all optional, all confirmed in the rendered file
   before writing. Skip freely; auto-detection covers the common case.
4. → §Commit step (SKILL.md).
