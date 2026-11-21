# Run context for factory orchestrators (shared)

## In a factory run (`ADLC_RUN_ID` set, or the lane's `WORKFLOW_INPUTS` carries a `run_id`)

Two kinds of factory run exist. A **workflow run** (supervised missions): the
workflow engine runs the step unattended, exports `ADLC_RUN_ID`,
`ADLC_ISSUE_REF` and `ADLC_STEP_OUTPUT`, and a gate follows it. A **raw lane
run** (reviews, autonomous missions): the Argo lane starts the agent directly,
adlc-cli never runs, and the run id travels only in `WORKFLOW_INPUTS`
(`{"issue_ref", "run_id", "dispatch"}`, set on every runner pod). Resolve both
the same way: `bash scripts/bash/run-context.sh` (PowerShell twin
`scripts/powershell/run-context.ps1`) prints `factory_run=yes` plus the
`run_id` and `issue_ref` to use, and the helpers below adopt it on their own.
A raw lane run has no `ADLC_STEP_OUTPUT` and no gate: nobody answers a
question, and the tracker comments are the only output anyone reads. In a
review, `WORKFLOW_INPUTS.issue_ref` is the MR ref (`<group>/<project>!<iid>`):
it is not an issue ref, so `issue_ref` prints empty.

**In a review run the publish helpers are no-ops.** A review has a lane run id
and no issue, and nothing to publish: `run-branch.sh` and `open-mr.sh` print
"review run … skipped" and change nothing, and `commit-step.sh` prints
`sha: none` unless `--commit` (or the `commit_steps` opt-in) asks for the
commit. The run id is still the one to use in markers.

- **Never ask for approval** or wait for an answer. The engine's gate after
  the step is the approval; a question here ends the step with nothing published.
- **Before returning, always** write a one-line `conclusion` (plus `mr_url`
  when a draft MR/PR was opened or reused) into `ADLC_STEP_OUTPUT` (when it is
  set) — one flat JSON object of string values; keep any keys already in the
  file. Do this whatever the outcome, even when nothing changed.
- **`<run_id>` in every marker and note is the resolved run id** —
  `ADLC_RUN_ID`, else the `run_id` that `run-context.sh` prints. Never set
  `ADLC_RUN_ID` by hand and never make one up (`local`, `mr-<iid>`,
  `mission-<iid>-manual`): an invented run id breaks every marker that names
  the run.
- `run-branch.sh` and `open-mr.sh` act only with a run context
  (`ADLC_RUN_ID`, or the lane's `WORKFLOW_INPUTS.run_id` adopted through
  `run-context.sh`); without one they are no-ops. Never open an MR without
  `open-mr.sh`. `commit-step.sh` additionally acts with
  `adlc.commit_steps: true` in `.adlc/init-options.json` or `--commit`.
- A helper's non-zero exit (refused path, missing committer identity, tracker
  scope) stops the run — report it, do not work around it.

## In a local session (`run-context.sh` prints `factory_run=no`)

Writes stay on disk, uncommitted, unless the user opted in (same flags).
`run-branch.sh` and `open-mr.sh` never act without a run context: an
interactive opt-in only commits on the current branch.
