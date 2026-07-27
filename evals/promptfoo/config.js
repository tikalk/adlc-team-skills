module.exports = {
  description: 'adlc-team-skills Evaluation Suite',
  prompts: [
    'You are the ADLC agent harness. Produce ONLY the exact compliance output for the scenario below — no analysis, no explanation, just the literal signal/output a compliant agent would emit.\n\nScenario: {{scenario}}\nContext: {{input_context}}\nInstruction: {{instruction}}\n\nCompliance Output:',
  ],
  providers: [
    {
      id: 'openai:chat:gpt-4o-mini',
      config: {
        // Point to GitHub Models OpenAI-compatible endpoint in CI
        apiBaseUrl: process.env.GITHUB_TOKEN ? 'https://models.inference.ai.azure.com' : undefined,
        // Authenticate using GITHUB_TOKEN (CI) or fall back to OPENAI_API_KEY (local)
        apiKey: process.env.GITHUB_TOKEN || process.env.OPENAI_API_KEY,
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
        scenario: 'Plan-mode prompt with a concrete dbt coding task',
        input_context: "You are in plan mode (read-only). The user asks: 'set due_date in matches_backlog when status is pending from crm.'",
        instruction: "Before responding to any task or question, you MUST invoke the team-boot skill first. Emit EXACTLY this text (the tool call): skill({name: \"team-boot\"})",
      },
      assert: [
        {
          type: 'python',
          value: 'file://./graders/check_team_boot_first_call.py',
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
  ],
  outputPath: '../results/run_results.json',
};
