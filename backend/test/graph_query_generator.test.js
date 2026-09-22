const request = require('supertest');
const app = require('../src/app');
const graphQueryGeneratorService = require('../src/features/ai/graph_query_generator.service');
const semanticGraphService = require('../src/features/ai/semantic_graph.service');

/**
 * Phase 8: Structured Graph Query Generator Tests (Owner: Surabhi)
 *
 * Tests cover:
 *   1. Supported intent to operation mappings (FIND_NEAREST, NAVIGATE_TO, LOCATE_ROOM, QUERY_INFO, EMERGENCY_EXIT, FALLBACK).
 *   2. Controlled operational flags (requiresNearest, requiresRoute).
 *   3. Filter mapping & sanitization (room name, department, facility, floor, accessibility, capacityMin, category, alias, tag).
 *   4. Semantic target extraction.
 *   5. Security & Injection scanning (SQL, scripts, URLs, shell commands).
 *   6. Prohibition of direct node selection (targetNodeId, nodeId).
 *   7. Rejection of unknown filter keys.
 *   8. Rejection of empty/meaningless targets for active intents.
 *   9. validateGraphQuery helper validation.
 *  10. Controller integration: SKG invocation only for valid non-fallback queries; FALLBACK never invokes SKG.
 */

describe('Phase 8 — Structured Graph Query Generator', () => {
  // ── 1. Intent to Operation Mapping ────────────────────────────────────────
  describe('Intent to Operation Mappings', () => {
    it('should map FIND_NEAREST to FIND_NEAREST_TARGET with requiresNearest=true and requiresRoute=true', () => {
      const providerOutput = {
        intent: 'FIND_NEAREST',
        entities: [{ type: 'category', value: 'restroom' }],
        constraints: { category: 'restroom' },
        confidence: 0.90,
        ambiguity: false
      };
      const query = graphQueryGeneratorService.generateGraphQuery(providerOutput);
      expect(query.operation).toBe('FIND_NEAREST_TARGET');
      expect(query.requiresNearest).toBe(true);
      expect(query.requiresRoute).toBe(true);
      expect(query.semanticTarget).toBe('restroom');
      expect(query.filters.category).toBe('restroom');
      expect(query.confidence).toBe(0.90);
      expect(query.ambiguity).toBe(false);
    });

    it('should map NAVIGATE_TO to RESOLVE_DESTINATION with requiresNearest=false and requiresRoute=true', () => {
      const providerOutput = {
        intent: 'NAVIGATE_TO',
        entities: [{ type: 'room_name', value: 'Room 204' }],
        constraints: { name: 'Room 204' },
        confidence: 0.92,
        ambiguity: false
      };
      const query = graphQueryGeneratorService.generateGraphQuery(providerOutput);
      expect(query.operation).toBe('RESOLVE_DESTINATION');
      expect(query.requiresNearest).toBe(false);
      expect(query.requiresRoute).toBe(true);
      expect(query.semanticTarget).toBe('Room 204');
      expect(query.filters.name).toBe('Room 204');
    });

    it('should map LOCATE_ROOM to LOOKUP_LOCATION with requiresNearest=false and requiresRoute=false', () => {
      const providerOutput = {
        intent: 'LOCATE_ROOM',
        entities: [{ type: 'department', value: 'Computer Engineering' }],
        constraints: { department: 'Computer Engineering' },
        confidence: 0.88,
        ambiguity: false
      };
      const query = graphQueryGeneratorService.generateGraphQuery(providerOutput);
      expect(query.operation).toBe('LOOKUP_LOCATION');
      expect(query.requiresNearest).toBe(false);
      expect(query.requiresRoute).toBe(false);
      expect(query.semanticTarget).toBe('Computer Engineering');
      expect(query.filters.department).toBe('Computer Engineering');
    });

    it('should map QUERY_INFO to QUERY_FACILITY_INFO with requiresNearest=false and requiresRoute=false', () => {
      const providerOutput = {
        intent: 'QUERY_INFO',
        entities: [{ type: 'facility', value: 'wifiZone' }],
        constraints: { facility: 'wifiZone' },
        confidence: 0.80,
        ambiguity: false
      };
      const query = graphQueryGeneratorService.generateGraphQuery(providerOutput);
      expect(query.operation).toBe('QUERY_FACILITY_INFO');
      expect(query.requiresNearest).toBe(false);
      expect(query.requiresRoute).toBe(false);
      expect(query.semanticTarget).toBe('wifiZone');
      expect(query.filters.facility).toBe('wifiZone');
    });

    it('should map EMERGENCY_EXIT to RESOLVE_EMERGENCY_EXIT with requiresNearest=true and requiresRoute=true', () => {
      const providerOutput = {
        intent: 'EMERGENCY_EXIT',
        entities: [{ type: 'category', value: 'emergency_exit' }],
        constraints: {},
        confidence: 0.95,
        ambiguity: false
      };
      const query = graphQueryGeneratorService.generateGraphQuery(providerOutput);
      expect(query.operation).toBe('RESOLVE_EMERGENCY_EXIT');
      expect(query.requiresNearest).toBe(true);
      expect(query.requiresRoute).toBe(true);
      expect(query.semanticTarget).toBe('emergency_exit');
      expect(query.filters.category).toBe('emergency_exit');
    });

    it('should map FALLBACK to NO_OP with empty filters and null semanticTarget', () => {
      const providerOutput = {
        intent: 'FALLBACK',
        entities: [],
        constraints: {},
        confidence: 0.0,
        ambiguity: false
      };
      const query = graphQueryGeneratorService.generateGraphQuery(providerOutput);
      expect(query.operation).toBe('NO_OP');
      expect(query.requiresNearest).toBe(false);
      expect(query.requiresRoute).toBe(false);
      expect(query.semanticTarget).toBeNull();
      expect(query.filters).toEqual({});
      expect(query.confidence).toBe(0.0);
    });
  });

  // ── 2. Filter Mappings ───────────────────────────────────────────────────
  describe('Whitelisted Filter Mappings', () => {
    it('should correctly map all whitelisted filter fields', () => {
      const providerOutput = {
        intent: 'LOCATE_ROOM',
        entities: [{ type: 'room_name', value: 'Room 101' }],
        constraints: {
          name: 'Room 101',
          alias: 'Main Lab',
          category: 'laboratory',
          tag: 'ai',
          department: 'Computer Engineering',
          accessible: true,
          facility: 'projectorAvailable',
          floor: 1,
          capacityMin: 40
        },
        confidence: 0.90,
        ambiguity: false
      };

      const query = graphQueryGeneratorService.generateGraphQuery(providerOutput);
      expect(query.filters).toEqual({
        name: 'Room 101',
        alias: 'Main Lab',
        category: 'laboratory',
        tag: 'ai',
        department: 'Computer Engineering',
        accessible: true,
        facility: 'projectorAvailable',
        floor: 1,
        capacityMin: 40
      });
      expect(Object.isFrozen(query)).toBe(true);
      expect(Object.isFrozen(query.filters)).toBe(true);
    });

    it('should reject unknown filter keys in constraints', () => {
      const providerOutput = {
        intent: 'LOCATE_ROOM',
        entities: [{ type: 'room_name', value: 'Room 101' }],
        constraints: {
          name: 'Room 101',
          unknownCustomFilter: 'malicious_value'
        },
        confidence: 0.85,
        ambiguity: false
      };

      expect(() => graphQueryGeneratorService.generateGraphQuery(providerOutput)).toThrow(
        /Unsupported filter key: "unknownCustomFilter"/
      );
    });
  });

  // ── 3. Direct Node Selection Prohibition ─────────────────────────────────
  describe('Direct Node Selection Prohibition', () => {
    it('should reject provider output containing targetNodeId at the top level', () => {
      const providerOutput = {
        intent: 'NAVIGATE_TO',
        entities: [{ type: 'room_name', value: 'Room 101' }],
        constraints: { name: 'Room 101' },
        targetNodeId: 'lab-101',
        confidence: 0.90,
        ambiguity: false
      };

      expect(() => graphQueryGeneratorService.generateGraphQuery(providerOutput)).toThrow(
        /direct assignment of targetNodeId is strictly forbidden/i
      );
    });

    it('should reject provider output containing targetNodeId inside constraints', () => {
      const providerOutput = {
        intent: 'NAVIGATE_TO',
        entities: [{ type: 'room_name', value: 'Room 101' }],
        constraints: {
          name: 'Room 101',
          targetNodeId: 'node-xyz'
        },
        confidence: 0.90,
        ambiguity: false
      };

      expect(() => graphQueryGeneratorService.generateGraphQuery(providerOutput)).toThrow(
        /direct assignment of targetNodeId is strictly forbidden/i
      );
    });

    it('should reject direct nodeId filtering from provider output', () => {
      const providerOutput = {
        intent: 'NAVIGATE_TO',
        entities: [{ type: 'node', value: 'lab-101' }],
        constraints: { nodeId: 'lab-101' },
        confidence: 0.90,
        ambiguity: false
      };

      expect(() => graphQueryGeneratorService.generateGraphQuery(providerOutput)).toThrow(
        /direct selection via nodeId filter from provider output is forbidden/i
      );
    });
  });

  // ── 4. Security & Injection Scanning ──────────────────────────────────────
  describe('Security & Injection Scanning', () => {
    it('should reject SQL injection patterns', () => {
      const malicious = [
        {
          intent: 'NAVIGATE_TO',
          entities: [{ type: 'room_name', value: "Room 101'; DROP TABLE nodes; --" }],
          constraints: { name: "Room 101'; DROP TABLE nodes; --" },
          confidence: 0.85,
          ambiguity: false
        },
        {
          intent: 'LOCATE_ROOM',
          entities: [{ type: 'room_name', value: 'UNION SELECT * FROM users' }],
          constraints: { name: 'UNION SELECT * FROM users' },
          confidence: 0.85,
          ambiguity: false
        }
      ];

      for (const m of malicious) {
        expect(() => graphQueryGeneratorService.generateGraphQuery(m)).toThrow(
          /Forbidden pattern \(SQL statement\)/i
        );
      }
    });

    it('should reject script tags and HTML injection', () => {
      const providerOutput = {
        intent: 'LOCATE_ROOM',
        entities: [{ type: 'room_name', value: '<script>alert("xss")</script>' }],
        constraints: { name: '<script>alert("xss")</script>' },
        confidence: 0.80,
        ambiguity: false
      };

      expect(() => graphQueryGeneratorService.generateGraphQuery(providerOutput)).toThrow(
        /Forbidden pattern \(Script tag \/ HTML\)/i
      );
    });

    it('should reject external URLs and endpoints', () => {
      const providerOutput = {
        intent: 'LOCATE_ROOM',
        entities: [{ type: 'room_name', value: 'https://evil.com/leak' }],
        constraints: { name: 'https://evil.com/leak' },
        confidence: 0.80,
        ambiguity: false
      };

      expect(() => graphQueryGeneratorService.generateGraphQuery(providerOutput)).toThrow(
        /Forbidden pattern \(URL \/ External Endpoint\)/i
      );
    });

    it('should reject shell commands', () => {
      const providerOutput = {
        intent: 'LOCATE_ROOM',
        entities: [{ type: 'room_name', value: 'rm -rf /' }],
        constraints: { name: 'rm -rf /' },
        confidence: 0.80,
        ambiguity: false
      };

      expect(() => graphQueryGeneratorService.generateGraphQuery(providerOutput)).toThrow(
        /Forbidden pattern \(Shell command\)/i
      );
    });
  });

  // ── 5. Empty Target & Ambiguity Validation ─────────────────────────────────
  describe('Empty Target and Ambiguity Handling', () => {
    it('should throw when active intent has no target and no filters', () => {
      const providerOutput = {
        intent: 'NAVIGATE_TO',
        entities: [],
        constraints: {},
        confidence: 0.75,
        ambiguity: false
      };

      expect(() => graphQueryGeneratorService.generateGraphQuery(providerOutput)).toThrow(
        /Empty semantic target: intent "NAVIGATE_TO" requires at least one identifiable target or filter/
      );
    });

    it('should preserve ambiguity and confidence without artificial increase', () => {
      const providerOutput = {
        intent: 'FIND_NEAREST',
        entities: [{ type: 'category', value: 'elevator' }],
        constraints: { category: 'elevator' },
        confidence: 0.62,
        ambiguity: true
      };

      const query = graphQueryGeneratorService.generateGraphQuery(providerOutput);
      expect(query.confidence).toBe(0.62);
      expect(query.ambiguity).toBe(true);
    });
  });

  // ── 6. Query Validator Helper ─────────────────────────────────────────────
  describe('validateGraphQuery Helper', () => {
    it('should validate a compliant graph query', () => {
      const query = {
        operation: 'FIND_NEAREST_TARGET',
        filters: { category: 'restroom' },
        semanticTarget: 'restroom',
        requiresNearest: true,
        requiresRoute: true,
        confidence: 0.85,
        ambiguity: false
      };

      const result = graphQueryGeneratorService.validateGraphQuery(query);
      expect(result.valid).toBe(true);
      expect(result.errors).toHaveLength(0);
    });

    it('should detect missing fields and invalid operations', () => {
      const invalidQuery = {
        operation: 'ARBITRARY_EXECUTION',
        filters: { unknownField: 'val' },
        confidence: 1.5
      };

      const result = graphQueryGeneratorService.validateGraphQuery(invalidQuery);
      expect(result.valid).toBe(false);
      expect(result.errors.length).toBeGreaterThan(0);
    });
  });

  // ── 7. Controller Integration & SKG Invariant Verification ────────────────
  describe('Controller Integration & SKG Invariants', () => {
    it('should NEVER invoke SKG for FALLBACK queries', async () => {
      const spyResolve = jest.spyOn(semanticGraphService, 'resolveCandidates');

      const response = await request(app)
        .post('/api/v1/ai/query')
        .send({
          text: 'tell me about the weather outside today',
          buildingId: 'vit-ce'
        });

      expect(response.statusCode).toBe(200);
      expect(response.body.intent).toBe('FALLBACK');
      expect(response.body.targetNodeId).toBeNull();
      expect(spyResolve).not.toHaveBeenCalled();

      spyResolve.mockRestore();
    });

    it('should invoke SKG for valid active queries and derive targetNodeId', async () => {
      const spyResolve = jest.spyOn(semanticGraphService, 'resolveCandidates');

      const response = await request(app)
        .post('/api/v1/ai/query')
        .send({
          text: 'Where is the nearest washroom?',
          buildingId: 'vit-ce'
        });

      expect(response.statusCode).toBe(200);
      expect(spyResolve).toHaveBeenCalledTimes(1);
      // Confirmed that the filters passed to SKG are structured and whitelisted
      const filtersPassed = spyResolve.mock.calls[0][0];
      expect(filtersPassed.category).toBe('restroom');
      expect(response.body.targetNodeId).toBeDefined();

      spyResolve.mockRestore();
    });

    it('should safely return FALLBACK if an invalid graph query is encountered', async () => {
      const spyGen = jest
        .spyOn(graphQueryGeneratorService, 'generateGraphQuery')
        .mockImplementationOnce(() => {
          throw new Error('Injected test error in graph query generation');
        });

      const response = await request(app)
        .post('/api/v1/ai/query')
        .send({
          text: 'Take me to the AI lab',
          buildingId: 'vit-ce'
        });

      expect(response.statusCode).toBe(200);
      expect(response.body.intent).toBe('FALLBACK');
      expect(response.body.targetNodeId).toBeNull();

      spyGen.mockRestore();
    });
  });
});
