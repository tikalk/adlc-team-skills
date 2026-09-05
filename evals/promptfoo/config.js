module.exports = {
  description: 'adlc-team-skills Evaluation Suite',
  prompts: [
    'You are the ADLC agent harness. Produce ONLY the exact compliance output for the scenario below — no analysis, no explanation, just the literal signal/output a compliant agent would emit.\n\nScenario: {{scenario}}\nContext: {{input_context}}\nInstruction: {{instruction}}\n\nCompliance Output:',
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
    }
  ],
  outputPath: 'evals/results/run_results.json',
};
