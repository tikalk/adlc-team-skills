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
   Jira/Linear: state the native-state expectation from tracker-integration
   §9, no check.
4. Provisioning offer (interactive runs only — never headless): if labels are
   missing, offer "create the N missing labels?" and proceed only on explicit
   confirmation. Create via provider CLI (`gh label create` / `glab label
   create`, neutral color, `factory lane label` description), then re-list to
   confirm and report. On decline, or in headless runs, stop at the report —
   the human creates them.
5. Report "wired" (provider + credential presence + labels present) or the
   specific gap and the fix.
