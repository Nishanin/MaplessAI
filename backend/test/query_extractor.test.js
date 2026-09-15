const queryExtractorService = require('../src/features/ai/query_extractor.service');

/**
 * QueryExtractorService Unit Tests (Owner: Surabhi)
 *
 * Tests cover:
 *   1. Intent extraction (navigation, nearest, emergency exit, accessible, unsupported, case-insensitivity)
 *   2. Entity extraction (lab, elevator, emergency exit, library, known alias, unknown entity)
 *   3. Constraint extraction (category, accessibility, facility, department, floor, no arbitrary fields)
 *   4. Safety and quality (empty text, whitespace, contradictory request, no invented node IDs, SQL/command injection safe, confidence in [0, 1])
 */

describe('QueryExtractorService — Unit Tests', () => {
  // ── 1. Intent Extraction ──────────────────────────────────────────────────
  describe('Intent Extraction', () => {
    it('should extract EMERGENCY_EXIT intent for emergency phrases', () => {
      const phrases = [
        'Find the emergency exit',
        'I need to evacuate now',
        'Where is the fire exit?',
        'Emergency evacuation door'
      ];
      for (const text of phrases) {
        const result = queryExtractorService.extractQuery(text);
        expect(result.intent).toBe('EMERGENCY_EXIT');
        expect(result.confidence).toBeGreaterThanOrEqual(0.8);
        expect(typeof result.reason).toBe('string');
      }
    });

    it('should extract FIND_NEAREST intent for nearest/closest phrases', () => {
      const res1 = queryExtractorService.extractQuery('Where is the nearest lab?');
      expect(res1.intent).toBe('FIND_NEAREST');
      expect(res1.constraints.category).toBe('laboratory');

      const res2 = queryExtractorService.extractQuery('Take me to the closest elevator');
      expect(res2.intent).toBe('FIND_NEAREST');
      expect(res2.constraints.category).toBe('elevator');
    });

    it('should extract NAVIGATE_TO intent for navigation phrases', () => {
      const res1 = queryExtractorService.extractQuery('Take me to the library');
      expect(res1.intent).toBe('NAVIGATE_TO');

      const res2 = queryExtractorService.extractQuery('Navigate to Software Lab 1');
      expect(res2.intent).toBe('NAVIGATE_TO');
      expect(res2.constraints.alias).toBe('Software Lab 1');
    });

    it('should extract LOCATE_ROOM intent for location queries', () => {
      const res = queryExtractorService.extractQuery('Where is Lab 101?');
      expect(res.intent).toBe('LOCATE_ROOM');
      expect(res.constraints.name).toBe('Lab 101');
    });

    it('should extract QUERY_INFO intent for facility and amenity queries', () => {
      const res = queryExtractorService.extractQuery('Is there wifi here?');
      expect(res.intent).toBe('QUERY_INFO');
      expect(res.constraints.facility).toBe('wifiZone');
    });

    it('should return FALLBACK for unsupported or off-topic queries', () => {
      const queries = [
        'Tell me a joke',
        'What is 2 + 2?',
        'Who is the prime minister of Canada?',
        'Sing a song'
      ];
      for (const text of queries) {
        const result = queryExtractorService.extractQuery(text);
        expect(result.intent).toBe('FALLBACK');
        expect(result.confidence).toBeLessThan(0.5);
      }
    });

    it('should handle case-insensitivity across mixed uppercase and lowercase', () => {
      const res = queryExtractorService.extractQuery('FiNd ThE nEaReSt ElEvAtOr');
      expect(res.intent).toBe('FIND_NEAREST');
      expect(res.constraints.category).toBe('elevator');
    });
  });

  // ── 2. Entity Extraction ──────────────────────────────────────────────────
  describe('Entity Extraction', () => {
    it('should extract laboratory entity correctly', () => {
      const res = queryExtractorService.extractQuery('Find the nearest computer lab');
      expect(res.entities).toEqual(
        expect.arrayContaining([{ type: 'category', value: 'laboratory' }])
      );
    });

    it('should extract elevator entity correctly', () => {
      const res = queryExtractorService.extractQuery('Where is the lift?');
      expect(res.entities).toEqual(
        expect.arrayContaining([{ type: 'category', value: 'elevator' }])
      );
    });

    it('should extract emergency exit entity correctly', () => {
      const res = queryExtractorService.extractQuery('Evacuate to emergency exit');
      expect(res.entities).toEqual(
        expect.arrayContaining([{ type: 'category', value: 'emergency_exit' }])
      );
    });

    it('should extract known alias entities correctly', () => {
      const res1 = queryExtractorService.extractQuery('Where is Software Lab 1?');
      expect(res1.entities).toEqual(
        expect.arrayContaining([{ type: 'alias', value: 'Software Lab 1' }])
      );

      const res2 = queryExtractorService.extractQuery('Take me to the Help Desk');
      expect(res2.entities).toEqual(
        expect.arrayContaining([{ type: 'alias', value: 'Help Desk' }])
      );
    });

    it('should extract department entities correctly', () => {
      const res = queryExtractorService.extractQuery('Where is Computer Engineering?');
      expect(res.entities).toEqual(
        expect.arrayContaining([{ type: 'department', value: 'Computer Engineering' }])
      );
    });
  });

  // ── 3. Constraint Extraction ──────────────────────────────────────────────
  describe('Constraint Extraction', () => {
    it('should extract category constraint', () => {
      const res = queryExtractorService.extractQuery('Find nearest elevator');
      expect(res.constraints.category).toBe('elevator');
    });

    it('should extract accessible constraint from text keywords', () => {
      const res = queryExtractorService.extractQuery('Where is the wheelchair accessible lab?');
      expect(res.constraints.accessible).toBe(true);
      expect(res.constraints.category).toBe('laboratory');
    });

    it('should extract accessible constraint from userContext', () => {
      const res = queryExtractorService.extractQuery('Where is the lab?', { accessible: true });
      expect(res.constraints.accessible).toBe(true);
      expect(res.constraints.category).toBe('laboratory');
    });

    it('should extract facility constraint', () => {
      const res1 = queryExtractorService.extractQuery('Find a room with wifi');
      expect(res1.constraints.facility).toBe('wifiZone');

      const res2 = queryExtractorService.extractQuery('Where is a room with a projector?');
      expect(res2.constraints.facility).toBe('projectorAvailable');
    });

    it('should extract floor constraint', () => {
      const res = queryExtractorService.extractQuery('Where is the lab on floor 1?');
      expect(res.constraints.floor).toBe(1);
    });

    it('should never include arbitrary or non-whitelisted constraint fields', () => {
      const allowed = new Set([
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

      const testQueries = [
        'Find nearest lab',
        'Where is floor 1 elevator?',
        'Room with wifi and accessible ramp',
        'Take me to Help Desk'
      ];

      for (const q of testQueries) {
        const res = queryExtractorService.extractQuery(q);
        for (const key of Object.keys(res.constraints)) {
          expect(allowed.has(key)).toBe(true);
        }
      }
    });
  });

  // ── 4. Safety, Quality & Edge Cases ───────────────────────────────────────
  describe('Safety, Quality & Edge Cases', () => {
    it('should handle empty string gracefully', () => {
      const res = queryExtractorService.extractQuery('');
      expect(res.intent).toBe('FALLBACK');
      expect(res.confidence).toBe(0.0);
      expect(res.ambiguity).toBe(false);
      expect(res.reason).toMatch(/empty/i);
    });

    it('should handle whitespace-only string gracefully', () => {
      const res = queryExtractorService.extractQuery('    \t\n   ');
      expect(res.intent).toBe('FALLBACK');
      expect(res.confidence).toBe(0.0);
      expect(res.ambiguity).toBe(false);
      expect(res.reason).toMatch(/empty/i);
    });

    it('should flag contradictory or multi-category queries as ambiguous', () => {
      const res = queryExtractorService.extractQuery('Find the nearest emergency exit and elevator');
      expect(res.intent).toBe('FALLBACK');
      expect(res.ambiguity).toBe(true);
      expect(res.confidence).toBeLessThan(0.5);
      expect(res.reason).toMatch(/contradictory|conflicting/i);
    });

    it('should flag underspecified navigation as ambiguous', () => {
      const res = queryExtractorService.extractQuery('Take me there please');
      expect(res.intent).toBe('NAVIGATE_TO');
      expect(res.ambiguity).toBe(true);
      expect(res.reason).toMatch(/without/i);
    });

    it('should never invent node IDs during extraction', () => {
      const res = queryExtractorService.extractQuery('Where is the secret lab?');
      expect(res.constraints.nodeId).toBeUndefined();
    });

    it('should treat SQL injection attempts as unsupported requests without errors', () => {
      const maliciousQueries = [
        "SELECT * FROM nodes WHERE id = 'lab-101'",
        "'; DROP TABLE buildings; --",
        "UNION ALL SELECT password FROM users"
      ];
      for (const q of maliciousQueries) {
        const res = queryExtractorService.extractQuery(q);
        expect(res.intent).toBe('FALLBACK');
        expect(res.confidence).toBe(0.0);
        expect(res.constraints).toEqual({});
      }
    });

    it('confidence must always be within [0.0, 1.0]', () => {
      const queries = [
        'nearest lab',
        'take me to library',
        'where is exit',
        '',
        'random gibberish 123',
        'accessible elevator floor 1'
      ];
      for (const q of queries) {
        const res = queryExtractorService.extractQuery(q);
        expect(res.confidence).toBeGreaterThanOrEqual(0.0);
        expect(res.confidence).toBeLessThanOrEqual(1.0);
      }
    });
  });
});
