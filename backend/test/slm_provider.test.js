const {
  BaseSlmProvider,
  validateProviderOutput,
  getSlmProvider,
  ALLOWED_INTENTS,
  ALLOWED_PROVIDERS
} = require('../src/features/ai/slm_provider');
const { MockSlmProvider } = require('../src/features/ai/mock_slm_provider');

/**
 * SLM Provider & Output Validator Unit Tests (Owner: Surabhi)
 *
 * Tests cover:
 *   1. Provider Behavior
 *   2. Strict Output Validation
 *   3. Provider Selection & Security
 */

describe('SLM Provider & Validator — Unit Tests', () => {
  // ── 1. Provider Behavior ──────────────────────────────────────────────────
  describe('Provider Behavior', () => {
    it('should return deterministic structured output for valid query', async () => {
      const provider = getSlmProvider('deterministic');
      const result = await provider.generateStructuredQuery({
        text: 'Where is the nearest lab?'
      });

      expect(result).toBeDefined();
      expect(result.intent).toBe('FIND_NEAREST');
      expect(result.constraints.category).toBe('laboratory');
      expect(result.confidence).toBeGreaterThanOrEqual(0.8);
      expect(result.ambiguity).toBe(false);
      expect(Array.isArray(result.entities)).toBe(true);
      expect(typeof result.reason).toBe('string');
    });

    it('mock provider should be an instance of BaseSlmProvider', () => {
      const mockProvider = MockSlmProvider.getInstance();
      expect(mockProvider instanceof BaseSlmProvider).toBe(true);
    });

    it('mock provider should support custom mock responses in unit tests', async () => {
      const mockProvider = MockSlmProvider.getInstance();
      mockProvider.setMockResponse({
        intent: 'QUERY_INFO',
        entities: [{ type: 'facility', value: 'wifiZone' }],
        constraints: { facility: 'wifiZone' },
        confidence: 0.95,
        ambiguity: false,
        reason: 'mocked test response'
      });

      const result = await mockProvider.generateStructuredQuery({ text: 'anything' });
      expect(result.intent).toBe('QUERY_INFO');
      expect(result.confidence).toBe(0.95);

      mockProvider.clearMockResponse();

      // Restores default behavior
      const defaultResult = await mockProvider.generateStructuredQuery({ text: 'emergency exit' });
      expect(defaultResult.intent).toBe('EMERGENCY_EXIT');
    });

    it('BaseSlmProvider abstract method throws when called directly', async () => {
      const base = new BaseSlmProvider();
      await expect(base.generateStructuredQuery({ text: 'test' })).rejects.toThrow(
        /must be implemented/i
      );
    });
  });

  // ── 2. Output Validation & Sanitization ───────────────────────────────────
  describe('Provider Output Validation', () => {
    it('should accept valid, well-formed provider output', () => {
      const validPayload = {
        intent: 'FIND_NEAREST',
        entities: [{ type: 'category', value: 'laboratory' }],
        constraints: { category: 'laboratory', accessible: true },
        confidence: 0.85,
        ambiguity: false,
        reason: 'valid laboratory query'
      };

      const result = validateProviderOutput(validPayload);
      expect(result.valid).toBe(true);
      expect(result.errors).toHaveLength(0);
      expect(result.normalized).toEqual(validPayload);
    });

    it('should reject non-object or null provider outputs', () => {
      expect(validateProviderOutput(null).valid).toBe(false);
      expect(validateProviderOutput(undefined).valid).toBe(false);
      expect(validateProviderOutput('some string').valid).toBe(false);
      expect(validateProviderOutput([1, 2, 3]).valid).toBe(false);
    });

    it('should reject unsupported intent values', () => {
      const payload = {
        intent: 'UNSUPPORTED_INTENT_123',
        entities: [],
        constraints: {},
        confidence: 0.8,
        ambiguity: false,
        reason: 'test'
      };

      const result = validateProviderOutput(payload);
      expect(result.valid).toBe(false);
      expect(result.errors.some(e => e.includes('Invalid intent'))).toBe(true);
    });

    it('should reject unsupported entity types', () => {
      const payload = {
        intent: 'LOCATE_ROOM',
        entities: [{ type: 'unsupported_entity_type', value: 'foo' }],
        constraints: {},
        confidence: 0.8,
        ambiguity: false,
        reason: 'test'
      };

      const result = validateProviderOutput(payload);
      expect(result.valid).toBe(false);
      expect(result.errors.some(e => e.includes('Unsupported entity type'))).toBe(true);
    });

    it('should reject non-whitelisted constraint fields', () => {
      const payload = {
        intent: 'LOCATE_ROOM',
        entities: [],
        constraints: {
          arbitraryInjection: 'DROP TABLE',
          __proto__: { evil: true }
        },
        confidence: 0.8,
        ambiguity: false,
        reason: 'test'
      };

      const result = validateProviderOutput(payload);
      expect(result.valid).toBe(false);
      expect(result.errors.some(e => e.includes('Unknown constraint field'))).toBe(true);
    });

    it('should reject out-of-range or non-numeric confidence values', () => {
      const testCases = [-0.1, 1.1, NaN, 'high', null];
      for (const conf of testCases) {
        const payload = {
          intent: 'FALLBACK',
          entities: [],
          constraints: {},
          confidence: conf,
          ambiguity: false,
          reason: 'test'
        };
        const result = validateProviderOutput(payload);
        expect(result.valid).toBe(false);
        expect(result.errors.some(e => e.includes('Invalid confidence'))).toBe(true);
      }
    });

    it('should reject non-boolean ambiguity values', () => {
      const payload = {
        intent: 'FALLBACK',
        entities: [],
        constraints: {},
        confidence: 0.5,
        ambiguity: 'yes', // not a boolean
        reason: 'test'
      };
      const result = validateProviderOutput(payload);
      expect(result.valid).toBe(false);
      expect(result.errors.some(e => e.includes('Invalid ambiguity'))).toBe(true);
    });

    it('SECURITY: should reject any provider attempt to dictate targetNodeId', () => {
      const payload = {
        intent: 'FIND_NEAREST',
        entities: [{ type: 'category', value: 'laboratory' }],
        constraints: { category: 'laboratory' },
        targetNodeId: 'lab-101', // Providers are FORBIDDEN from deciding targetNodeId!
        confidence: 0.85,
        ambiguity: false,
        reason: 'sneaky provider'
      };

      const result = validateProviderOutput(payload);
      expect(result.valid).toBe(false);
      expect(result.errors.some(e => e.includes('Security violation'))).toBe(true);
    });
  });

  // ── 3. Provider Selection & Configuration ─────────────────────────────────
  describe('Provider Selection & Security', () => {
    it('should return deterministic provider by default', () => {
      const provider = getSlmProvider();
      expect(provider).toBeDefined();
      expect(typeof provider.generateStructuredQuery).toBe('function');
    });

    it('should allow selecting mock provider explicitly', () => {
      const provider = getSlmProvider('mock');
      expect(provider).toBeDefined();
      expect(provider instanceof BaseSlmProvider).toBe(true);
    });

    it('should throw controlled error for unknown or arbitrary provider names', () => {
      const dangerousNames = [
        '../../evil_module',
        'http://remote.ai/api',
        'chatgpt_v5',
        'arbitrary'
      ];

      for (const name of dangerousNames) {
        expect(() => getSlmProvider(name)).toThrow(/Unsupported SLM provider/i);
      }
    });

    it('allowed providers list should be strictly controlled', () => {
      expect(ALLOWED_PROVIDERS).toEqual(['deterministic', 'mock']);
    });
  });
});
