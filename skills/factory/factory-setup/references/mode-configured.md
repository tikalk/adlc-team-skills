# Mode 3: Already configured

Verification path — reached when `.adlc/issues-provider.yml` exists, or when
the user only wants a wiring check. The only write this mode ever performs
is confirm-gated label creation (step 4); everything else is read-only.

## Steps

1. Read `.adlc/issues-provider.yml` and report:
   - the active `provider:` value (or state that none is set — file is a
     commented template, route to Mode 2);
   - any field mappings and `labels:` overrides present (overrides change the
     effective names checked in step 3);
   - whether the provider matches the repo's git remote (advisory only —
     a mismatch is reported, never "fixed" silently).
2. Confirm credentials resolve for that provider (env vars present:
   `GITHUB_TOKEN`/`GH_TOKEN`, `GITLAB_TOKEN`, `LINEAR_API_KEY`,
   `JIRA_URL`+`JIRA_EMAIL`+`JIRA_API_TOKEN`) — presence only, values never
   printed.
3. Verify the factory label vocabulary (GitHub/GitLab only — read-only):
   resolve effective names through the `labels:` mapping (unmapped =
   canonical), list repo labels (`gh label list` / `glab label list`), and
   report any required names missing, each with its exact create command.
   Also report every lifecycle label whose description is empty. The
   expected descriptions are:

   | Label | Description |
   |--|--|
   | `intent` | Lifecycle: intent — awaiting Intent Gate approval |
   | `spec-gated` | Lifecycle: spec-gated — approved for factory execution |
   | `executing` | Lifecycle: executing — a factory mission is running |
   | `parked` | Lifecycle: parked — a supervised run waits at a gate; add `resume` to continue |
   | `validation` | Lifecycle: validation — MR/PR open for review |
   | `done` | Lifecycle: done — merged (terminal) |
   | `cancelled` | Lifecycle: cancelled — closed without a merge (terminal) |

   Report a label that still carries the retired `factory-stage` prefix as stray, and remove it only on explicit confirmation from the human (`gh label delete` / `glab label delete`). Never remove it in a headless run.
   Jira/Linear: state the native-state expectation from tracker-integration
   §9, no check.
4. Provisioning offer (interactive runs only — never headless): if labels are
   missing, offer "create the N missing labels?" and proceed only on explicit
   confirmation. Create via provider CLI (`gh label create` / `glab label
   create`, neutral color; a lifecycle label gets its description from the
   table in step 3, any other label `factory lane label`). In the same
   confirmed step, fill empty lifecycle descriptions (`gh label edit
   --description` / `glab label edit --description`). Then re-list to
   confirm and report. On decline, or in headless runs, stop at the report —
   the human creates them.
5. Lifecycle backfill (interactive runs only — never headless). When the
   factory-tickets lifecycle lint reports violations, take its `--json` plan
   and run `scripts/bash/lifecycle-backfill.sh --plan <file> --provider <p> --project <path>`
   (PowerShell: `scripts/powershell/lifecycle-backfill.ps1`). With no flag it
   prints the dry-run table (issue, current labels, proposed label) and makes
   no tracker call. Show the table to the human.
   Run `lifecycle-backfill --apply` only after the human confirms that exact table.
   Each row then gets one Set Lifecycle call: the proposed label is added and
   every other lifecycle label is removed in the same call, and the labels
   are re-read to verify. Rows proposed as `-` are skipped for a human
   decision. Re-run the lint afterwards and report its summary line.
6. Report "wired" (provider + credential presence + labels present) or the
   specific gap and the fix.
