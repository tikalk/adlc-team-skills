# Run context for factory orchestrators (shared)

## In a factory run (`ADLC_RUN_ID` set)

The workflow engine runs the step unattended and a gate follows it.

- **Never ask for approval** or wait for an answer. The engine's gate after
  the step is the approval; a question here ends the step with nothing published.
- **Before returning, always** write a one-line `conclusion` (plus `mr_url`
  when a draft MR/PR was opened or reused) into `ADLC_STEP_OUTPUT` — one flat
  JSON object of string values; keep any keys already in the file. Do this
  whatever the outcome, even when nothing changed.
- `run-branch.sh` and `open-mr.sh` act only with `ADLC_RUN_ID`; without it
  they are no-ops. `commit-step.sh` additionally acts with
  `adlc.commit_steps: true` in `.adlc/init-options.json` or `--commit`.
- A helper's non-zero exit (refused path, missing committer identity, tracker
  scope) stops the run — report it, do not work around it.

## In a local session (no `ADLC_RUN_ID`)

Writes stay on disk, uncommitted, unless the user opted in (same flags).
`run-branch.sh` and `open-mr.sh` never act without `ADLC_RUN_ID`: an
interactive opt-in only commits on the current branch.
