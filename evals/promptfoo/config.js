module.exports = {
  description: 'adlc-team-skills Evaluation Suite',
  prompts: [
    'Evaluate this scenario and return the expected compliance output:\n\nScenario: {{scenario}}\nContext: {{input_context}}\n\nOutput:',
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
      },
      assert: [
        {
          type: 'python',
          value: 'file://./graders/check_goldset_format.py',
        },
      ],
    },
  ],
  outputPath: '../results/run_results.json',
};