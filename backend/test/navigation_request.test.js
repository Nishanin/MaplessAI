const request = require('supertest');
const app = require('../src/app');
const semanticGraphService = require('../src/features/ai/semantic_graph.service');
const navigationRequestService = require('../src/features/ai/navigation_request.service');
const { validateContract } = require('../src/utils/schema_validator');

/**
 * Phase 9: Semantic Resolution and NavigationRequest Boundary Tests (Owner: Surabhi)
 *
 * Tests cover:
 *   1. Explicit resolution states: RESOLVED, AMBIGUOUS, NOT_FOUND.
 *   2. Semantic candidate resolution filters (exact name, alias, category, department, facility, floor, accessible, capacity).
 *   3. NavigationRequest construction & strict validation under contracts/navigation-request.schema.json.
 *   4. Boundary protection: Lookups (LOCATE_ROOM, QUERY_INFO) and unresolvable states NEVER produce NavigationRequests.
 *   5. Security & Injection scanning within NavigationRequest.
 *   6. Controller integration: NavigationRequest presence on navigation intents, absence on lookups/fallbacks, and zero SKG invocation on fallback.
 */

describe('Phase 9 — Semantic Resolution and NavigationRequest Boundary', () => {
  // ── 1. Resolution States & Semantic Candidate Filtering ───────────────────
  describe('Semantic Graph Resolution States', () => {
    it('should return RESOLVED when exactly one candidate matches exact name', () => {
      const res = semanticGraphService.resolveCandidates({ name: 'Lab 101' });
      expect(res.resolutionState).toBe('RESOLVED');
      expect(res.status).toBe('resolved');
      expect(res.matchCount).toBe(1);
      expect(res.candidateIds).toEqual(['lab-101']);
    });

    it('should return RESOLVED when matching known alias', () => {
      const res = semanticGraphService.resolveCandidates({ alias: 'software lab 1' });
      expect(res.resolutionState).toBe('RESOLVED');
      expect(res.matchCount).toBe(1);
      expect(res.candidateIds).toEqual(['lab-101']);
    });

    it('should return RESOLVED when matching specific department and category', () => {
      const res = semanticGraphService.resolveCandidates({
        category: 'laboratory',
        department: 'Computer Engineering'
      });
      expect(res.resolutionState).toBe('RESOLVED');
      expect(res.candidateIds).toEqual(['lab-101']);
    });

    it('should return RESOLVED with accessibility constraint', () => {
      const res = semanticGraphService.resolveCandidates({
        category: 'laboratory',
        accessible: true
      });
      expect(res.resolutionState).toBe('RESOLVED');
      expect(res.candidates[0].accessible).toBe(true);
    });

    it('should return RESOLVED with capacity filter', () => {
      const res = semanticGraphService.resolveCandidates({
        category: 'laboratory',
        capacityMin: 40
      });
      expect(res.resolutionState).toBe('RESOLVED');
      expect(res.candidates[0].capacity).toBeGreaterThanOrEqual(40);
    });

    it('should return AMBIGUOUS when multiple candidates match', () => {
      const res = semanticGraphService.resolveCandidates({ department: 'Computer Engineering' });
      expect(res.resolutionState).toBe('AMBIGUOUS');
      expect(res.status).toBe('ambiguous');
      expect(res.matchCount).toBe(2);
      expect(res.candidateIds).toEqual(expect.arrayContaining(['lab-101', 'library']));
    });

    it('should return NOT_FOUND when zero candidates match', () => {
      const res = semanticGraphService.resolveCandidates({ category: 'non_existent_category' });
      expect(res.resolutionState).toBe('NOT_FOUND');
      expect(res.status).toBe('not_found');
      expect(res.matchCount).toBe(0);
      expect(res.candidateIds).toEqual([]);
    });
  });

  // ── 2. NavigationRequest Construction & Contract Compliance ────────────────
  describe('NavigationRequest Construction & Schema Validation', () => {
    it('should construct a valid NavigationRequest for NAVIGATE_TO intent', () => {
      const graphQuery = {
        operation: 'RESOLVE_DESTINATION',
        filters: { name: 'Lab 101' },
        semanticTarget: 'Lab 101',
        requiresNearest: false,
        requiresRoute: true,
        confidence: 0.90,
        ambiguity: false
      };
      const resolution = semanticGraphService.resolveCandidates({ name: 'Lab 101' });

      const navRequest = navigationRequestService.buildNavigationRequest({
        graphQuery,
        resolution,
        buildingId: 'vit-ce',
        userContext: { currentNodeId: 'reception' },
        intent: 'NAVIGATE_TO'
      });

      expect(navRequest).toBeDefined();
      expect(navRequest.buildingId).toBe('vit-ce');
      expect(navRequest.startNodeId).toBe('reception');
      expect(navRequest.destinationNodeId).toBe('lab-101');
      expect(navRequest.intent).toBe('NAVIGATE_TO');
      expect(navRequest.operation).toBe('RESOLVE_DESTINATION');
      expect(navRequest.requiresRoute).toBe(true);
      expect(navRequest.requiresNearest).toBe(false);
      expect(navRequest.confidence).toBe(0.90);
      expect(navRequest.resolvedTarget.nodeId).toBe('lab-101');
      expect(navRequest.resolvedTarget.name).toBe('Lab 101');
      expect(Object.isFrozen(navRequest)).toBe(true);

      const contractValidation = validateContract('navigation-request', navRequest);
      expect(contractValidation.valid).toBe(true);
    });

    it('should construct a valid NavigationRequest for FIND_NEAREST intent', () => {
      const graphQuery = {
        operation: 'FIND_NEAREST_TARGET',
        filters: { category: 'elevator' },
        semanticTarget: 'elevator',
        requiresNearest: true,
        requiresRoute: true,
        confidence: 0.88,
        ambiguity: false
      };
      const resolution = semanticGraphService.resolveCandidates({ category: 'elevator' });

      const navRequest = navigationRequestService.buildNavigationRequest({
        graphQuery,
        resolution,
        buildingId: 'vit-ce',
        intent: 'FIND_NEAREST'
      });

      expect(navRequest).toBeDefined();
      expect(navRequest.intent).toBe('FIND_NEAREST');
      expect(navRequest.requiresNearest).toBe(true);
      expect(navRequest.startNodeId).toBeNull();
      expect(navRequest.destinationNodeId).toBe('lift');

      const contractValidation = validateContract('navigation-request', navRequest);
      expect(contractValidation.valid).toBe(true);
    });

    it('should construct a valid NavigationRequest for EMERGENCY_EXIT with emergencyMode=true', () => {
      const graphQuery = {
        operation: 'RESOLVE_EMERGENCY_EXIT',
        filters: { category: 'emergency_exit' },
        semanticTarget: 'emergency_exit',
        requiresNearest: true,
        requiresRoute: true,
        confidence: 0.95,
        ambiguity: false
      };
      const resolution = semanticGraphService.resolveCandidates({ category: 'emergency_exit' });

      const navRequest = navigationRequestService.buildNavigationRequest({
        graphQuery,
        resolution,
        buildingId: 'vit-ce',
        intent: 'EMERGENCY_EXIT'
      });

      expect(navRequest).toBeDefined();
      expect(navRequest.intent).toBe('EMERGENCY_EXIT');
      expect(navRequest.preferences.emergencyMode).toBe(true);
      expect(navRequest.requiresNearest).toBe(true);

      const contractValidation = validateContract('navigation-request', navRequest);
      expect(contractValidation.valid).toBe(true);
    });
  });

  // ── 3. Non-Navigation Intent Boundary ──────────────────────────────────────
  describe('Non-Navigation Intents and Unresolved States Boundary', () => {
    it('should NEVER create a NavigationRequest for LOCATE_ROOM lookup intent', () => {
      const graphQuery = {
        operation: 'LOOKUP_LOCATION',
        filters: { name: 'Lab 101' },
        semanticTarget: 'Lab 101',
        requiresNearest: false,
        requiresRoute: false,
        confidence: 0.90,
        ambiguity: false
      };
      const resolution = semanticGraphService.resolveCandidates({ name: 'Lab 101' });

      const navRequest = navigationRequestService.buildNavigationRequest({
        graphQuery,
        resolution,
        buildingId: 'vit-ce',
        intent: 'LOCATE_ROOM'
      });

      expect(navRequest).toBeNull();
    });

    it('should NEVER create a NavigationRequest for QUERY_INFO lookup intent', () => {
      const graphQuery = {
        operation: 'QUERY_FACILITY_INFO',
        filters: { facility: 'wifiZone' },
        semanticTarget: 'wifiZone',
        requiresNearest: false,
        requiresRoute: false,
        confidence: 0.85,
        ambiguity: false
      };
      const resolution = semanticGraphService.resolveCandidates({ facility: 'wifiZone' });

      const navRequest = navigationRequestService.buildNavigationRequest({
        graphQuery,
        resolution,
        buildingId: 'vit-ce',
        intent: 'QUERY_INFO'
      });

      expect(navRequest).toBeNull();
    });

    it('should NEVER create a NavigationRequest when resolution is AMBIGUOUS', () => {
      const graphQuery = {
        operation: 'FIND_NEAREST_TARGET',
        filters: { category: 'restroom' },
        semanticTarget: 'restroom',
        requiresNearest: true,
        requiresRoute: true,
        confidence: 0.85,
        ambiguity: false
      };
      const resolution = semanticGraphService.resolveCandidates({ department: 'Computer Engineering' }); // 2 candidates match

      const navRequest = navigationRequestService.buildNavigationRequest({
        graphQuery,
        resolution,
        buildingId: 'vit-ce',
        intent: 'FIND_NEAREST'
      });

      expect(navRequest).toBeNull();
    });

    it('should NEVER create a NavigationRequest when resolution is NOT_FOUND', () => {
      const graphQuery = {
        operation: 'RESOLVE_DESTINATION',
        filters: { name: 'Nonexistent Hall' },
        semanticTarget: 'Nonexistent Hall',
        requiresNearest: false,
        requiresRoute: true,
        confidence: 0.85,
        ambiguity: false
      };
      const resolution = semanticGraphService.resolveCandidates({ name: 'Nonexistent Hall' });

      const navRequest = navigationRequestService.buildNavigationRequest({
        graphQuery,
        resolution,
        buildingId: 'vit-ce',
        intent: 'NAVIGATE_TO'
      });

      expect(navRequest).toBeNull();
    });
  });

  // ── 4. Security & Validation Protections ───────────────────────────────────
  describe('Security and Validation Protections', () => {
    it('should reject NavigationRequest containing SQL injection patterns', () => {
      const maliciousNavRequest = {
        buildingId: 'vit-ce',
        destinationNodeId: 'lab-101',
        intent: 'NAVIGATE_TO',
        operation: 'RESOLVE_DESTINATION',
        semanticTarget: "SELECT * FROM nodes WHERE '1'='1",
        resolvedTarget: {
          nodeId: 'lab-101',
          name: 'Lab 101',
          category: 'laboratory'
        }
      };

      const result = navigationRequestService.validateNavigationRequest(maliciousNavRequest);
      expect(result.valid).toBe(false);
      expect(result.errors.some(e => e.includes('SQL statement'))).toBe(true);
    });

    it('should reject NavigationRequest containing shell commands or script tags', () => {
      const maliciousNavRequest = {
        buildingId: 'vit-ce',
        destinationNodeId: 'lab-101',
        intent: 'NAVIGATE_TO',
        operation: 'RESOLVE_DESTINATION',
        semanticTarget: '<script>alert("hack")</script>',
        resolvedTarget: {
          nodeId: 'lab-101',
          name: 'rm -rf /',
          category: 'laboratory'
        }
      };

      const result = navigationRequestService.validateNavigationRequest(maliciousNavRequest);
      expect(result.valid).toBe(false);
      expect(result.errors.length).toBeGreaterThanOrEqual(1);
    });

    it('should reject NavigationRequest with missing destinationNodeId', () => {
      const invalidNavRequest = {
        buildingId: 'vit-ce',
        intent: 'NAVIGATE_TO',
        operation: 'RESOLVE_DESTINATION',
        semanticTarget: 'Lab 101'
      };

      const result = navigationRequestService.validateNavigationRequest(invalidNavRequest);
      expect(result.valid).toBe(false);
    });
  });

  // ── 5. Controller End-to-End Integration ──────────────────────────────────
  describe('Controller Integration & API Response Compatibility', () => {
    it('should include NavigationRequest in response for resolved NAVIGATE_TO query', async () => {
      const response = await request(app)
        .post('/api/v1/ai/query')
        .send({
          text: 'Take me to Lab 101',
          buildingId: 'vit-ce',
          userContext: { currentNodeId: 'entrance' }
        });

      expect(response.statusCode).toBe(200);
      expect(response.body.intent).toBe('NAVIGATE_TO');
      expect(response.body.targetNodeId).toBe('lab-101');
      expect(response.body.navigationRequest).toBeDefined();
      expect(response.body.navigationRequest.destinationNodeId).toBe('lab-101');
      expect(response.body.navigationRequest.startNodeId).toBe('entrance');
      expect(response.body.navigationRequest.requiresRoute).toBe(true);

      const contractValidation = validateContract('ai-response', response.body);
      expect(contractValidation.valid).toBe(true);
    });

    it('should set navigationRequest: null for LOCATE_ROOM lookup queries', async () => {
      const response = await request(app)
        .post('/api/v1/ai/query')
        .send({
          text: 'Where is Lab 101?',
          buildingId: 'vit-ce'
        });

      expect(response.statusCode).toBe(200);
      expect(response.body.intent).toBe('LOCATE_ROOM');
      expect(response.body.targetNodeId).toBe('lab-101');
      expect(response.body.navigationRequest).toBeNull();

      const contractValidation = validateContract('ai-response', response.body);
      expect(contractValidation.valid).toBe(true);
    });

    it('should set navigationRequest: null and targetNodeId: null for FALLBACK queries', async () => {
      const spyResolve = jest.spyOn(semanticGraphService, 'resolveCandidates');

      const response = await request(app)
        .post('/api/v1/ai/query')
        .send({
          text: 'Tell me a funny joke about robots',
          buildingId: 'vit-ce'
        });

      expect(response.statusCode).toBe(200);
      expect(response.body.intent).toBe('FALLBACK');
      expect(response.body.targetNodeId).toBeNull();
      expect(response.body.navigationRequest).toBeNull();
      expect(spyResolve).not.toHaveBeenCalled();

      spyResolve.mockRestore();
    });

    it('should set navigationRequest: null for ambiguous location queries', async () => {
      const response = await request(app)
        .post('/api/v1/ai/query')
        .send({
          text: 'Where can I find the CSE department?',
          buildingId: 'vit-ce'
        });

      expect(response.statusCode).toBe(200);
      // Multiple candidates match department, triggers ambiguity fallback
      expect(response.body.intent).toBe('FALLBACK');
      expect(response.body.targetNodeId).toBeNull();
      expect(response.body.navigationRequest).toBeNull();
    });
  });
});
