## In a local session — you answer the gates

When `ADLC_RUN_ID` is not set, a person is in this session, and nothing else will answer a gate. The agentic-container runtime that relays gates to Slack exists only in a runner pod.

1. **A paused run is your turn, not the end of the mission.** When `adlc-cli workflow run` or `resume` exits with the run paused at a gate (`run_paused`, `status: paused` in `adlc-cli workflow state show <run_id>`), ask the person the gate's question and options. Then run `adlc-cli workflow resume <run_id> --input <verdict_input>=<answer>` and keep going. Never end your turn on a paused run that nobody was asked about.
2. **Every gate that approves MRs is followed by a step that opens them.** A `gate` whose message promises MRs/PRs is followed by a `publish` step: `run-branch.sh` and `open-mr.sh` for each repository the change touches, writing `mr_url` (`mr_urls` for more than one). Only then comes the write-back step, so the completion comment links real MRs. A gate with nothing after it to act on its answer is a plan defect; fix the plan before you start the run.
3. Before ending your turn, the run is `completed`, `failed` or aborted, or it is paused at a gate the person has been asked about.
