---
name: factory-review
description: Quality & Compliance Review Engine (The Great Filter). Performs automated, severity-ranked PR compliance reviews against REVIEW.md policy-as-code and babysits agent PRs to merge.
---

# factory-review

## What this skill does

`factory-review` is the PR-review compliance engine of the software factory (deck slide 12 Review & Merge stage). It acts as the automated component of **The Great Filter** (deck slide 16), reviewing Pull Requests against organizational policy-as-code (`REVIEW.md`) and babysitting agent-opened PRs until they are ready for merge.

It operates as a **Kind-B control-plane skill** integrated with the PR hosting provider (GitHub / GitLab) via the tracker-agnostic integration layer (`factory-mission/references/tracker-integration.md`).

---

## When to use

- Before any PR is merged, to run identical, consistent compliance checks.
- To have the agent automatically address reviewer comment threads and push fixes.
- To manage agent-opened PRs (sweeping unresolved threads, resolving failing tests) until they are ready for final sign-off.

**When NOT to use**:
- To evaluate test execution correctness (use `factory-mission` / evals judges instead).
- To bypass branch protection (this skill **never** approves or merges PRs).

---

## Process

### 1. Policy-as-Code Configuration
1. Read the `REVIEW.md` file from the repository root. If absent, create a default template.
2. The policy defines:
   - **Review passes**: Bugs & logical errors, security vulnerabilities, and compliance against design documents (`PRD.md`/`AD.md`).
   - **Severity weights**: What constitutes an *Important* block (e.g., memory leak, security risk, spec deviation) vs. a *Nit* (formatting, style).
   - **Skip lists**: Generated paths, vendor files, and CI-validated paths.

### 2. PR Review Pipeline
When triggered with `--pr <id>`:
1. Discover credentials and PR hosting tools (`factory-mission/references/tracker-integration.md`).
2. Fetch the PR diff and description.
3. Run the identical passes defined in `REVIEW.md`.
4. Format and post **severity-ranked findings** as inline PR comments via MCP.
5. If findings contain `Important` issues, set PR label to `validation`. If clean, set to `validation` + advise code-owner of merge-readiness.
6. **Separation of Duties (Mandatory)**: The review agent physically cannot approve or merge the PR. A human code-owner's explicit approval is always required.

### 3. Agent Comment-Addressing & Babysitting
- **Comment-Addressing**: When a human reviewer tags the agent (e.g., `@agent fix this`), the agent reads the thread context, implements the correction, and pushes the fix.
- **Babysit-to-Merge**: For PRs opened by the agent:
  - Sweep the PR regularly for new comments or failing CI checks.
  - Automatically fix failing checks or address review comments, pushing updates until the PR is green.
  - Leave the PR in a merge-ready state awaiting final human approval.

### 4. Findings to Directives Feedback Loop (PDR-040)
- **Twice-Mistake Threshold**: If the review detects the same policy violation on a second PR, automatically trigger a local `levelup-specify` call to extract a preventive rule.
- Package the rule as a CDR draft (via `factory-learn`) targeting the `team-ai-directives` repository.
- Flag any changes that make current directives outdated.

---

## Safety & Operating Constraints

1. **Strictly Non-Approving**: Under no circumstances does the review agent approve its own code or bypass branch protection.
2. **Advisory Auto-Merge**: Triage confidence scores (PDR-048) and validation outputs advise on auto-merge eligibility; the actual merge is executed by code-owners or strict GitHub Actions branch rules.
3. **Dry-Run Gating**: Initial review comments must be previewed locally before being written to the remote PR thread.
