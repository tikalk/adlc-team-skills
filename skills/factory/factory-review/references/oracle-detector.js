/**
 * Oracle-Independence Detector
 * Detects oracle-laundering in tests: when expected values are derived from code under test
 *
 * Work Item: #40
 * PDR-145: Oracle independence in tests & graders
 * ADR-462: Oracle independence detection algorithm
 */

const { parse } = require('@babel/parser');
const traverse = require('@babel/traverse').default;

/**
 * Walk a detached AST sub-node (not attached to a Program/File root) and invoke
 * visitors by node type. Babel's traverse() requires scope+parentPath for any
 * node that isn't a Program/File, so sub-trees pulled out mid-traversal (an
 * assertion's arguments, a function body, an expected-value expression) must
 * be walked manually instead of re-entering traverse() on them.
 */
function walk(node, visitors, parent = null) {
  if (!node || typeof node.type !== 'string') return;

  const visitor = visitors[node.type];
  if (visitor) visitor(node, parent);

  for (const key of Object.keys(node)) {
    if (key === 'loc' || key === 'start' || key === 'end' || key === 'range' ||
        key === 'leadingComments' || key === 'trailingComments' || key === 'innerComments') {
      continue;
    }
    const value = node[key];
    if (Array.isArray(value)) {
      for (const item of value) walk(item, visitors, node);
    } else if (value && typeof value.type === 'string') {
      walk(value, visitors, node);
    }
  }
}

/**
 * Comments attach to the nearest statement (e.g. ExpressionStatement), not to
 * an inner expression like the assertion's CallExpression itself, so rationale
 * checks must fall back to the immediate parent's leadingComments.
 */
function getLeadingComments(node, parent) {
  return node.leadingComments || parent?.leadingComments || null;
}

/**
 * Main detection function
 * Returns array of findings with oracle:derivation-path evidence
 */
function detectOracleLaundering(testCode) {
  const findings = [];

  try {
    const ast = parse(testCode, {
      sourceType: 'module',
      plugins: ['jsx'],
      attachComment: true
    });

    // Track function definitions and their parameters
    const functionScopes = new Map();

    traverse(ast, {
      FunctionDeclaration(path) {
        functionScopes.set(path.node.name, {
          params: path.node.params.map(p => p.name),
          loc: path.node.loc
        });
      }
    });

    // Find all test calls and their assertions
    traverse(ast, {
      CallExpression(path) {
        const callee = path.node.callee;

        // Check if this is a test declaration
        if (isTestDeclaration(callee)) {
          const testCallback = path.node.arguments[1];
          if (testCallback && (testCallback.type === 'FunctionExpression' ||
              testCallback.type === 'ArrowFunctionExpression')) {
            // Find assertions within this test
            analyzeTestBlock(testCallback, findings, functionScopes);
          }
        }
      }
    });

  } catch (error) {
    // Parse errors - return with error context
    findings.push({
      type: 'parse-error',
      message: `Failed to parse test code: ${error.message}`,
      severity: 'Warning'
    });
  }

  return findings;
}

/**
 * Check if a callee is a test declaration (test, it, describe, etc.)
 */
function isTestDeclaration(callee) {
  if (callee.type === 'Identifier') {
    return ['test', 'it', 'describe'].includes(callee.name);
  }
  return false;
}

/**
 * Analyze assertions within a test block
 */
function analyzeTestBlock(testFn, findings, functionScopes) {
  // Extract all identifiers used in this test
  const testIdentifiers = new Set();

  walk(testFn, {
    Identifier(node) {
      testIdentifiers.add(node.name);
    }
  });

  // Find all assertions
  walk(testFn, {
    CallExpression(node, parent) {
      const { callee, arguments: args } = node;

      // Handle: assert.equal(actual, expected)
      if (callee.type === 'MemberExpression' &&
          callee.object?.name === 'assert' &&
          ['equal', 'strictEqual', 'deepEqual'].includes(callee.property?.name)) {

        if (args.length >= 2) {
          const expected = args[1];
          analyzeExpectedValue(expected, testIdentifiers, node, findings, parent);
        }
      }

      // Handle: expect(actual).toBe(expected) or .toEqual(expected)
      if (callee.type === 'MemberExpression' &&
          ['toBe', 'toEqual', 'toStrictEqual'].includes(callee.property?.name)) {

        if (args.length >= 1) {
          const expected = args[0];
          analyzeExpectedValue(expected, testIdentifiers, node, findings, parent);
        }
      }
    }
  });
}

/**
 * Check if expected value is oracle-laundering
 */
function analyzeExpectedValue(expectedNode, testIdentifiers, assertionNode, findings, assertionParent) {
  // Skip literal values (numbers, strings, booleans)
  if (['NumericLiteral', 'StringLiteral', 'BooleanLiteral'].includes(expectedNode.type)) {
    return; // Literals are safe
  }

  const derivedIdentifiers = [];
  const identifiersUsed = new Set();

  // Extract identifiers from expected value
  walk(expectedNode, {
    Identifier(node) {
      const name = node.name;
      identifiersUsed.add(name);

      // Check if this identifier is defined in test scope
      if (testIdentifiers.has(name)) {
        derivedIdentifiers.push(name);
      }
    }
  });

  // If expected uses identifiers from test, it's oracle-laundering
  if (derivedIdentifiers.length > 0) {
    const hasRationale = checkForRationale(assertionNode, assertionParent);

    findings.push({
      type: 'oracle-laundering',
      severity: hasRationale ? 'Info' : 'Important',
      message: hasRationale
        ? 'Oracle-laundering detected but rationale provided'
        : 'Test expected value is derived from code under test (oracle-laundering)',
      location: assertionNode.loc,
      evidence: `oracle:${derivedIdentifiers.join('->')}`,
      allowed: hasRationale,
      details: {
        derivedIdentifiers,
        derivationPath: derivedIdentifiers.join('->'),
        identifiersInExpected: Array.from(identifiersUsed),
        hasRationale,
        rationale: extractRationalComment(assertionNode, assertionParent)
      }
    });
  }
}

/**
 * Check if assertion has a rationale comment nearby
 */
function checkForRationale(assertionNode, assertionParent) {
  // Look for comments that explain why oracle is okay
  const comments = getLeadingComments(assertionNode, assertionParent);
  if (comments) {
    return comments.some(c =>
      /rationale|reason|intentional|approved|update|changed|contract|spec/i.test(c.value)
    );
  }
  return false;
}

/**
 * Extract rationale comment text
 */
function extractRationalComment(assertionNode, assertionParent) {
  const comments = getLeadingComments(assertionNode, assertionParent);
  if (comments) {
    const rationale = comments.find(c =>
      /rationale|reason|intentional|approved|update|changed|contract|spec/i.test(c.value)
    );
    return rationale?.value || null;
  }
  return null;
}

/**
 * Detect self-referential grader (grader evaluates its own output)
 * This is typically caught by analyzing the grader function signature
 */
function detectSelfReferentialGrader(code) {
  const findings = [];

  try {
    const ast = parse(code, {
      sourceType: 'module',
      plugins: ['jsx']
    });

    traverse(ast, {
      FunctionDeclaration(path) {
        // Look for grader functions with output used as reference
        const fnName = path.node.id?.name;
        if (fnName?.includes('Grader') || fnName?.includes('grader')) {
          // Check if grader uses its own computed result as reference
          const functionBody = path.node.body;
          const computedVars = new Set();

          walk(functionBody, {
            VariableDeclarator(node) {
              if (node.id?.name) computedVars.add(node.id.name);
            }
          });

          // If computed vars are used in comparisons, flag as self-referential
          let hasSelfRef = false;
          walk(functionBody, {
            BinaryExpression(node) {
              const { left, right } = node;
              if ((left.name && computedVars.has(left.name)) ||
                  (right.name && computedVars.has(right.name))) {
                hasSelfRef = true;
              }
            }
          });

          if (hasSelfRef) {
            findings.push({
              type: 'self-referential-grader',
              severity: 'Important',
              message: 'Grader evaluates its own computed output (self-referential)',
              location: path.node.loc,
              evidence: 'oracle:self-referential'
            });
          }
        }
      }
    });
  } catch (error) {
    // Silent fail for parse errors
  }

  return findings;
}

/**
 * Export detection functions
 */
module.exports = {
  detectOracleLaundering,
  detectSelfReferentialGrader
};
