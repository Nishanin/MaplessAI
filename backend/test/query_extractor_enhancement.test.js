const queryExtractorService = require('../src/features/ai/query_extractor.service');
const { validateProviderOutput } = require('../src/features/ai/slm_provider');

/**
 * Phase 7: Natural Language Query Extraction Enhancement Tests (Owner: Surabhi)
 *
 * Tests cover:
 *   1. Campus Natural-Language Variations:
 *      - "Where is the nearest washroom?"
 *      - "Take me to the AI lab."
 *      - "Find an accessible entrance."
 *      - "Where can I find the CSE department?"
 *      - "Locate room 204."
 *      - "Where is the nearest elevator?"
 *      - "Show me the emergency exit."
 *      - "Find a classroom with capacity above 60."
 *      - "Where is the computer lab on the second floor?"
 *   2. Synonyms & Word-Order Variations (washroom/restroom/toilet/lavatory, nearby/closest)
 *   3. Floor & Capacity Normalization
 *   4. Accessibility Phrasing (wheelchair, ramp, step-free)
 *   5. Anti-Overmatching Safeguards (generic bare "room" is flagged as ambiguous)
 *   6. Strict Provider Output Schema Compatibility
 */

describe('Phase 7 — Intent and Entity Extraction Enhancement', () => {
  // ── 1. Target Campus Query Variations ─────────────────────────────────────
  describe('Campus Query Variations', () => {
    it('should extract "Where is the nearest washroom?" correctly', () => {
      const res = queryExtractorService.extractQuery('Where is the nearest washroom?');
      expect(res.intent).toBe('FIND_NEAREST');
      expect(res.constraints.category).toBe('restroom');
      expect(res.confidence).toBeGreaterThanOrEqual(0.85);

      const validated = validateProviderOutput(res);
      expect(validated.valid).toBe(true);
    });

    it('should extract "Take me to the AI lab." correctly', () => {
      const res = queryExtractorService.extractQuery('Take me to the AI lab.');
      expect(res.intent).toBe('NAVIGATE_TO');
      expect(res.constraints.category).toBe('laboratory');
      expect(res.confidence).toBeGreaterThanOrEqual(0.85);

      const validated = validateProviderOutput(res);
      expect(validated.valid).toBe(true);
    });

    it('should extract "Find an accessible entrance." correctly', () => {
      const res = queryExtractorService.extractQuery('Find an accessible entrance.');
      expect(res.intent).toBe('LOCATE_ROOM');
      expect(res.constraints.category).toBe('entrance');
      expect(res.constraints.accessible).toBe(true);
      expect(res.confidence).toBeGreaterThanOrEqual(0.85);

      const validated = validateProviderOutput(res);
      expect(validated.valid).toBe(true);
    });

    it('should extract "Where can I find the CSE department?" correctly', () => {
      const res = queryExtractorService.extractQuery('Where can I find the CSE department?');
      expect(res.intent).toBe('LOCATE_ROOM');
      expect(res.constraints.department).toBe('Computer Engineering');
      expect(res.confidence).toBeGreaterThanOrEqual(0.85);

      const validated = validateProviderOutput(res);
      expect(validated.valid).toBe(true);
    });

    it('should extract "Locate room 204." correctly', () => {
      const res = queryExtractorService.extractQuery('Locate room 204.');
      expect(res.intent).toBe('LOCATE_ROOM');
      expect(res.constraints.name).toBe('Room 204');
      expect(res.confidence).toBeGreaterThanOrEqual(0.85);

      const validated = validateProviderOutput(res);
      expect(validated.valid).toBe(true);
    });

    it('should extract "Where is the nearest elevator?" correctly', () => {
      const res = queryExtractorService.extractQuery('Where is the nearest elevator?');
      expect(res.intent).toBe('FIND_NEAREST');
      expect(res.constraints.category).toBe('elevator');
      expect(res.confidence).toBeGreaterThanOrEqual(0.85);

      const validated = validateProviderOutput(res);
      expect(validated.valid).toBe(true);
    });

    it('should extract "Show me the emergency exit." correctly', () => {
      const res = queryExtractorService.extractQuery('Show me the emergency exit.');
      expect(res.intent).toBe('EMERGENCY_EXIT');
      expect(res.constraints.category).toBe('emergency_exit');
      expect(res.confidence).toBeGreaterThanOrEqual(0.90);

      const validated = validateProviderOutput(res);
      expect(validated.valid).toBe(true);
    });

    it('should extract "Find a classroom with capacity above 60." correctly', () => {
      const res = queryExtractorService.extractQuery('Find a classroom with capacity above 60.');
      expect(res.intent).toBe('LOCATE_ROOM');
      expect(res.constraints.category).toBe('classroom');
      expect(res.constraints.capacityMin).toBe(60);
      expect(res.confidence).toBeGreaterThanOrEqual(0.85);

      const validated = validateProviderOutput(res);
      expect(validated.valid).toBe(true);
    });

    it('should extract "Where is the computer lab on the second floor?" correctly', () => {
      const res = queryExtractorService.extractQuery('Where is the computer lab on the second floor?');
      expect(res.intent).toBe('LOCATE_ROOM');
      expect(res.constraints.category).toBe('laboratory');
      expect(res.constraints.floor).toBe(2);
      expect(res.confidence).toBeGreaterThanOrEqual(0.85);

      const validated = validateProviderOutput(res);
      expect(validated.valid).toBe(true);
    });
  });

  // ── 2. Synonyms & Variations ──────────────────────────────────────────────
  describe('Synonyms & Phrasing Variations', () => {
    it('should map washroom, toilet, lavatory synonyms to category "restroom"', () => {
      const queries = [
        'Find a nearby washroom',
        'Where is the closest toilet?',
        'Locate the lavatory'
      ];
      for (const q of queries) {
        const res = queryExtractorService.extractQuery(q);
        expect(res.constraints.category).toBe('restroom');
      }
    });

    it('should map "nearby", "closest", and "nearest" to FIND_NEAREST', () => {
      expect(queryExtractorService.extractQuery('nearby elevator').intent).toBe('FIND_NEAREST');
      expect(queryExtractorService.extractQuery('closest elevator').intent).toBe('FIND_NEAREST');
      expect(queryExtractorService.extractQuery('nearest elevator').intent).toBe('FIND_NEAREST');
    });

    it('should map wheelchair, ramp, and step-free to accessible constraint', () => {
      const queries = [
        'wheelchair accessible lab',
        'entrance with ramp access',
        'step-free elevator'
      ];
      for (const q of queries) {
        const res = queryExtractorService.extractQuery(q);
        expect(res.constraints.accessible).toBe(true);
      }
    });

    it('should map room codes like A-204 and rm 101 correctly', () => {
      const res1 = queryExtractorService.extractQuery('Take me to room A-204');
      expect(res1.constraints.name).toBe('Room A-204');

      const res2 = queryExtractorService.extractQuery('Where is rm 101?');
      expect(res2.constraints.name).toBe('Room 101');
    });
  });

  // ── 3. Floor & Capacity Expressions ───────────────────────────────────────
  describe('Floor and Capacity Normalization', () => {
    it('should normalize floor expressions: ground, 1st, second, 3rd, basement', () => {
      expect(queryExtractorService.extractQuery('elevator on ground floor').constraints.floor).toBe(0);
      expect(queryExtractorService.extractQuery('lab on 1st floor').constraints.floor).toBe(1);
      expect(queryExtractorService.extractQuery('staircase on floor 2').constraints.floor).toBe(2);
      expect(queryExtractorService.extractQuery('room on third floor').constraints.floor).toBe(3);
      expect(queryExtractorService.extractQuery('storage in basement').constraints.floor).toBe(-1);
    });

    it('should normalize capacity expressions: above 60, more than 45 seats, 50+ capacity', () => {
      expect(queryExtractorService.extractQuery('classroom with capacity above 60').constraints.capacityMin).toBe(60);
      expect(queryExtractorService.extractQuery('hall with more than 45 seats').constraints.capacityMin).toBe(45);
      expect(queryExtractorService.extractQuery('lab with 50+ capacity').constraints.capacityMin).toBe(50);
    });
  });

  // ── 4. Anti-Overmatching Safeguards ───────────────────────────────────────
  describe('Anti-Overmatching Safeguards', () => {
    it('should NOT treat generic bare "room" as a valid destination', () => {
      const res = queryExtractorService.extractQuery('Where is the room?');
      expect(res.ambiguity).toBe(true);
      expect(res.confidence).toBeLessThanOrEqual(0.5);
      expect(res.constraints.name).toBeUndefined();
    });

    it('should NOT treat "take me there" as a clear destination', () => {
      const res = queryExtractorService.extractQuery('Take me there');
      expect(res.intent).toBe('NAVIGATE_TO');
      expect(res.ambiguity).toBe(true);
      expect(res.confidence).toBeLessThanOrEqual(0.65);
    });

    it('should never emit targetNodeId from extractor', () => {
      const res = queryExtractorService.extractQuery('Take me to Lab 101');
      expect(res).not.toHaveProperty('targetNodeId');
    });
  });

  // ── 5. Schema & Provider Validation Compatibility ─────────────────────────
  describe('Schema & Provider Output Validation Adherence', () => {
    it('all extracted results must be strictly schema-valid under validateProviderOutput', () => {
      const testQueries = [
        'Where is the nearest washroom?',
        'Take me to the AI lab.',
        'Find an accessible entrance.',
        'Where can I find the CSE department?',
        'Locate room 204.',
        'Where is the nearest elevator?',
        'Show me the emergency exit.',
        'Find a classroom with capacity above 60.',
        'Where is the computer lab on the second floor?'
      ];

      for (const q of testQueries) {
        const extracted = queryExtractorService.extractQuery(q);
        const validated = validateProviderOutput(extracted);
        if (!validated.valid) {
          console.error(`Validation failed for query "${q}":`, validated.errors);
        }
        expect(validated.valid).toBe(true);
        expect(validated.errors).toHaveLength(0);
      }
    });
  });
});
