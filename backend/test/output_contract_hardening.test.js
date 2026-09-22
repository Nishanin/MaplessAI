const request = require('supertest');
const app = require('../src/app');
const { validateContract } = require('../src/utils/schema_validator');
const {
  validateProviderOutput,
  validateSemanticConsistency,
  ALLOWED_INTENTS,
  ALLOWED_ENTITY_TYPES,
  ALLOWED_CONSTRAINTS
} = require('../src/features/ai/slm_provider');
const { MockSlmProvider } = require('../src/features/ai/mock_slm_provider');

/**
 * Phase 6: Structured Output Contract Hardening Tests (Owner: Surabhi)
 *
 * Tests cover:
 *   1.  Missing required fields
 *   2.  Incorrect field types
 *   3.  Unknown / additional fields rejection
 *   4.  Invalid intent values
 *   5.  Invalid entity types
 *   6.  Invalid / non-whitelisted constraints
 *   7.  Invalid confidence values
 *   8.  Invalid ambiguity values
 *   9.  Forbidden targetNodeId rejection
 *   10. Semantic consistency (invalid intent/entity combinations)
 *   11. Valid outputs for every supported intent
 *   12. Security scanning (SQL, scripts, URLs, commands)
 *   13. Controller fallback behavior for invalid provider outputs
 *   14. Formal contract schema test (contracts/slm-provider-output.schema.json)
 */

describe('Phase 6 — Structured Output Contract Hardening', () => {
  // ── 1. Formal Schema Contract Adherence ───────────────────────────────────
  describe('Formal JSON Schema (slm-provider-output.schema.json)', () => {
    it('should validate a compliant provider output against slm-provider-output.schema.json', () => {
      const validSample = {
        intent: 'FIND_NEAREST',
        entities: [{ type: 'category', value: 'laboratory' }],
        constraints: { category: 'laboratory', accessible: true },
        confidence: 0.85,
        ambiguity: false,
        reason: 'valid nearest lab request'
      };

      const result = validateContract('slm-provider-output', validSample);
      expect(result.valid).toBe(true);
      expect(result.errors).toEqual([]);
    });

    it('should reject when required fields are missing from schema', () => {
      const missingIntent = {
        entities: [],
        constraints: {},
        confidence: 0.5,
        ambiguity: false
      };
      expect(validateContract('slm-provider-output', missingIntent).valid).toBe(false);

      const missingAmbiguity = {
        intent: 'FALLBACK',
        entities: [],
        constraints: {},
        confidence: 0.0
      };
      expect(validateContract('slm-provider-output', missingAmbiguity).valid).toBe(false);
    });

    it('should reject unexpected additional properties in schema', () => {
      const unexpected = {
        intent: 'FALLBACK',
        entities: [],
        constraints: {},
        confidence: 0.0,
        ambiguity: false,
        unexpectedProperty: 'malicious'
      };
      const result = validateContract('slm-provider-output', unexpected);
      expect(result.valid).toBe(false);
    });
  });

  // ── 2. Missing Required Fields ────────────────────────────────────────────
  describe('Missing Required Fields', () => {
    it('should reject output missing intent', () => {
      const res = validateProviderOutput({
        entities: [],
        constraints: {},
        confidence: 0.8,
        ambiguity: false
      });
      expect(res.valid).toBe(false);
      expect(res.errors.some(e => e.includes('intent'))).toBe(true);
    });

    it('should reject output missing entities', () => {
      const res = validateProviderOutput({
        intent: 'FALLBACK',
        constraints: {},
        confidence: 0.0,
        ambiguity: false
      });
      expect(res.valid).toBe(false);
      expect(res.errors.some(e => e.includes('entities'))).toBe(true);
    });

    it('should reject output missing confidence', () => {
      const res = validateProviderOutput({
        intent: 'FALLBACK',
        entities: [],
        constraints: {},
        ambiguity: false
      });
      expect(res.valid).toBe(false);
      expect(res.errors.some(e => e.includes('confidence'))).toBe(true);
    });

    it('should reject output missing ambiguity', () => {
      const res = validateProviderOutput({
        intent: 'FALLBACK',
        entities: [],
        constraints: {},
        confidence: 0.0
      });
      expect(res.valid).toBe(false);
      expect(res.errors.some(e => e.includes('ambiguity'))).toBe(true);
    });
  });

  // ── 3. Incorrect Field Types ──────────────────────────────────────────────
  describe('Incorrect Field Types', () => {
    it('should reject non-string intent', () => {
      const res = validateProviderOutput({
        intent: 12345,
        entities: [],
        constraints: {},
        confidence: 0.5,
        ambiguity: false
      });
      expect(res.valid).toBe(false);
      expect(res.errors.some(e => e.includes('Invalid intent'))).toBe(true);
    });

    it('should reject non-array entities', () => {
      const res = validateProviderOutput({
        intent: 'FALLBACK',
        entities: { type: 'category', value: 'lab' },
        constraints: {},
        confidence: 0.0,
        ambiguity: false
      });
      expect(res.valid).toBe(false);
      expect(res.errors.some(e => e.includes('entities'))).toBe(true);
    });

    it('should reject non-object constraints', () => {
      const res = validateProviderOutput({
        intent: 'FALLBACK',
        entities: [],
        constraints: 'invalid-string-constraint',
        confidence: 0.0,
        ambiguity: false
      });
      expect(res.valid).toBe(false);
      expect(res.errors.some(e => e.includes('constraints'))).toBe(true);
    });

    it('should reject non-boolean ambiguity', () => {
      const res = validateProviderOutput({
        intent: 'FALLBACK',
        entities: [],
        constraints: {},
        confidence: 0.0,
        ambiguity: 'false' // string, not boolean
      });
      expect(res.valid).toBe(false);
      expect(res.errors.some(e => e.includes('ambiguity'))).toBe(true);
    });

    it('should reject out-of-range confidence', () => {
      expect(validateProviderOutput({ intent: 'FALLBACK', entities: [], constraints: {}, confidence: -0.5, ambiguity: false }).valid).toBe(false);
      expect(validateProviderOutput({ intent: 'FALLBACK', entities: [], constraints: {}, confidence: 1.5, ambiguity: false }).valid).toBe(false);
      expect(validateProviderOutput({ intent: 'FALLBACK', entities: [], constraints: {}, confidence: 'high', ambiguity: false }).valid).toBe(false);
    });
  });

  // ── 4. Unknown & Forbidden Fields ─────────────────────────────────────────
  describe('Unknown & Forbidden Fields', () => {
    it('should reject provider attempting to supply targetNodeId', () => {
      const res = validateProviderOutput({
        intent: 'FIND_NEAREST',
        entities: [{ type: 'category', value: 'laboratory' }],
        constraints: { category: 'laboratory' },
        targetNodeId: 'lab-101', // Strictly forbidden!
        confidence: 0.9,
        ambiguity: false
      });
      expect(res.valid).toBe(false);
      expect(res.errors.some(e => e.includes('Security violation'))).toBe(true);
    });

    it('should reject unknown top-level fields', () => {
      const res = validateProviderOutput({
        intent: 'FALLBACK',
        entities: [],
        constraints: {},
        confidence: 0.0,
        ambiguity: false,
        arbitraryField: 'injected'
      });
      expect(res.valid).toBe(false);
      expect(res.errors.some(e => e.includes('arbitraryField'))).toBe(true);
    });

    it('should reject non-whitelisted constraint fields', () => {
      const res = validateProviderOutput({
        intent: 'LOCATE_ROOM',
        entities: [{ type: 'room_name', value: 'Lab 101' }],
        constraints: {
          name: 'Lab 101',
          forbiddenSql: 'DROP TABLE'
        },
        confidence: 0.8,
        ambiguity: false
      });
      expect(res.valid).toBe(false);
      expect(res.errors.some(e => e.includes('forbiddenSql'))).toBe(true);
    });
  });

  // ── 5. Security Scanning (SQL, Scripts, URLs, Commands) ───────────────────
  describe('Security & Injection Scanning', () => {
    it('should detect and reject SQL statements in string values', () => {
      const sqlInEntity = {
        intent: 'LOCATE_ROOM',
        entities: [{ type: 'room_name', value: 'Lab 101; SELECT * FROM users' }],
        constraints: { name: 'Lab 101' },
        confidence: 0.8,
        ambiguity: false
      };
      const res = validateProviderOutput(sqlInEntity);
      expect(res.valid).toBe(false);
      expect(res.errors.some(e => e.includes('SQL statement'))).toBe(true);
    });

    it('should detect and reject script tags in string values', () => {
      const scriptInReason = {
        intent: 'FALLBACK',
        entities: [],
        constraints: {},
        confidence: 0.0,
        ambiguity: false,
        reason: '<script>alert("xss")</script>'
      };
      const res = validateProviderOutput(scriptInReason);
      expect(res.valid).toBe(false);
      expect(res.errors.some(e => e.includes('Script tag'))).toBe(true);
    });

    it('should detect and reject URLs in string values', () => {
      const urlInConstraint = {
        intent: 'LOCATE_ROOM',
        entities: [{ type: 'room_name', value: 'Lab' }],
        constraints: { name: 'http://malicious.endpoint/steal' },
        confidence: 0.8,
        ambiguity: false
      };
      const res = validateProviderOutput(urlInConstraint);
      expect(res.valid).toBe(false);
      expect(res.errors.some(e => e.includes('URL'))).toBe(true);
    });

    it('should detect and reject shell commands in string values', () => {
      const shellInEntity = {
        intent: 'LOCATE_ROOM',
        entities: [{ type: 'room_name', value: 'rm -rf /' }],
        constraints: { name: 'rm -rf /' },
        confidence: 0.8,
        ambiguity: false
      };
      const res = validateProviderOutput(shellInEntity);
      expect(res.valid).toBe(false);
      expect(res.errors.some(e => e.includes('Shell command'))).toBe(true);
    });
  });

  // ── 6. Semantic Consistency Validation ────────────────────────────────────
  describe('Semantic Consistency Rules', () => {
    it('NAVIGATE_TO without destination entity or constraint must be rejected', () => {
      const res = validateProviderOutput({
        intent: 'NAVIGATE_TO',
        entities: [],
        constraints: {},
        confidence: 0.9,
        ambiguity: false
      });
      expect(res.valid).toBe(false);
      expect(res.errors.some(e => e.includes('Semantic consistency violation: NAVIGATE_TO'))).toBe(true);
    });

    it('FIND_NEAREST without target category/facility must be rejected', () => {
      const res = validateProviderOutput({
        intent: 'FIND_NEAREST',
        entities: [],
        constraints: {},
        confidence: 0.9,
        ambiguity: false
      });
      expect(res.valid).toBe(false);
      expect(res.errors.some(e => e.includes('Semantic consistency violation: FIND_NEAREST'))).toBe(true);
    });

    it('LOCATE_ROOM without room-related entity/constraint must be rejected', () => {
      const res = validateProviderOutput({
        intent: 'LOCATE_ROOM',
        entities: [],
        constraints: {},
        confidence: 0.9,
        ambiguity: false
      });
      expect(res.valid).toBe(false);
      expect(res.errors.some(e => e.includes('Semantic consistency violation: LOCATE_ROOM'))).toBe(true);
    });

    it('EMERGENCY_EXIT targeting an unrelated specific room must be rejected', () => {
      const res = validateProviderOutput({
        intent: 'EMERGENCY_EXIT',
        entities: [{ type: 'room_name', value: 'Lab 101' }],
        constraints: { name: 'Lab 101' }, // Unrelated room without emergency_exit category
        confidence: 0.9,
        ambiguity: false
      });
      expect(res.valid).toBe(false);
      expect(res.errors.some(e => e.includes('Semantic consistency violation: EMERGENCY_EXIT'))).toBe(true);
    });
  });

  // ── 7. Valid Outputs for Every Supported Intent ───────────────────────────
  describe('Valid Outputs for Every Supported Intent', () => {
    it('should accept valid FIND_NEAREST output', () => {
      const res = validateProviderOutput({
        intent: 'FIND_NEAREST',
        entities: [{ type: 'category', value: 'elevator' }],
        constraints: { category: 'elevator' },
        confidence: 0.85,
        ambiguity: false,
        reason: 'find nearest elevator'
      });
      expect(res.valid).toBe(true);
    });

    it('should accept valid NAVIGATE_TO output', () => {
      const res = validateProviderOutput({
        intent: 'NAVIGATE_TO',
        entities: [{ type: 'alias', value: 'Software Lab 1' }],
        constraints: { alias: 'Software Lab 1' },
        confidence: 0.9,
        ambiguity: false,
        reason: 'navigate to software lab'
      });
      expect(res.valid).toBe(true);
    });

    it('should accept valid LOCATE_ROOM output', () => {
      const res = validateProviderOutput({
        intent: 'LOCATE_ROOM',
        entities: [{ type: 'room_name', value: 'Department Library' }],
        constraints: { name: 'Department Library' },
        confidence: 0.85,
        ambiguity: false,
        reason: 'locate library'
      });
      expect(res.valid).toBe(true);
    });

    it('should accept valid QUERY_INFO output', () => {
      const res = validateProviderOutput({
        intent: 'QUERY_INFO',
        entities: [{ type: 'facility', value: 'wifiZone' }],
        constraints: { facility: 'wifiZone' },
        confidence: 0.75,
        ambiguity: false,
        reason: 'wifi info'
      });
      expect(res.valid).toBe(true);
    });

    it('should accept valid EMERGENCY_EXIT output', () => {
      const res = validateProviderOutput({
        intent: 'EMERGENCY_EXIT',
        entities: [{ type: 'category', value: 'emergency_exit' }],
        constraints: { category: 'emergency_exit' },
        confidence: 0.95,
        ambiguity: false,
        reason: 'emergency evacuation'
      });
      expect(res.valid).toBe(true);
    });

    it('should accept valid FALLBACK output', () => {
      const res = validateProviderOutput({
        intent: 'FALLBACK',
        entities: [],
        constraints: {},
        confidence: 0.0,
        ambiguity: false,
        reason: 'off topic query'
      });
      expect(res.valid).toBe(true);
    });
  });

  // ── 8. Controller Fallback Integration on Invalid Provider Output ─────────
  describe('Controller Fallback on Invalid Provider Output', () => {
    let mockProvider;

    beforeEach(() => {
      mockProvider = MockSlmProvider.getInstance();
    });

    afterEach(() => {
      mockProvider.clearMockResponse();
    });

    it('should produce safe schema-valid FALLBACK when provider output is semantically inconsistent', async () => {
      // Inconsistent: NAVIGATE_TO with no destination entity
      mockProvider.setMockResponse({
        intent: 'NAVIGATE_TO',
        entities: [],
        constraints: {},
        confidence: 0.9,
        ambiguity: false,
        reason: 'broken provider'
      });

      const response = await request(app)
        .post('/api/v1/ai/query')
        .send({ text: 'take me there', buildingId: 'vit-ce' });

      expect(response.statusCode).toBe(200);
      expect(response.body.intent).toBe('FALLBACK');
      expect(response.body.targetNodeId).toBeNull();
      expect(response.body.confidence).toBe(0.0);

      const contractCheck = validateContract('ai-response', response.body);
      expect(contractCheck.valid).toBe(true);
    });

    it('should produce safe schema-valid FALLBACK when provider output contains forbidden targetNodeId', async () => {
      mockProvider.setMockResponse({
        intent: 'FIND_NEAREST',
        entities: [{ type: 'category', value: 'laboratory' }],
        constraints: { category: 'laboratory' },
        targetNodeId: 'lab-101', // Forbidden!
        confidence: 0.9,
        ambiguity: false,
        reason: 'sneaky provider'
      });

      const response = await request(app)
        .post('/api/v1/ai/query')
        .send({ text: 'Where is lab?', buildingId: 'vit-ce' });

      expect(response.statusCode).toBe(200);
      expect(response.body.intent).toBe('FALLBACK');
      expect(response.body.targetNodeId).toBeNull();
      expect(response.body.confidence).toBe(0.0);

      const contractCheck = validateContract('ai-response', response.body);
      expect(contractCheck.valid).toBe(true);
    });

    it('should produce safe schema-valid FALLBACK when provider output contains SQL injection', async () => {
      mockProvider.setMockResponse({
        intent: 'LOCATE_ROOM',
        entities: [{ type: 'room_name', value: "Lab 101'; DROP TABLE nodes; --" }],
        constraints: { name: 'Lab 101' },
        confidence: 0.8,
        ambiguity: false,
        reason: 'injection attempt'
      });

      const response = await request(app)
        .post('/api/v1/ai/query')
        .send({ text: 'Where is Lab 101?', buildingId: 'vit-ce' });

      expect(response.statusCode).toBe(200);
      expect(response.body.intent).toBe('FALLBACK');
      expect(response.body.targetNodeId).toBeNull();

      const contractCheck = validateContract('ai-response', response.body);
      expect(contractCheck.valid).toBe(true);
    });
  });
});
