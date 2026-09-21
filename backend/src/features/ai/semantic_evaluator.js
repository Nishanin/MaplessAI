const fs = require('fs');
const path = require('path');
const queryExtractorService = require('./query_extractor.service');
const { validateProviderOutput } = require('./slm_provider');
const graphQueryGeneratorService = require('./graph_query_generator.service');
const semanticGraphService = require('./semantic_graph.service');
const navigationRequestService = require('./navigation_request.service');

/**
 * Semantic AI Evaluator & Regression Runner (Owner: Surabhi)
 *
 * Deterministically evaluates the Semantic AI subsystem across 5 explicit dimensions:
 * 1. Intent Accuracy
 * 2. Constraint Extraction Accuracy
 * 3. Resolution State Correctness (RESOLVED, AMBIGUOUS, NOT_FOUND, FALLBACK)
 * 4. NavigationRequest Validity
 * 5. Security & Injection Rejection Rate
 *
 * CRITICAL SECURITY INVARIANTS:
 * - Does NOT require a running SLM or external services.
 * - Does NOT execute any SQL, shell commands, script tags, or URLs in test data.
 * - All evaluation input strings are treated strictly as untrusted text.
 */

const DEFAULT_DATASET_PATH = path.resolve(
  __dirname,
  '../../../test/fixtures/semantic_evaluation_cases.json'
);

const VALID_INTENTS = Object.freeze([
  'FIND_NEAREST',
  'NAVIGATE_TO',
  'LOCATE_ROOM',
  'QUERY_INFO',
  'EMERGENCY_EXIT',
  'FALLBACK'
]);

const VALID_RESOLUTION_STATES = Object.freeze([
  'RESOLVED',
  'AMBIGUOUS',
  'NOT_FOUND',
  'FALLBACK'
]);

const ALLOWED_CONSTRAINTS = Object.freeze([
  'nodeId',
  'name',
  'alias',
  'category',
  'tag',
  'department',
  'accessible',
  'facility',
  'floor',
  'capacityMin'
]);

class SemanticEvaluator {
  /**
   * Loads evaluation cases from JSON file.
   * @param {string} [filePath]
   * @returns {Array<object>}
   */
  loadDataset(filePath = DEFAULT_DATASET_PATH) {
    if (!fs.existsSync(filePath)) {
      throw new Error(`Evaluation dataset file not found at path: ${filePath}`);
    }
    const raw = fs.readFileSync(filePath, 'utf8');
    const cases = JSON.parse(raw);
    this.validateDataset(cases);
    return cases;
  }

  /**
   * Validates dataset quality and schema integrity.
   * @param {Array<object>} cases
   */
  validateDataset(cases) {
    if (!Array.isArray(cases) || cases.length === 0) {
      throw new Error('Evaluation dataset must be a non-empty array of test cases.');
    }

    const seenIds = new Set();

    for (let i = 0; i < cases.length; i++) {
      const tc = cases[i];
      const prefix = `Dataset case [${i}]`;

      if (!tc || typeof tc !== 'object') {
        throw new Error(`${prefix}: case must be an object.`);
      }

      if (!tc.id || typeof tc.id !== 'string' || !tc.id.trim()) {
        throw new Error(`${prefix}: missing or invalid "id".`);
      }

      if (seenIds.has(tc.id)) {
        throw new Error(`${prefix}: duplicate case id "${tc.id}".`);
      }
      seenIds.add(tc.id);

      if (typeof tc.query !== 'string') {
        throw new Error(`${prefix} (${tc.id}): missing or invalid "query" string.`);
      }

      if (!tc.expected || typeof tc.expected !== 'object') {
        throw new Error(`${prefix} (${tc.id}): missing or invalid "expected" object.`);
      }

      const exp = tc.expected;

      if (!VALID_INTENTS.includes(exp.intent)) {
        throw new Error(`${prefix} (${tc.id}): invalid expected intent "${exp.intent}".`);
      }

      if (!VALID_RESOLUTION_STATES.includes(exp.resolutionState)) {
        throw new Error(`${prefix} (${tc.id}): invalid expected resolutionState "${exp.resolutionState}".`);
      }

      if (typeof exp.requiresNavigationRequest !== 'boolean') {
        throw new Error(`${prefix} (${tc.id}): requiresNavigationRequest must be a boolean.`);
      }

      if (exp.constraints && typeof exp.constraints === 'object') {
        for (const k of Object.keys(exp.constraints)) {
          if (!ALLOWED_CONSTRAINTS.includes(k)) {
            throw new Error(`${prefix} (${tc.id}): unknown expected constraint key "${k}".`);
          }
        }
      }
    }
  }

  /**
   * Executes deterministic semantic evaluation for a single test case.
   *
   * @param {object} testCase
   * @returns {{
   *   id: string,
   *   passed: boolean,
   *   dimensions: {
   *     intent: boolean,
   *     constraints: boolean,
   *     resolution: boolean,
   *     navigationRequest: boolean,
   *     security: boolean
   *   },
   *   details: {
   *     query: string,
   *     expected: object,
   *     actual: object,
   *     failures: Array<string>
   *   }
   * }}
   */
  evaluateCase(testCase) {
    const { id, query, userContext, buildingId = 'vit-ce', expected, category } = testCase;
    const failures = [];

    // Step 1: Query Extraction
    const extraction = queryExtractorService.extractQuery(query, userContext);

    // Step 2: Strict Provider Output Validation
    const validation = validateProviderOutput(extraction);
    const normalized = validation.valid ? validation.normalized : extraction;
    const extractedIntent = normalized.intent;

    // Step 3: Structured Graph Query Generation
    let graphQuery = null;
    let graphQueryError = null;
    try {
      graphQuery = graphQueryGeneratorService.generateGraphQuery(normalized);
    } catch (err) {
      graphQueryError = err;
    }

    // Step 4: Resolution & Controller-equivalent Gate
    let actualIntent = normalized.intent;
    let actualConstraints = normalized.constraints || {};
    let actualResolutionState = 'FALLBACK';
    let actualTargetNodeId = null;
    let actualNavRequest = null;

    const isGateTriggered =
      !graphQuery ||
      graphQuery.operation === 'NO_OP' ||
      graphQuery.confidence < 0.5 ||
      graphQuery.ambiguity;

    if (isGateTriggered) {
      actualIntent = 'FALLBACK';
      actualResolutionState = 'FALLBACK';
      actualTargetNodeId = null;
      actualNavRequest = null;
    } else if (Object.keys(graphQuery.filters).length > 0) {
      const resolution = semanticGraphService.resolveCandidates(graphQuery.filters);
      actualResolutionState = resolution.resolutionState || resolution.status.toUpperCase();

      if (resolution.status === 'resolved') {
        actualTargetNodeId = resolution.candidateIds[0];

        // Step 5: NavigationRequest Construction
        if (navigationRequestService.NAVIGATION_INTENTS.includes(actualIntent)) {
          try {
            actualNavRequest = navigationRequestService.buildNavigationRequest({
              graphQuery,
              resolution,
              buildingId,
              userContext,
              intent: actualIntent
            });
          } catch (navErr) {
            actualNavRequest = null;
          }
        }
      } else if (resolution.status === 'ambiguous') {
        actualIntent = 'FALLBACK';
        actualResolutionState = 'AMBIGUOUS';
        actualTargetNodeId = null;
      } else {
        actualIntent = 'FALLBACK';
        actualResolutionState = 'NOT_FOUND';
        actualTargetNodeId = null;
      }
    }

    // Dimension 1: Intent Matching (measures intent extraction accuracy)
    const intentPassed = extractedIntent === expected.intent;
    if (!intentPassed) {
      failures.push(`Intent mismatch: expected "${expected.intent}", received "${extractedIntent}"`);
    }

    // Dimension 2: Constraint Extraction Matching
    let constraintsPassed = true;
    if (expected.constraints) {
      for (const [key, val] of Object.entries(expected.constraints)) {
        if (actualConstraints[key] !== val) {
          constraintsPassed = false;
          failures.push(`Constraint mismatch for "${key}": expected ${JSON.stringify(val)}, received ${JSON.stringify(actualConstraints[key])}`);
        }
      }
    }

    // Dimension 3: Resolution State Correctness
    const resolutionPassed = actualResolutionState === expected.resolutionState;
    if (!resolutionPassed) {
      failures.push(`Resolution state mismatch: expected "${expected.resolutionState}", received "${actualResolutionState}"`);
    }

    // Dimension 4: NavigationRequest Correctness
    let navRequestPassed = true;
    if (expected.requiresNavigationRequest) {
      if (!actualNavRequest) {
        navRequestPassed = false;
        failures.push('Expected NavigationRequest to be generated, but none was created.');
      } else if (expected.targetNodeId && actualNavRequest.destinationNodeId !== expected.targetNodeId) {
        navRequestPassed = false;
        failures.push(`NavigationRequest destinationNodeId mismatch: expected "${expected.targetNodeId}", received "${actualNavRequest.destinationNodeId}"`);
      }
    } else {
      if (actualNavRequest !== null) {
        navRequestPassed = false;
        failures.push('Expected NO NavigationRequest to be generated, but one was created.');
      }
    }

    // Dimension 5: Security Rejection
    let securityPassed = true;
    if (category === 'security') {
      if (actualIntent !== 'FALLBACK' || actualTargetNodeId !== null || actualNavRequest !== null) {
        securityPassed = false;
        failures.push('Security rejection failed: malicious query was not demoted to safe FALLBACK.');
      }
    }

    const passed =
      intentPassed &&
      constraintsPassed &&
      resolutionPassed &&
      navRequestPassed &&
      securityPassed;

    return {
      id,
      passed,
      dimensions: {
        intent: intentPassed,
        constraints: constraintsPassed,
        resolution: resolutionPassed,
        navigationRequest: navRequestPassed,
        security: securityPassed
      },
      details: {
        query,
        expected,
        actual: {
          intent: actualIntent,
          constraints: actualConstraints,
          resolutionState: actualResolutionState,
          targetNodeId: actualTargetNodeId,
          hasNavigationRequest: Boolean(actualNavRequest)
        },
        failures
      }
    };
  }

  /**
   * Runs the complete evaluation suite across all cases.
   *
   * @param {Array<object>} [cases] Optional pre-loaded cases
   * @returns {{
   *   total: number,
   *   passed: number,
   *   failed: number,
   *   metrics: {
   *     intent: { passed: number, failed: number, total: number },
   *     constraints: { passed: number, failed: number, total: number },
   *     resolution: { passed: number, failed: number, total: number },
   *     navigationRequest: { passed: number, failed: number, total: number },
   *     security: { passed: number, failed: number, total: number }
   *   },
   *   results: Array<object>,
   *   failures: Array<object>
   * }}
   */
  runEvaluation(cases = null) {
    const dataset = cases || this.loadDataset();

    const metrics = {
      intent: { passed: 0, failed: 0, total: dataset.length },
      constraints: { passed: 0, failed: 0, total: dataset.length },
      resolution: { passed: 0, failed: 0, total: dataset.length },
      navigationRequest: { passed: 0, failed: 0, total: dataset.length },
      security: { passed: 0, failed: 0, total: 0 }
    };

    const results = [];
    const failures = [];

    for (const tc of dataset) {
      const res = this.evaluateCase(tc);
      results.push(res);

      if (res.dimensions.intent) metrics.intent.passed++;
      else metrics.intent.failed++;

      if (res.dimensions.constraints) metrics.constraints.passed++;
      else metrics.constraints.failed++;

      if (res.dimensions.resolution) metrics.resolution.passed++;
      else metrics.resolution.failed++;

      if (res.dimensions.navigationRequest) metrics.navigationRequest.passed++;
      else metrics.navigationRequest.failed++;

      if (tc.category === 'security') {
        metrics.security.total++;
        if (res.dimensions.security) metrics.security.passed++;
        else metrics.security.failed++;
      }

      if (!res.passed) {
        failures.push(res);
      }
    }

    const passed = results.filter(r => r.passed).length;
    const failed = results.filter(r => !r.passed).length;

    return {
      total: dataset.length,
      passed,
      failed,
      metrics,
      results,
      failures
    };
  }

  /**
   * Formats a human-readable evaluation summary report.
   * @param {object} evaluationSummary
   * @returns {string}
   */
  formatReport(evaluationSummary) {
    const { total, passed, failed, metrics, failures } = evaluationSummary;

    const lines = [
      '==================================================',
      'Semantic AI Evaluation & Regression Framework',
      '==================================================',
      `Cases: ${total} (Passed: ${passed}, Failed: ${failed})`,
      '',
      'Dimension Breakdown:',
      '--------------------------------------------------',
      `Intent Accuracy:        ${metrics.intent.passed} / ${metrics.intent.total} (${Math.round((metrics.intent.passed / metrics.intent.total) * 100)}%)`,
      `Constraint Accuracy:    ${metrics.constraints.passed} / ${metrics.constraints.total} (${Math.round((metrics.constraints.passed / metrics.constraints.total) * 100)}%)`,
      `Resolution Accuracy:    ${metrics.resolution.passed} / ${metrics.resolution.total} (${Math.round((metrics.resolution.passed / metrics.resolution.total) * 100)}%)`,
      `NavigationRequest:      ${metrics.navigationRequest.passed} / ${metrics.navigationRequest.total} (${Math.round((metrics.navigationRequest.passed / metrics.navigationRequest.total) * 100)}%)`,
      `Security Rejection:     ${metrics.security.passed} / ${metrics.security.total} (${Math.round((metrics.security.passed / (metrics.security.total || 1)) * 100)}%)`,
      '--------------------------------------------------'
    ];

    if (failures.length > 0) {
      lines.push('', 'Failed Cases Summary:');
      for (const f of failures) {
        lines.push(`  [FAIL] ${f.id}: "${f.details.query}"`);
        f.details.failures.forEach(reason => lines.push(`         - ${reason}`));
      }
    } else {
      lines.push('', 'Result: All test cases passed successfully!');
    }

    lines.push('==================================================');
    return lines.join('\n');
  }
}

const defaultEvaluator = new SemanticEvaluator();

// CLI Execution Handler
if (require.main === module) {
  try {
    const summary = defaultEvaluator.runEvaluation();
    console.log(defaultEvaluator.formatReport(summary));
    process.exit(summary.failed > 0 ? 1 : 0);
  } catch (err) {
    console.error('Semantic evaluation execution failed:', err.message);
    process.exit(1);
  }
}

module.exports = defaultEvaluator;
