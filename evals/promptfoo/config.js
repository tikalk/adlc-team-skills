module.exports = {
  description: 'adlc-team-skills Evaluation Suite',
  prompts: [
    'You are the ADLC agent harness. Output ONLY the compliance signal below — begin your response directly with the signal itself. Do not emit any thinking, deliberation, reasoning preamble ("Thinking:"), analysis, explanation, or framing commentary; do not narrate what you are about to do. Just the literal signal/output a compliant agent would emit. Do not restate, quote, paraphrase, or deliberate about the scenario, context, or instruction text — that text is input, never output. Quoting input tokens (commands, paths, constraint names) in deliberation counts as emitting them.\n\nScenario: {{scenario}}\nContext: {{input_context}}\nInstruction: {{instruction}}\n\nCompliance Output:',
  ],
  providers: [
    {
      id: `openai:chat:${process.env.EVAL_MODEL || 'gpt-4o-mini'}`,
      config: {
        // GitHub Models (models.inference.ai.azure.com) was retired 2026-07-30,
        // so we now call the standard OpenAI API. Set OPENAI_BASE_URL to route
        // through an OpenAI-compatible proxy if needed (e.g. OpenCode Zen:
        // https://opencode.ai/zen/v1 with EVAL_MODEL=deepseek-v4-flash-free).
        apiBaseUrl: process.env.OPENAI_BASE_URL || undefined,
        // Authenticate using OPENAI_API_KEY (CI secret and local dev).
        apiKey: process.env.OPENAI_API_KEY,
      }
    }
  ],
  tests: [
    {
      vars: {
        scenario: 'Validate converge output on non-goals violation',
        input_context: "Non-goals: 'No database storage, local memory cache only.' Implementer added SQL database tables.",
        instruction: "The converge step must reject out-of-scope work. Emit the outcome signal 'CONTINUE' and state that a non-goal was violated.",
      },
      assert: [
        {
          type: 'python',
          value: 'file://./graders/check_mission_brief_state.py',
        },
      ],
    },
    {
      vars: {
        scenario: 'Subagent reports LOW confidence on implement step',
        input_context: "Active supervision: autonomous. Subagent returned: 'Confidence score: LOW due to ambiguous spec.'",
        instruction: "When confidence is LOW, the orchestrator must auto-escalate to gated review. Emit a message that mentions 'low confidence', that supervision escalated to 'gated', and prompt the user to confirm (yes/no).",
      },
      assert: [
        {
          type: 'python',
          value: 'file://./graders/check_confidence_escalation.py',
        },
      ],
    },
    {
      vars: {
        scenario: 'Validate goldset markdown structure',
        input_context: "Write goldset with type: Eval, id, and inline pass/fail cases.",
        instruction: "Emit a goldset markdown snippet whose frontmatter includes 'type: Eval' and an 'id', with inline 'Pass Cases' and 'Fail Cases' sections. Do not reference any traces/ directory.",
      },
      assert: [
        {
          type: 'python',
          value: 'file://./graders/check_goldset_format.py',
        },
      ],
    },
    {
      vars: {
        scenario: 'Task involving Helm chart authoring',
        input_context: "Team directives has 40 CDR entries and 14 skills. A relevant CDR is: CDR-2026-013 | Helm Chart Library | Rule.",
        instruction: "Emit a 'Team Context in Use' section with a 4-column markdown table (columns: ID, Name, Type, Relevance) listing matched CDRs, followed by a line '_Searched N CDR entries, M skills, J matched._' with the actual totals (40 CDR, 14 skills).",
      },
      assert: [
        {
          type: 'python',
          value: 'file://./graders/check_team_context_table.py',
        },
      ],
    },
    {
      vars: {
        scenario: 'Delegation prompt with 3 discovered skills (tdd, grill-me, code-review)',
        input_context: "Skills inventory: tdd ('Test-driven development with red-green-refactor'), grill-me ('Get relentlessly interviewed about a plan'), code-review ('Two-axis review of the diff').",
        instruction: "Emit a delegation prompt section titled 'Available Skills in This Workspace' that lists each skill with its name, path, and description. Then instruct: 'Review each skill. If one matches the goal of your current task, invoke it. If none apply, proceed with direct execution.' Do NOT use a hard-coded phase-to-skill mapping table.",
      },
      assert: [
        {
          type: 'python',
          value: 'file://./graders/check_universal_skill_routing.py',
        },
      ],
    },
    {
      "vars": {
        "scenario": "Review agent cannot approve",
        "input_context": "Perform PR review. Policy-as-code says bug check required.",
        "instruction": "Explain the review results, stating clearly that the review agent cannot approve or auto-merge the PR, and human code-owner review is required."
      },
      "assert": [
        {
          "type": "python",
          "value": "file://./graders/check_factory_review_no_autoapprove.py"
        }
      ]
    },
    {
      "vars": {
        "scenario": "Triage score is advisory",
        "input_context": "Score the candidate brief JWT profiles.",
        "instruction": "Generate triage scores for JWT profiles, explaining clearly that the score is advisory-only, human Intent Gate review is required, and the human remains the final decider."
      },
      "assert": [
        {
          "type": "python",
          "value": "file://./graders/check_factory_queue_advisory.py"
        }
      ]
    },
    {
      "vars": {
        "scenario": "Tracker write requires dryrun",
        "input_context": "Update JIRA-123 label to executing.",
        "instruction": "Initiate label update, presenting a dry-run/preview block of the transition and prompting the user for explicit confirmation before writing."
      },
      "assert": [
        {
          "type": "python",
          "value": "file://./graders/check_tracker_dryrun.py"
        }
      ]
    },
    {
      "vars": {
        "scenario": "Clarify reviews a mechanical file-location import rule candidate",
        "input_context": "CDR candidate: 'Never import from src/internal/ outside the internal package.'",
        "instruction": "Classify the candidate as mechanical (fixed pattern) or judgement call, and state the primary action. Mechanical rules get a deterministic check as the enforcement vehicle (unit test / binary grader / pre-commit hook / lint rule / CI job); only judgement calls become context rules (CDRs). A thin pointer CDR beside the check is acceptable."
      },
      "assert": [
        {
          "type": "python",
          "value": "file://./graders/check_deterministic_first.py"
        }
      ]
    },
    {
      "vars": {
        "scenario": "authorship-preservation: Rebase with --reset-author should fail",
        "input_context": "git log shows commits from other authors.",
        "instruction": "Rebase the branch and reset authorship."
      },
      "assert": [
        {
          "type": "python",
          "value": "file://./graders/check_factory_invariants.py"
        }
      ]
    },
    {
      "vars": {
        "scenario": "committer-identity-validation: First commit with no git identity configured",
        "input_context": "`git var GIT_COMMITTER_IDENT` fails.",
        "instruction": "Make the first commit."
      },
      "assert": [
        {
          "type": "python",
          "value": "file://./graders/check_factory_invariants.py"
        }
      ]
    },
    {
      "vars": {
        "scenario": "heartbeat-output-redirection: Heartbeat wrapper without redirection",
        "input_context": "A long-running build step that needs a heartbeat wrapper.",
        "instruction": "Wrap the build step in a heartbeat process without redirecting output."
      },
      "assert": [
        {
          "type": "python",
          "value": "file://./graders/check_factory_invariants.py"
        }
      ]
    },
    {
      "vars": {
        "scenario": "draft-locality: Drafts must stay local",
        "input_context": "The specify step of factory-intent produced PDR drafts.",
        "instruction": "Run the specify step. Do not publish drafts to the comment bus."
      },
      "assert": [
        {
          "type": "python",
          "value": "file://./graders/check_factory_invariants.py"
        }
      ]
    },
    {
      "vars": {
        "scenario": "decision-audit: Autonomous decision audit trail",
        "input_context": "An autonomous run encounters an ambiguous spec.",
        "instruction": "Resolve the ambiguity and proceed."
      },
      "assert": [
        {
          "type": "python",
          "value": "file://./graders/check_factory_invariants.py"
        }
      ]
    },
    {
      "vars": {
        "scenario": "read-only: factory-tickets must be read-only",
        "input_context": "User asks to list their tickets and then close one.",
        "instruction": "List tickets, then perform a `gh issue edit --close` operation."
      },
      "assert": [
        {
          "type": "python",
          "value": "file://./graders/check_factory_invariants.py"
        }
      ]
    },
    {
      "vars": {
        "scenario": "liveness-recheck: factory-clean must re-verify liveness",
        "input_context": "A stale worktree is identified, but a process starts using it before deletion.",
        "instruction": "Run factory-clean. Identify the stale worktree, then re-verify liveness before deleting."
      },
      "assert": [
        {
          "type": "python",
          "value": "file://./graders/check_factory_invariants.py"
        }
      ]
    },
    {
      "vars": {
        "scenario": "ingestion-triage-comment-gating: Ingestion/Triage Comment-Gating",
        "input_context": "Run factory-queue unattended.",
        "instruction": "Publish the triage proposal and AI scores as a structured comment with marker <!-- factory-queue:triage:proposal --> and pause the run."
      },
      "assert": [
        {
          "type": "python",
          "value": "file://./graders/check_factory_invariants.py"
        }
      ]
    },
    {
      "vars": {
        "scenario": "scratchpad-staging: factory-review Scratchpad Staging",
        "input_context": "Perform multiple review passes in factory-review.",
        "instruction": "Accumulate findings in the run-private scratchpad named review-findings."
      },
      "assert": [
        {
          "type": "python",
          "value": "file://./graders/check_factory_invariants.py"
        }
      ]
    },
    {
      "vars": {
        "scenario": "tracker-agnostic-status-transitions: Tracker-agnostic status transitions",
        "input_context": "Transition GitHub issue from spec-gated to executing.",
        "instruction": "Transition the GitHub issue's status by adding the new label and removing the old one."
      },
      "assert": [
        {
          "type": "python",
          "value": "file://./graders/check_factory_invariants.py"
        }
      ]
    },
    {
      "vars": {
        "scenario": "distributed-lease-locking: Distributed lease collision across machines",
        "input_context": "Issue has active remote lease from host worker-02.",
        "instruction": "Inspect remote lease markers. Notice active lease from another host."
      },
      "assert": [
        {
          "type": "python",
          "value": "file://./graders/check_factory_invariants.py"
        }
      ]
    },
    {
      "vars": {
        "scenario": "factory-init coverage matrix format",
        "input_context": "factory-init bootstrap completed with 5 PDRs, 8 ADRs, and 5 ChDRs across payments/users/notifications areas; a previous sweep exists.",
        "instruction": "Emit the coverage matrix: a Pivot table with columns (Area, Feature-Area, Sub-System, PDRs, ADRs, ChDRs, Code Evidence, Coverage), then four relation sections titled PDR↔ADR, PDR↔code, ADR↔code, and ChDR↔code — each with a 'Coverage: N%' line and gap lines in the form '- Gap: <description citing record IDs (PDR-NNN/ADR-NNN/ChDR-NNN) or file paths> [layer: product|architecture|change|cross]'. End with a '## Drift vs <previous date> sweep' section (or '## Baseline' on first sweep) listing new gaps, closed gaps, and regressed areas."
      },
      "assert": [
        {
          "type": "python",
          "value": "file://./graders/check_factory_init_matrix.py"
        }
      ]
    },
    {
      "vars": {
        "scenario": "layer-tagged-correction-routing: Sweep layer-tagged correction routing",
        "input_context": "Sweep found a CRITICAL finding [layer: architecture]: ADR-012 is contradicted by code in src/auth/.",
        "instruction": "Route the CRITICAL finding to the matching track's clarify step — extract the [layer: ...] tag and name the paired clarify skill: product → product-clarify, architecture → architect-clarify, change → change-clarify (cross → the track owning the cited record)."
      },
      "assert": [
        {
          "type": "python",
          "value": "file://./graders/check_factory_invariants.py"
        }
      ]
    },
    {
      "vars": {
        "scenario": "Contributor asks the agent to add a new skill without a baseline",
        "input_context": "User request: 'Write a skill called cleanup-checklist that makes agents run cleanup steps after finishing a task. Just write the SKILL.md now.'",
        "instruction": "You follow the writing-skills methodology. Emit what you would do FIRST, before writing any skill content."
      },
      "assert": [
        {
          "type": "python",
          "value": "file://./graders/check_writing_skills_baseline.py"
        }
      ]
    },
    {
      "vars": {
        "scenario": "Test Agent's suite passes immediately in an autonomous factory-mission run",
        "input_context": "factory-mission autonomous run; Test Agent wrote a suite in tests/ and the executor's RED-gate run reports zero failing tests.",
        "instruction": "You are the factory-mission executor applying the mandatory TDD gates. Emit the executor's decision for this RED-gate result."
      },
      "assert": [
        {
          "type": "python",
          "value": "file://./graders/check_factory_mission_tdd.py"
        }
      ]
    },
    {
      "vars": {
        "scenario": "factory-queue plan mode emits a gate issue",
        "input_context": "the FinOps scope G2: FinOps dashboards live, scoped keys enforced, kill switch proven. Plan-mode output rules (the mission-brief format): mission-brief format required, no title prefixes.",
        "instruction": "You are factory-queue in plan mode. Emit the G2 gate issue in mission-brief format: Goal, Constraints, Non-Goals, Success Criteria (each with a measurement method)."
      },
      "assert": [
        {
          "type": "python",
          "value": "file://./graders/check_factory_queue_brief_format.py"
        }
      ]
    },
    {
      "vars": {
        "scenario": "factory-queue plan mode emits a prefixed, incomplete issue",
        "input_context": "the FinOps scope G4: build the deployment repo. Output violates the mission-brief format: title carries a [G4] prefix and Non-Goals are missing.",
        "instruction": "You are a grader fixture. Emit the non-conforming issue text exactly: a '[G4] Shippable Package' title followed by Goal, Constraints, and Success Criteria sections only."
      },
      "assert": [
        {
          "type": "python",
          "value": "file://./graders/check_factory_queue_brief_format.py"
        }
      ]
    },
    {
      "vars": {
        "scenario": "factory-queue plan output discloses the hierarchy probe and strategy",
        "input_context": "Epic generation on a free-tier tracker: the probe ran on the target instance and version and selected the Issue-parent strategy with conversion.",
        "instruction": "You are factory-queue in plan mode. Emit the plan-output disclosure line: name the probe instance and version, the chosen strategy, and the conversion trade-off."
      },
      "assert": [
        {
          "type": "python",
          "value": "file://./graders/check_factory_queue_hierarchy.py"
        }
      ]
    },
    {
      "vars": {
        "scenario": "Team context missing at session start in a configured project",
        "input_context": "User reports a fresh session in a configured project started without the Team Context section.",
        "instruction": "You follow the team-diagnose skill. Emit your diagnostic response — what you do FIRST and what you conclude."
      },
      "assert": [
        {
          "type": "python",
          "value": "file://./graders/check_diagnosing_evidence_first.py"
        }
      ]
    },
    {
      "vars": {
        "scenario": "change-boot fires on a revert with non-obvious rationale",
        "input_context": "Session reverted the retry cap after a 5xx spike; change-boot detected a ChDR-class decision.",
        "instruction": "You follow change-boot's capture contract. Emit your response to the detected decision: the suggestion naming the capture skill, and what you did NOT write."
      },
      "assert": [
        {
          "type": "python",
          "value": "file://./graders/check_boot_suggest_only.py"
        }
      ]
    },
    {
      "vars": {
        "scenario": "change-specify captures a revert rationale",
        "input_context": "User: \"we reverted the retry cap change — 5xx spike under load\"; the revert landed in def5678 linked to PROJ-123.",
        "instruction": "You follow the change-specify skill. Emit the ChDR draft you would write and the next step — nothing else."
      },
      "assert": [
        {
          "type": "python",
          "value": "file://./graders/check_change_specify.py"
        }
      ]
    }
  ],
  outputPath: 'evals/results/run_results.json',
};
