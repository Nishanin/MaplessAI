const { validateContract } = require('../../utils/schema_validator');

/**
 * NavigationRequest Service (Owner: Surabhi)
 *
 * Constructs and validates the final semantic-to-spatial handoff object (`NavigationRequest`).
 *
 * CRITICAL ARCHITECTURAL & SECURITY BOUNDARIES:
 * 1. Semantic AI Layer Responsibility:
 *    Natural language → intent/entity/constraint extraction → structured query → SKG candidate resolution → NavigationRequest.
 * 2. Spatial Routing Layer Responsibility (Pratik):
 *    Consumes NavigationRequest → computes physical route via A* or Dijkstra → returns turn instructions and path.
 * 3. NavigationRequest is produced ONLY when semantic candidate resolution reaches `RESOLVED` (1 single destination).
 * 4. Lookups (LOCATE_ROOM, QUERY_INFO) and unresolvable/ambiguous states (AMBIGUOUS, NOT_FOUND, FALLBACK)
 *    NEVER produce a NavigationRequest and NEVER invoke spatial routing.
 * 5. destinationNodeId originates EXCLUSIVELY from SemanticGraphService candidate resolution, never from the SLM.
 * 6. The AI layer NEVER computes physical routes, distances, turns, or coordinates.
 */

const RESOLUTION_STATES = Object.freeze({
  RESOLVED: 'RESOLVED',
  AMBIGUOUS: 'AMBIGUOUS',
  NOT_FOUND: 'NOT_FOUND',
  FALLBACK: 'FALLBACK'
});

const NAVIGATION_INTENTS = Object.freeze([
  'NAVIGATE_TO',
  'FIND_NEAREST',
  'EMERGENCY_EXIT'
]);

const NON_NAVIGATION_INTENTS = Object.freeze([
  'LOCATE_ROOM',
  'QUERY_INFO',
  'FALLBACK'
]);

const FORBIDDEN_PATTERNS = Object.freeze([
  {
    name: 'SQL statement',
    regex: /\b(SELECT\s+.*\s+FROM|INSERT\s+INTO|UPDATE\s+\w+\s+SET|DELETE\s+FROM|DROP\s+TABLE|UNION\s+SELECT|ALTER\s+TABLE)\b/i
  },
  {
    name: 'Script tag / HTML',
    regex: /<script\b[^>]*>/i
  },
  {
    name: 'URL / External Endpoint',
    regex: /\b(https?:\/\/|ftp:\/\/|file:\/\/)\b/i
  },
  {
    name: 'Shell command',
    regex: /\b(rm\s+-rf|chmod\s+|sh\s+-c|bash\s+-c|curl\s+|wget\s+)\b/i
  }
]);

/**
 * Recursively scans an object for security injection patterns.
 * @param {*} obj
 * @param {string} path
 * @param {Array<string>} errors
 */
function scanSecurityPatterns(obj, path, errors) {
  if (typeof obj === 'string') {
    for (const pattern of FORBIDDEN_PATTERNS) {
      if (pattern.regex.test(obj)) {
        errors.push(`Security violation: Forbidden pattern (${pattern.name}) detected in ${path || 'value'}.`);
      }
    }
  } else if (Array.isArray(obj)) {
    obj.forEach((item, idx) => scanSecurityPatterns(item, `${path}[${idx}]`, errors));
  } else if (obj && typeof obj === 'object') {
    for (const [key, val] of Object.entries(obj)) {
      scanSecurityPatterns(val, path ? `${path}.${key}` : key, errors);
    }
  }
}

class NavigationRequestService {
  constructor() {
    this.RESOLUTION_STATES = RESOLUTION_STATES;
    this.NAVIGATION_INTENTS = NAVIGATION_INTENTS;
    this.NON_NAVIGATION_INTENTS = NON_NAVIGATION_INTENTS;
  }

  /**
   * Constructs a validated, frozen NavigationRequest object for the spatial engine.
   * Returns null if intent does not require routing or if resolution did not succeed.
   *
   * @param {{
   *   graphQuery: object,
   *   resolution: object,
   *   buildingId: string,
   *   userContext?: object,
   *   intent?: string
   * }} params
   * @returns {object|null} Frozen NavigationRequest or null
   */
  buildNavigationRequest({ graphQuery, resolution, buildingId, userContext, intent }) {
    if (!graphQuery || typeof graphQuery !== 'object') {
      return null;
    }

    const effectiveIntent = intent || graphQuery.intent || (
      graphQuery.operation === 'FIND_NEAREST_TARGET'
        ? 'FIND_NEAREST'
        : graphQuery.operation === 'RESOLVE_EMERGENCY_EXIT'
          ? 'EMERGENCY_EXIT'
          : graphQuery.operation === 'RESOLVE_DESTINATION'
            ? 'NAVIGATE_TO'
            : null
    );

    // Rule 1: Non-navigation intents (LOCATE_ROOM, QUERY_INFO, FALLBACK) NEVER create NavigationRequests
    if (!effectiveIntent || !NAVIGATION_INTENTS.includes(effectiveIntent)) {
      return null;
    }

    // Rule 2: Active query must not be a NO_OP or below confidence threshold
    if (graphQuery.operation === 'NO_OP' || graphQuery.confidence < 0.5 || graphQuery.ambiguity) {
      return null;
    }

    // Rule 3: Resolution must be strictly RESOLVED with exactly 1 candidate
    if (!resolution || typeof resolution !== 'object') {
      return null;
    }

    const isResolved =
      resolution.resolutionState === RESOLUTION_STATES.RESOLVED ||
      resolution.status === 'resolved';

    if (!isResolved || !Array.isArray(resolution.candidates) || resolution.candidates.length !== 1) {
      return null;
    }

    const candidate = resolution.candidates[0];
    if (!candidate || !candidate.id) {
      return null;
    }

    const effectiveBuildingId = buildingId || candidate.buildingId || 'vit-ce';
    const startNodeId = userContext && typeof userContext.currentNodeId === 'string' && userContext.currentNodeId.trim()
      ? userContext.currentNodeId.trim()
      : null;

    const navRequest = Object.freeze({
      buildingId: effectiveBuildingId,
      startNodeId,
      destinationNodeId: candidate.id,
      intent: effectiveIntent,
      operation: graphQuery.operation,
      semanticTarget: graphQuery.semanticTarget || candidate.name,
      resolvedTarget: Object.freeze({
        nodeId: candidate.id,
        name: candidate.name,
        category: candidate.category,
        floorNumber: candidate.floorNumber !== undefined ? candidate.floorNumber : null,
        floorName: candidate.floorName || null,
        buildingId: candidate.buildingId || effectiveBuildingId,
        accessible: candidate.accessible === true,
        department: candidate.department || null
      }),
      constraints: Object.freeze({ ...(graphQuery.filters || {}) }),
      preferences: Object.freeze({
        accessible: graphQuery.filters && graphQuery.filters.accessible === true,
        avoidStairs: graphQuery.filters && graphQuery.filters.accessible === true,
        avoidBlockedEdges: true,
        emergencyMode: effectiveIntent === 'EMERGENCY_EXIT' || graphQuery.operation === 'RESOLVE_EMERGENCY_EXIT'
      }),
      requiresNearest: graphQuery.requiresNearest === true,
      requiresRoute: true,
      confidence: graphQuery.confidence,
      ambiguity: false
    });

    // Validate the generated NavigationRequest against contracts
    const validation = this.validateNavigationRequest(navRequest);
    if (!validation.valid) {
      throw new Error(`NavigationRequest validation failed: ${validation.errors.join('; ')}`);
    }

    return navRequest;
  }

  /**
   * Validates a NavigationRequest against schema and strict security boundaries.
   *
   * @param {object} request
   * @returns {{ valid: boolean, errors: Array<string> }}
   */
  validateNavigationRequest(request) {
    const errors = [];
    if (!request || typeof request !== 'object' || Array.isArray(request)) {
      return { valid: false, errors: ['NavigationRequest must be a non-null object.'] };
    }

    // 1. JSON Schema validation
    const schemaValidation = validateContract('navigation-request', request);
    if (!schemaValidation.valid) {
      errors.push(...(schemaValidation.errors || ['Schema validation failed']));
    }

    // 2. Security scan
    scanSecurityPatterns(request, '', errors);

    // 3. Prohibit direct target node manipulation
    if (request.intent && !NAVIGATION_INTENTS.includes(request.intent)) {
      errors.push(`Invalid navigation intent: "${request.intent}". Non-navigation intents cannot produce a NavigationRequest.`);
    }

    if (request.ambiguity === true) {
      errors.push('Ambiguous requests cannot produce a validated NavigationRequest.');
    }

    if (typeof request.confidence === 'number' && request.confidence < 0.5) {
      errors.push(`Confidence (${request.confidence}) is below threshold for navigation handoff.`);
    }

    return {
      valid: errors.length === 0,
      errors
    };
  }
}

module.exports = new NavigationRequestService();
