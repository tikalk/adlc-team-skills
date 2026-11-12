/**
 * Oracle-Independence Detection Tests
 * Tests for detecting when test expected values are derived from code under test
 *
 * Governing records (traceability only — see adlc-team-skills/REVIEW.md
 * "Decision-record ids"): PDR-145 (oracle independence in tests & graders),
 * ADR-462 (oracle independence detection algorithm).
 *
 * No test runner is wired into this repo's JS tooling (CI runs pytest; see
 * .github/workflows/test.yml), so this file is self-contained: it defines
 * its own minimal describe/it shim and runs directly via
 * `node tests/unit/oracle-independence-detection.test.js`, exiting non-zero
 * on any failure.
 */

const assert = require('assert');
const { detectOracleLaundering } = require('../../skills/factory/factory-review/references/oracle-detector');

let currentSuite = [];
let failures = [];
let passCount = 0;

function describe(name, fn) {
  currentSuite.push(name);
  fn();
  currentSuite.pop();
}

function it(name, fn) {
  const fullName = [...currentSuite, name].join(' > ');
  try {
    fn();
    passCount++;
    console.log('[PASS]', fullName);
  } catch (e) {
    failures.push({ name: fullName, error: e.message });
    console.log('[FAIL]', fullName, '-', e.message);
  }
}

describe('Oracle-Independence Detection', () => {

  describe('Detection', () => {

    it('flags derived-expected test as oracle-laundering', () => {
      const code = `
        const sum = (arr) => arr.reduce((a,b) => a+b, 0);

        test('sum works', () => {
          const arr = [1, 2, 3];
          assert.equal(sum(arr), arr.reduce((a,b) => a+b, 0));
        });
      `;

      const findings = detectOracleLaundering(code);
      assert(findings.length > 0, 'Should detect oracle-laundering');

      const oracleFinding = findings[0];
      assert.strictEqual(oracleFinding.severity, 'Important');
      assert(oracleFinding.evidence.includes('oracle:'), 'Should include oracle: evidence');
      assert(oracleFinding.message.includes('oracle'), 'Message should mention oracle');
    });

    it('detects reduce() as derived identifier', () => {
      const code = `
        const sum = (arr) => arr.reduce((a,b) => a+b, 0);
        test('sum', () => {
          const arr = [1, 2, 3];
          assert.equal(sum(arr), arr.reduce((a,b) => a+b, 0));
        });
      `;

      const findings = detectOracleLaundering(code);
      assert(findings.length > 0);
      assert(findings[0].details.derivationPath.includes('reduce'));
    });

    it('allows justified snapshots with rationale comment', () => {
      const code = `
        test('API response structure', () => {
          const response = api.getUser(123);
          // Rationale: API contract changed in v2.0
          assert.deepEqual(response, { id: 123, name: 'Alice' });
        });
      `;

      const findings = detectOracleLaundering(code);
      // With rationale, oracle is allowed
      assert(findings.length === 0 || findings[0].allowed === true);
    });

    it('allows reference to external specification', () => {
      const code = `
        test('JSON schema validation', () => {
          const data = fetchData();
          const schema = require('./openapi.json');
          assert(jsonschema.validate(data, schema));
        });
      `;

      const findings = detectOracleLaundering(code);
      // External spec is legitimate, not oracle
      assert(findings.length === 0);
    });

    it('detects expect().toBe() oracle patterns', () => {
      // Uses a test-scope identifier (x) in both the call and the expected
      // value, matching the derivation heuristic. A purely-literal expected
      // value (e.g. `.toBe(5 * 2)`) shares no identifier with test scope and
      // is a known detection gap, not something this heuristic can catch
      // (see docs/oracle-independence-detection.md).
      const code = `
        const calculate = (x) => x * 2;
        test('double value', () => {
          const x = 5;
          expect(calculate(x)).toBe(x * 2);
        });
      `;

      const findings = detectOracleLaundering(code);
      assert(findings.length > 0, 'Should detect oracle in expect().toBe()');
    });

    it('distinguishes between literal values and derived values', () => {
      // Literal expected value - SAFE
      const literalCode = `
        const sum = (a, b) => a + b;
        test('add two numbers', () => {
          assert.equal(sum(2, 3), 5);
        });
      `;

      const findings1 = detectOracleLaundering(literalCode);
      assert(findings1.length === 0, 'Literal expected values are safe');

      // Derived expected value - ORACLE
      const derivedCode = `
        const sum = (a, b) => a + b;
        test('add two numbers', () => {
          const a = 2, b = 3;
          assert.equal(sum(a, b), a + b);
        });
      `;

      const findings2 = detectOracleLaundering(derivedCode);
      assert(findings2.length > 0, 'Derived expected values are oracle');
    });

    it('handles multiple assertions in same test', () => {
      // Both assertions reuse test-scope identifiers (a, b) in the expected
      // value, matching the derivation heuristic.
      const code = `
        const multiply = (a, b) => a * b;
        const add = (a, b) => a + b;

        test('math operations', () => {
          const a = 3, b = 4;
          assert.equal(multiply(a, b), a * b);    // oracle
          assert.equal(add(a, b), a + b);         // oracle
        });
      `;

      const findings = detectOracleLaundering(code);
      assert(findings.length >= 2, 'Should detect multiple oracles');
    });

  });

  describe('Implementation Validation', () => {

    it('produces structured evidence trail', () => {
      const code = `
        const sum = (arr) => arr.reduce((a,b) => a+b, 0);
        test('sum', () => {
          const arr = [1, 2, 3];
          assert.equal(sum(arr), arr.reduce((a,b) => a+b, 0));
        });
      `;

      const findings = detectOracleLaundering(code);
      assert(findings.length > 0);

      const finding = findings[0];
      assert(finding.evidence, 'Should have evidence field');
      assert(finding.details, 'Should have details object');
      assert(finding.details.derivationPath, 'Should track derivation chain');
    });

    it('includes location information for debugging', () => {
      const code = `
        test('example', () => {
          assert.equal(fn(x), fn(x));
        });
      `;

      const findings = detectOracleLaundering(code);
      if (findings.length > 0) {
        assert(findings[0].location || findings[0].line, 'Should include location info');
      }
    });

  });

  describe('Edge Cases', () => {

    it('ignores comments that do not explain rationale', () => {
      const code = `
        test('test name', () => {
          // This calculates the expected value
          assert.equal(result, someFunc());
        });
      `;

      const findings = detectOracleLaundering(code);
      // Generic comment doesn't count as rationale
      assert(findings.length > 0);
    });

    it('handles nested function definitions', () => {
      const code = `
        test('nested', () => {
          const helper = (x) => x * 2;
          assert.equal(helper(5), helper(5));
        });
      `;

      const findings = detectOracleLaundering(code);
      assert(findings.length > 0, 'Should detect oracle even with nested functions');
    });

  });

});

console.log();
console.log(`${passCount} passed, ${failures.length} failed out of ${passCount + failures.length}`);
if (failures.length > 0) {
  process.exit(1);
}
