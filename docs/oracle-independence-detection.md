# Oracle-Independence Detection

## What it detects

A check that takes its expected value from the code under test proves
nothing — it grades the implementation against itself. Agent-authored tests
tend toward this shape: snapshots regenerated from current behavior,
expected values computed by calling the implementation, mocks returning
implementation output.

`skills/factory/factory-review/references/oracle-detector.js` makes this an
Important finding class inside the test-integrity review pass: an
assertion's expected value is flagged when it references an identifier also
defined in the test's own scope (the governing product and architecture
decisions behind this are named, not cited by id, per this repo's
decision-record rule — see `docs/decision-memory.md`).

Example: `assert.equal(sum(arr), arr.reduce((a, b) => a + b, 0))` shares the
identifier `arr` between the call under test and the "expected" expression —
the test never independently states what the answer should be, it just
re-runs the logic. The detector flags this with an evidence trail in
`oracle:<derivation-path>` format (e.g. `oracle:arr->reduce`), traceable back
to the shared identifiers.

A legitimate snapshot update is not flagged as blocking: a leading comment
containing words like "rationale", "approved", or "contract" next to the
assertion marks it as a reviewed, justified update (`allowed: true`,
`Info` severity instead of `Important`).

## Known limitation: literal-reimplementation oracles

The algorithm detects oracle-laundering via **identifier-scope matching**
only. It does not catch a formula re-implemented purely with literals that
share no identifier with the test's scope — e.g.
`assert.equal(multiply(3, 4), 3 * 4)`. Catching that pattern would require
structural/semantic comparison between the expected expression and the
implementation under test, a materially different and more complex
algorithm than what's implemented here.

`evals/oracle-laundering.eval.js` scenarios 5 and 6 exercise exactly this
pattern. They are tagged `knownGap` and will not show a finding — this is
expected, not a regression. The harness's `run()` executes them, reports
their real result, and counts them separately from the in-scope scenarios.
Current measured result: 6/6 in-scope scenarios pass; 0/2 known-gap
scenarios pass.

## Validation history

An earlier pass claimed "8/8 eval scenarios passed, 100%" — direct execution
showed that claim was false: the detector produced zero real findings in any
scenario, and the harness's pass/fail arithmetic happened to agree with a
non-functional detector by coincidence for every scenario. The harness's
`run()` formula was inverted for should-detect scenarios and has since been
corrected, and the scenario that justified a snapshot with a rationale
comment no longer uses an always-true check. Four real bugs
were found and fixed by running the detector against realistic code rather
than trusting the harness's reported result:

- the test-callback type check rejected arrow-function test bodies
  (`test('x', () => {...})`) — the common case in modern JS test code
- nested AST-traversal calls on detached sub-nodes threw (the traversal
  library requires explicit scope/parent context for anything other than a
  whole-file root), masked by a catch-all as a generic parse error
- a function's name was read from the wrong property, disabling
  self-referential-grader detection entirely
- rationale comments attach to the enclosing statement, not the assertion
  expression itself, so justified-snapshot detection never matched

`tests/unit/oracle-independence-detection.test.js` is self-contained (no
external test-framework dependency — this repo's CI runs pytest, so the file
defines its own minimal `describe`/`it` shim) and genuinely passes in full
when run directly via `node tests/unit/oracle-independence-detection.test.js`.
