const semanticEvaluator = require('../src/features/ai/semantic_evaluator');

/**
 * Phase 10: Semantic AI Evaluation & Regression Test Suite (Owner: Surabhi)
 *
 * Tests cover:
 *   1. Evaluation dataset loading and quality validation (no duplicates, required fields, whitelisted constraints).
 *   2. Rejection of malformed evaluation datasets (duplicate IDs, invalid intents, unknown constraints).
 *   3. End-to-end evaluation execution and 100% security rejection rate.
 *   4. Dimension-by-dimension metrics reporting.
 *   5. Failure reporting format and failure detail capture.
 */

describe('Phase 10 — Semantic AI Evaluation Framework', () => {
  // ── 1. Dataset Loading & Schema Integrity ──────────────────────────────────
  describe('Dataset Quality Safeguards', () => {
    it('should successfully load the version-controlled evaluation dataset', () => {
      const dataset = semanticEvaluator.loadDataset();
      expect(Array.isArray(dataset)).toBe(true);
      expect(dataset.length).toBeGreaterThanOrEqual(50);
    });

    it('every evaluation case must have unique non-empty ID and required fields', () => {
      const dataset = semanticEvaluator.loadDataset();
      const seenIds = new Set();

      for (const tc of dataset) {
        expect(typeof tc.id).toBe('string');
        expect(tc.id.trim().length).toBeGreaterThan(0);
        expect(seenIds.has(tc.id)).toBe(false);
        seenIds.add(tc.id);

        expect(typeof tc.query).toBe('string');
        expect(tc.expected).toBeDefined();
        expect(typeof tc.expected.intent).toBe('string');
        expect(typeof tc.expected.resolutionState).toBe('string');
        expect(typeof tc.expected.requiresNavigationRequest).toBe('boolean');
      }
    });

    it('should reject datasets containing duplicate case IDs', () => {
      const invalidDataset = [
        {
          id: 'duplicate-id',
          query: 'Where is lab 101?',
          expected: { intent: 'LOCATE_ROOM', resolutionState: 'RESOLVED', requiresNavigationRequest: false }
        },
        {
          id: 'duplicate-id',
          query: 'Where is elevator?',
          expected: { intent: 'FIND_NEAREST', resolutionState: 'RESOLVED', requiresNavigationRequest: true }
        }
      ];

      expect(() => semanticEvaluator.validateDataset(invalidDataset)).toThrow(/duplicate case id "duplicate-id"/);
    });

    it('should reject datasets with unknown constraint keys', () => {
      const invalidDataset = [
        {
          id: 'invalid-constraint-id',
          query: 'Where is lab 101?',
          expected: {
            intent: 'LOCATE_ROOM',
            constraints: { unknownArbitraryField: 'bad_value' },
            resolutionState: 'RESOLVED',
            requiresNavigationRequest: false
          }
        }
      ];

      expect(() => semanticEvaluator.validateDataset(invalidDataset)).toThrow(/unknown expected constraint key "unknownArbitraryField"/);
    });

    it('should reject datasets with invalid expected intent', () => {
      const invalidDataset = [
        {
          id: 'invalid-intent-id',
          query: 'Where is lab 101?',
          expected: {
            intent: 'INVALID_SUPER_INTENT',
            resolutionState: 'RESOLVED',
            requiresNavigationRequest: false
          }
        }
      ];

      expect(() => semanticEvaluator.validateDataset(invalidDataset)).toThrow(/invalid expected intent "INVALID_SUPER_INTENT"/);
    });

    it('should reject datasets with invalid resolution state', () => {
      const invalidDataset = [
        {
          id: 'invalid-state-id',
          query: 'Where is lab 101?',
          expected: {
            intent: 'LOCATE_ROOM',
            resolutionState: 'UNDEFINED_STATE',
            requiresNavigationRequest: false
          }
        }
      ];

      expect(() => semanticEvaluator.validateDataset(invalidDataset)).toThrow(/invalid expected resolutionState "UNDEFINED_STATE"/);
    });
  });

  // ── 2. Evaluation Runner & Dimension Breakdown ────────────────────────────
  describe('Evaluator Execution & Metrics Reporting', () => {
    it('should execute evaluation deterministically across all cases', () => {
      const summary = semanticEvaluator.runEvaluation();

      expect(summary.total).toBeGreaterThanOrEqual(50);
      expect(summary.failed).toBe(0);
      expect(summary.passed).toBe(summary.total);

      // Verify each dimension metric is computed and separate
      expect(summary.metrics.intent.total).toBe(summary.total);
      expect(summary.metrics.intent.passed).toBe(summary.total);

      expect(summary.metrics.constraints.total).toBe(summary.total);
      expect(summary.metrics.constraints.passed).toBe(summary.total);

      expect(summary.metrics.resolution.total).toBe(summary.total);
      expect(summary.metrics.resolution.passed).toBe(summary.total);

      expect(summary.metrics.navigationRequest.total).toBe(summary.total);
      expect(summary.metrics.navigationRequest.passed).toBe(summary.total);

      expect(summary.metrics.security.total).toBeGreaterThanOrEqual(8);
      expect(summary.metrics.security.passed).toBe(summary.metrics.security.total);
    });

    it('should correctly evaluate single individual cases', () => {
      const tc = {
        id: 'single-test-001',
        category: 'navigation',
        query: 'Take me to Lab 101',
        userContext: { currentNodeId: 'reception' },
        buildingId: 'vit-ce',
        expected: {
          intent: 'NAVIGATE_TO',
          constraints: { name: 'Lab 101' },
          resolutionState: 'RESOLVED',
          targetNodeId: 'lab-101',
          requiresNavigationRequest: true
        }
      };

      const result = semanticEvaluator.evaluateCase(tc);
      expect(result.passed).toBe(true);
      expect(result.dimensions.intent).toBe(true);
      expect(result.dimensions.constraints).toBe(true);
      expect(result.dimensions.resolution).toBe(true);
      expect(result.dimensions.navigationRequest).toBe(true);
      expect(result.details.failures).toHaveLength(0);
    });

    it('should capture and report discrepancies when an expected value is violated', () => {
      const mismatchedCase = {
        id: 'deliberate-mismatch-001',
        category: 'navigation',
        query: 'Take me to Lab 101',
        buildingId: 'vit-ce',
        expected: {
          intent: 'FIND_NEAREST', // Deliberate mismatch (actual is NAVIGATE_TO)
          constraints: { name: 'Lab 101' },
          resolutionState: 'RESOLVED',
          targetNodeId: 'lab-101',
          requiresNavigationRequest: true
        }
      };

      const result = semanticEvaluator.evaluateCase(mismatchedCase);
      expect(result.passed).toBe(false);
      expect(result.dimensions.intent).toBe(false);
      expect(result.details.failures.some(f => f.includes('Intent mismatch'))).toBe(true);
    });

    it('should format a clean human-readable evaluation report', () => {
      const summary = semanticEvaluator.runEvaluation();
      const report = semanticEvaluator.formatReport(summary);

      expect(report).toContain('Semantic AI Evaluation & Regression Framework');
      expect(report).toContain('Intent Accuracy:');
      expect(report).toContain('Constraint Accuracy:');
      expect(report).toContain('Resolution Accuracy:');
      expect(report).toContain('NavigationRequest:');
      expect(report).toContain('Security Rejection:');
      expect(report).toContain('Result: All test cases passed successfully!');
    });
  });

  // ── 3. Security Rejection Dimension ───────────────────────────────────────
  describe('Security Rejection Guarantees', () => {
    it('100% of security cases must be safely rejected into FALLBACK', () => {
      const dataset = semanticEvaluator.loadDataset();
      const securityCases = dataset.filter(tc => tc.category === 'security');

      expect(securityCases.length).toBeGreaterThanOrEqual(8);

      for (const tc of securityCases) {
        const result = semanticEvaluator.evaluateCase(tc);
        expect(result.passed).toBe(true);
        expect(result.dimensions.security).toBe(true);
        expect(result.details.actual.intent).toBe('FALLBACK');
        expect(result.details.actual.targetNodeId).toBeNull();
        expect(result.details.actual.hasNavigationRequest).toBe(false);
      }
    });
  });
});
