// CDR routing recall eval (adlc-workspace#36, kanfil's unblock condition on #203).
//
// The same tasks are routed against shapes of the injected CDR index:
//   shipped    — rendered live by boot.sh from fixture/directives
//                (render_index.sh); what a session really gets — today one
//                "Use when …" line per record
//   full-table — snapshot: the pre-#36 rows (ID | Type | descriptor), rendered
//                from the same fixture by boot.sh at 3ccd33c
//   topic-map  — snapshot: names only, grouped by directory, rendered from the
//                same fixture by boot.sh at 9f99476
// Regenerate a snapshot: BOOT_SH=<old boot.sh> render_index.sh > indexes/<shape>.md
// The grader scores recall of the expected modules per case; summarize.py
// prints the hit rate per shape and gates on it (EVAL-018).
//
// CI: every PR runs CDR_RECALL_SHAPES=shipped (one call per case) against a
// fixed floor; nightly runs the default set (3 calls per case) and also checks
// that the shipped shape does not recall less than the pre-#36 table.
//
// Run:  promptfoo eval -c evals/promptfoo/cdr-recall/config.js --no-cache \
//         -o /tmp/cdr-recall.json && python3 evals/promptfoo/cdr-recall/summarize.py /tmp/cdr-recall.json
const { execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const here = __dirname;
const SHAPES = (process.env.CDR_RECALL_SHAPES || 'shipped,full-table,topic-map').split(',');
const parsed = JSON.parse(fs.readFileSync(path.join(here, 'cases.json'), 'utf8'));
const { always_allow } = parsed;
// CDR_RECALL_CASES=id1,id2 runs a subset (smoke runs); default is every case.
const only = process.env.CDR_RECALL_CASES ? new Set(process.env.CDR_RECALL_CASES.split(',')) : null;
const cases = parsed.cases.filter((c) => !only || only.has(c.id));

const TEMPLATE = (index) =>
  'You are a coding agent at session start. Your team injected this index of team rules (CDRs):\n\n' +
  index +
  '\n\nBefore starting the task below, decide which of these records you would open and follow. ' +
  'Output ONLY one record per line, using its module name if shown, otherwise its ID. ' +
  'Pick every record that applies and nothing that does not. If none applies, output exactly NONE.\n\n' +
  'Task: {{task}}\n\nRecords:';

// shipped is rendered on every load, never read from a checked-in file.
const indexFor = (shape) => (shape === 'shipped'
  ? execFileSync('bash', [path.join(here, 'render_index.sh')], { encoding: 'utf8' })
  : fs.readFileSync(path.join(here, 'indexes', shape + '.md'), 'utf8'));

module.exports = {
  description: 'CDR routing recall (EVAL-018): shipped index vs pre-#36 table vs names-only topic map',
  prompts: SHAPES.map((shape) => ({
    id: `cdr-recall:${shape}`,
    label: shape,
    raw: TEMPLATE(indexFor(shape)),
  })),
  // CDR_RECALL_PROVIDER=claude routes through the local `claude` CLI
  // (claude_provider.sh); default is the suite's OpenAI provider (CI).
  providers: process.env.CDR_RECALL_PROVIDER === 'claude'
    ? [{ id: `exec:${path.join(here, 'claude_provider.sh')}`, label: 'claude-cli' }]
    : [
    {
      id: `openai:chat:${process.env.EVAL_MODEL || 'gpt-4o-mini'}`,
      config: {
        apiBaseUrl: process.env.OPENAI_BASE_URL || undefined,
        apiKey: process.env.OPENAI_API_KEY,
        temperature: 0,
      },
    },
  ],
  tests: cases.map((c) => ({
    description: c.id,
    vars: { task: c.task, case_json: JSON.stringify({ ...c, always_allow }) },
    assert: [{ type: 'python', value: `file://${path.join(here, 'check_cdr_recall.py')}` }],
  })),
};
