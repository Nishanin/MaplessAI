const request = require('supertest');
const app = require('../src/app');
const { validateContract } = require('../src/utils/schema_validator');
const slmProviderModule = require('../src/features/ai/slm_provider');
const semanticGraphService = require('../src/features/ai/semantic_graph.service');

/**
 * Mock Spatial Engine Consumer (Simulates Pratik's Downstream Routing Layer)
 * Validates that incoming handoff payloads strictly conform to the established
 * navigation-request contract before any route calculation would take place.
 */
class MockSpatialEngineConsumer {
  constructor() {
    this.receivedRequests = [];
  }

  consume(navigationRequest) {
    if (!navigationRequest || typeof navigationRequest !== 'object') {
      throw new Error('Spatial consumer received null or invalid NavigationRequest.');
    }

    const validation = validateContract('navigation-request', navigationRequest);
    if (!validation.valid) {
      throw new Error(`Spatial consumer rejected malformed NavigationRequest: ${JSON.stringify(validation.errors)}`);
    }

    this.receivedRequests.push(navigationRequest);
    return {
      status: 'ACCEPTED',
      destinationNodeId: navigationRequest.destinationNodeId,
      startNodeId: navigationRequest.startNodeId || null,
      intent: navigationRequest.intent,
      operation: navigationRequest.operation,
      requiresRoute: navigationRequest.requiresRoute
    };
  }

  reset() {
    this.receivedRequests = [];
  }
}

describe('Semantic AI to Spatial Engine Integration Boundary Tests (Phase 12)', () => {
  let mockSpatialEngine;

  beforeEach(() => {
    mockSpatialEngine = new MockSpatialEngineConsumer();
    jest.restoreAllMocks();
  });

  // ── A. Valid NAVIGATE_TO Request ──────────────────────────────────────────
  describe('A. Valid NAVIGATE_TO Request', () => {
    it('should produce a validated NavigationRequest with graph-resolved destinationNodeId', async () => {
      const res = await request(app)
        .post('/api/v1/ai/query')
        .send({
          text: 'Navigate to Lab 101',
          buildingId: 'vit-ce',
          userContext: { currentNodeId: 'reception', accessible: false }
        });

      expect(res.status).toBe(200);
      expect(res.body.intent).toBe('NAVIGATE_TO');
      expect(res.body.targetNodeId).toBe('lab-101');
      expect(res.body.navigationRequest).not.toBeNull();

      // Destination comes from Semantic Knowledge Graph resolution
      const graphNode = semanticGraphService.getNodeById('lab-101');
      expect(graphNode).not.toBeNull();
      expect(res.body.navigationRequest.destinationNodeId).toBe(graphNode.id);
      expect(res.body.navigationRequest.startNodeId).toBe('reception');
      expect(res.body.navigationRequest.requiresRoute).toBe(true);

      // Mock spatial engine consumes and accepts handoff
      const handoffResult = mockSpatialEngine.consume(res.body.navigationRequest);
      expect(handoffResult.status).toBe('ACCEPTED');
      expect(handoffResult.destinationNodeId).toBe('lab-101');
      expect(mockSpatialEngine.receivedRequests).toHaveLength(1);
    });
  });

  // ── B. Valid FIND_NEAREST Request ─────────────────────────────────────────
  describe('B. Valid FIND_NEAREST Request', () => {
    it('should produce NavigationRequest preserving nearest semantics for spatial engine', async () => {
      const res = await request(app)
        .post('/api/v1/ai/query')
        .send({
          text: 'Where is the nearest elevator?',
          buildingId: 'vit-ce',
          userContext: { currentNodeId: 'entrance' }
        });

      expect(res.status).toBe(200);
      expect(res.body.intent).toBe('FIND_NEAREST');
      expect(res.body.targetNodeId).toBe('lift');
      expect(res.body.navigationRequest).not.toBeNull();
      expect(res.body.navigationRequest.requiresNearest).toBe(true);
      expect(res.body.navigationRequest.operation).toBe('FIND_NEAREST_TARGET');

      const handoffResult = mockSpatialEngine.consume(res.body.navigationRequest);
      expect(handoffResult.status).toBe('ACCEPTED');
      expect(handoffResult.destinationNodeId).toBe('lift');
      expect(mockSpatialEngine.receivedRequests).toHaveLength(1);
    });
  });

  // ── C. Valid EMERGENCY_EXIT Request ───────────────────────────────────────
  describe('C. Valid EMERGENCY_EXIT Request', () => {
    it('should produce NavigationRequest with emergency routing preferences', async () => {
      const res = await request(app)
        .post('/api/v1/ai/query')
        .send({
          text: 'Emergency! Where is the nearest fire exit?',
          buildingId: 'vit-ce',
          userContext: { currentNodeId: 'lab-101' }
        });

      expect(res.status).toBe(200);
      expect(res.body.intent).toBe('EMERGENCY_EXIT');
      expect(res.body.targetNodeId).toBe('exit-a');
      expect(res.body.navigationRequest).not.toBeNull();
      expect(res.body.navigationRequest.preferences.emergencyMode).toBe(true);
      expect(res.body.navigationRequest.requiresNearest).toBe(true);

      const handoffResult = mockSpatialEngine.consume(res.body.navigationRequest);
      expect(handoffResult.status).toBe('ACCEPTED');
      expect(handoffResult.destinationNodeId).toBe('exit-a');
      expect(mockSpatialEngine.receivedRequests).toHaveLength(1);
    });
  });

  // ── D. Non-Navigation Lookup: QUERY_INFO ───────────────────────────────────
  describe('D. Non-Navigation Lookup: QUERY_INFO', () => {
    it('should provide informational response with strictly null NavigationRequest', async () => {
      const res = await request(app)
        .post('/api/v1/ai/query')
        .send({
          text: 'What is the operational hours for Library?',
          buildingId: 'vit-ce'
        });

      expect(res.status).toBe(200);
      expect(res.body.intent).toBe('QUERY_INFO');
      expect(res.body.navigationRequest).toBeNull();

      // Spatial engine is never called
      expect(mockSpatialEngine.receivedRequests).toHaveLength(0);
    });
  });

  // ── E. Non-Navigation Lookup: LOCATE_ROOM & FALLBACK ──────────────────────
  describe('E. Non-Navigation Lookup: LOCATE_ROOM & FALLBACK', () => {
    it('should never create NavigationRequest for room lookups without navigation verb', async () => {
      const res = await request(app)
        .post('/api/v1/ai/query')
        .send({
          text: 'Where is Lab 101?',
          buildingId: 'vit-ce'
        });

      expect(res.status).toBe(200);
      expect(res.body.intent).toBe('LOCATE_ROOM');
      expect(res.body.targetNodeId).toBe('lab-101');
      expect(res.body.navigationRequest).toBeNull();
      expect(mockSpatialEngine.receivedRequests).toHaveLength(0);
    });

    it('should never create NavigationRequest for unsupported / FALLBACK queries', async () => {
      const res = await request(app)
        .post('/api/v1/ai/query')
        .send({
          text: 'What is the capital of France?',
          buildingId: 'vit-ce'
        });

      expect(res.status).toBe(200);
      expect(res.body.intent).toBe('FALLBACK');
      expect(res.body.targetNodeId).toBeNull();
      expect(res.body.navigationRequest).toBeNull();
      expect(mockSpatialEngine.receivedRequests).toHaveLength(0);
    });
  });

  // ── F. AMBIGUOUS Resolution ───────────────────────────────────────────────
  describe('F. AMBIGUOUS Resolution', () => {
    it('should return null NavigationRequest and never invoke spatial engine on ambiguous queries', async () => {
      // "accessible entrance stairs only" or multiple conflicting categories
      const res = await request(app)
        .post('/api/v1/ai/query')
        .send({
          text: 'Take me to the lab and the elevator',
          buildingId: 'vit-ce'
        });

      expect(res.status).toBe(200);
      expect(res.body.intent).toBe('FALLBACK');
      expect(res.body.targetNodeId).toBeNull();
      expect(res.body.navigationRequest).toBeNull();
      expect(mockSpatialEngine.receivedRequests).toHaveLength(0);
    });
  });

  // ── G. NOT_FOUND Resolution ───────────────────────────────────────────────
  describe('G. NOT_FOUND Resolution', () => {
    it('should return null NavigationRequest when target does not exist in graph', async () => {
      const res = await request(app)
        .post('/api/v1/ai/query')
        .send({
          text: 'Navigate to room 999 on floor 8',
          buildingId: 'vit-ce'
        });

      expect(res.status).toBe(200);
      expect(res.body.intent).toBe('FALLBACK');
      expect(res.body.targetNodeId).toBeNull();
      expect(res.body.navigationRequest).toBeNull();
      expect(res.body.confidence).toBe(0.0);
      expect(mockSpatialEngine.receivedRequests).toHaveLength(0);
    });
  });

  // ── H. Invalid Provider Destination Injection ─────────────────────────────
  describe('H. Invalid Provider Destination Injection', () => {
    it('should reject provider targetNodeId injection and prevent spatial engine handoff', async () => {
      // Mock provider attempting direct node ID injection
      const mockInjectingProvider = {
        generateStructuredQuery: jest.fn().mockResolvedValue({
          intent: 'NAVIGATE_TO',
          entities: [{ type: 'room_name', value: 'Lab 101' }],
          constraints: { name: 'Lab 101' },
          targetNodeId: 'malicious-injected-node',
          confidence: 0.95,
          ambiguity: false,
          reason: 'malicious injection'
        })
      };
      jest.spyOn(slmProviderModule, 'getSlmProvider').mockReturnValue(mockInjectingProvider);

      const res = await request(app)
        .post('/api/v1/ai/query')
        .send({
          text: 'Navigate to Lab 101',
          buildingId: 'vit-ce'
        });

      expect(res.status).toBe(200);
      expect(res.body.intent).toBe('FALLBACK');
      expect(res.body.targetNodeId).toBeNull();
      expect(res.body.navigationRequest).toBeNull();
      expect(mockSpatialEngine.receivedRequests).toHaveLength(0);
    });
  });

  // ── I. Confidence Monotonicity Across Handoff ──────────────────────────────
  describe('I. Confidence Monotonicity Across Handoff', () => {
    it('should verify final confidence <= graph-query confidence <= provider confidence', async () => {
      const mockConfidenceProvider = {
        generateStructuredQuery: jest.fn().mockResolvedValue({
          intent: 'NAVIGATE_TO',
          entities: [{ type: 'room_name', value: 'Lab 101' }],
          constraints: { name: 'Lab 101' },
          confidence: 0.72,
          ambiguity: false,
          reason: 'calibrated confidence test'
        })
      };
      jest.spyOn(slmProviderModule, 'getSlmProvider').mockReturnValue(mockConfidenceProvider);

      const res = await request(app)
        .post('/api/ai/query'.replace('/api/', '/api/v1/'))
        .send({
          text: 'Navigate to Lab 101',
          buildingId: 'vit-ce'
        });

      expect(res.status).toBe(200);
      const providerConfidence = 0.72;
      const responseConfidence = res.body.confidence;
      const navConfidence = res.body.navigationRequest.confidence;

      expect(responseConfidence).toBeLessThanOrEqual(providerConfidence);
      expect(navConfidence).toBeLessThanOrEqual(responseConfidence);
      expect(navConfidence).toBe(0.72);
    });
  });

  // ── J. Determinism of Handoff Payloads ─────────────────────────────────────
  describe('J. Determinism of Handoff Payloads', () => {
    it('should produce byte-for-byte identical NavigationRequest across repeated queries', async () => {
      const payload = {
        text: 'Take me to the Department Library',
        buildingId: 'vit-ce',
        userContext: { currentNodeId: 'entrance', accessible: true }
      };

      const res1 = await request(app).post('/api/v1/ai/query').send(payload);
      const res2 = await request(app).post('/api/v1/ai/query').send(payload);

      expect(res1.body.navigationRequest).not.toBeNull();
      expect(res2.body.navigationRequest).not.toBeNull();
      expect(res1.body.navigationRequest).toEqual(res2.body.navigationRequest);

      const handoff1 = mockSpatialEngine.consume(res1.body.navigationRequest);
      const handoff2 = mockSpatialEngine.consume(res2.body.navigationRequest);
      expect(handoff1).toEqual(handoff2);
    });
  });

  // ── K. Spatial Isolation ──────────────────────────────────────────────────
  describe('K. Spatial Engine Isolation & Separation of Concerns', () => {
    it('should never calculate routes, distances, turns, coordinates, or graph edges in Semantic AI', async () => {
      const res = await request(app)
        .post('/api/v1/ai/query')
        .send({
          text: 'Navigate to Lab 101',
          buildingId: 'vit-ce',
          userContext: { currentNodeId: 'reception' }
        });

      expect(res.status).toBe(200);
      const navRequest = res.body.navigationRequest;
      expect(navRequest).not.toBeNull();

      // Semantic AI supplies target destinations, NOT spatial route computations
      expect(navRequest.route).toBeUndefined();
      expect(navRequest.path).toBeUndefined();
      expect(navRequest.waypoints).toBeUndefined();
      expect(navRequest.turnInstructions).toBeUndefined();
      expect(navRequest.distanceMeters).toBeUndefined();
      expect(navRequest.coordinates).toBeUndefined();

      // Spatial engine consumer receives clean handoff containing only destinationNodeId and preferences
      expect(navRequest.destinationNodeId).toBe('lab-101');
      expect(navRequest.preferences).toBeDefined();
    });
  });
});
