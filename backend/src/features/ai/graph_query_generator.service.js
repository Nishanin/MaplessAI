/**
 * Graph Query Generator Service (Owner: Surabhi)
 *
 * Translates validated SLM provider extractions into controlled, structured
 * Semantic Knowledge Graph (SKG) queries.
 *
 * CRITICAL SECURITY INVARIANTS:
 * 1. This service generates structured in-memory query descriptors only — NEVER SQL or dynamic code.
 * 2. It accepts ONLY validated provider outputs conforming to the established contract.
 * 3. It STRICTLY FORBIDS direct node-selection instructions (e.g., targetNodeId or manual nodeId injection).
 *    targetNodeId is derived EXCLUSIVELY by downstream Semantic Knowledge Graph candidate resolution.
 * 4. All filters are strictly restricted to the immutable SKG whitelist.
 * 5. Prompt injection, SQL, shell commands, script tags, and URLs are aggressively scanned and rejected.
 * 6. FALLBACK intents always produce a NO_OP operation with empty filters, ensuring the SKG is never invoked.
 */

const ALLOWED_INTENTS = Object.freeze([
  'FIND_NEAREST',
  'NAVIGATE_TO',
  'LOCATE_ROOM',
  'QUERY_INFO',
  'EMERGENCY_EXIT',
  'FALLBACK'
]);

const ALLOWED_OPERATIONS = Object.freeze({
  FIND_NEAREST: 'FIND_NEAREST_TARGET',
  NAVIGATE_TO: 'RESOLVE_DESTINATION',
  LOCATE_ROOM: 'LOOKUP_LOCATION',
  QUERY_INFO: 'QUERY_FACILITY_INFO',
  EMERGENCY_EXIT: 'RESOLVE_EMERGENCY_EXIT',
  FALLBACK: 'NO_OP'
});

const ALLOWED_FILTERS = Object.freeze([
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
 * Recursively scans an object for malicious injection patterns.
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

class GraphQueryGeneratorService {
  constructor() {
    this.ALLOWED_OPERATIONS = ALLOWED_OPERATIONS;
    this.ALLOWED_FILTERS = ALLOWED_FILTERS;
  }

  /**
   * Converts validated SLM provider output into a structured, read-only SKG query.
   *
   * @param {object} providerOutput Validated output from SLM provider or extractor
   * @returns {{
   *   operation: string,
   *   filters: object,
   *   semanticTarget: string|null,
   *   requiresNearest: boolean,
   *   requiresRoute: boolean,
   *   confidence: number,
   *   ambiguity: boolean
   * }}
   */
  generateGraphQuery(providerOutput) {
    // ── 1. Structural Validation ───────────────────────────────────────────
    if (!providerOutput || typeof providerOutput !== 'object' || Array.isArray(providerOutput)) {
      throw new Error('Invalid provider output: must be a non-null object.');
    }

    const { intent, entities, constraints, confidence, ambiguity } = providerOutput;

    if (!intent || typeof intent !== 'string' || !ALLOWED_INTENTS.includes(intent)) {
      throw new Error(`Invalid or unsupported intent: "${intent}".`);
    }

    if (!Array.isArray(entities)) {
      throw new Error('Invalid provider output: entities must be an array.');
    }

    if (!constraints || typeof constraints !== 'object' || Array.isArray(constraints)) {
      throw new Error('Invalid provider output: constraints must be a plain object.');
    }

    if (typeof confidence !== 'number' || Number.isNaN(confidence) || confidence < 0.0 || confidence > 1.0) {
      throw new Error(`Invalid confidence score: must be a number between 0.0 and 1.0, received ${confidence}.`);
    }

    if (typeof ambiguity !== 'boolean') {
      throw new Error('Invalid provider output: ambiguity must be a boolean.');
    }

    // ── 2. Direct Node Selection Prohibition ────────────────────────────────
    if ('targetNodeId' in providerOutput || 'targetNodeId' in constraints) {
      throw new Error('Security violation: direct assignment of targetNodeId is strictly forbidden.');
    }

    if ('nodeId' in constraints && constraints.nodeId !== undefined && constraints.nodeId !== null) {
      throw new Error('Security violation: direct selection via nodeId filter from provider output is forbidden.');
    }

    // ── 3. Security & Injection Scanning ────────────────────────────────────
    const securityErrors = [];
    scanSecurityPatterns(providerOutput, '', securityErrors);
    if (securityErrors.length > 0) {
      throw new Error(`Security validation failed: ${securityErrors.join('; ')}`);
    }

    // ── 4. Unknown Filters Check ────────────────────────────────────────────
    for (const key of Object.keys(constraints)) {
      if (!ALLOWED_FILTERS.includes(key)) {
        throw new Error(`Unsupported filter key: "${key}" is not in the whitelist of allowed graph filters.`);
      }
    }

    // ── 5. Intent to Operation Mapping ──────────────────────────────────────
    const operation = ALLOWED_OPERATIONS[intent];
    if (!operation) {
      throw new Error(`No operation mapping defined for intent "${intent}".`);
    }

    // ── 6. Handling FALLBACK Intent ─────────────────────────────────────────
    if (intent === 'FALLBACK') {
      return Object.freeze({
        operation: 'NO_OP',
        filters: Object.freeze({}),
        semanticTarget: null,
        requiresNearest: false,
        requiresRoute: false,
        confidence: Math.min(1.0, Math.max(0.0, confidence)),
        ambiguity
      });
    }

    // ── 7. Whitelisted Filters Sanitization ─────────────────────────────────
    const sanitizedFilters = {};
    for (const key of ALLOWED_FILTERS) {
      if (
        Object.prototype.hasOwnProperty.call(constraints, key) &&
        constraints[key] !== undefined &&
        constraints[key] !== null &&
        key !== 'nodeId' // Guaranteed exclusion of direct node IDs
      ) {
        sanitizedFilters[key] = constraints[key];
      }
    }

    // Special case: EMERGENCY_EXIT always targets the emergency_exit category
    if (intent === 'EMERGENCY_EXIT') {
      sanitizedFilters.category = 'emergency_exit';
    }

    // ── 8. Semantic Target Extraction ───────────────────────────────────────
    let semanticTarget = null;

    if (intent === 'EMERGENCY_EXIT') {
      semanticTarget = 'emergency_exit';
    } else if (sanitizedFilters.alias) {
      semanticTarget = sanitizedFilters.alias;
    } else if (sanitizedFilters.name) {
      semanticTarget = sanitizedFilters.name;
    } else if (sanitizedFilters.category) {
      semanticTarget = sanitizedFilters.category;
    } else if (sanitizedFilters.department) {
      semanticTarget = sanitizedFilters.department;
    } else if (sanitizedFilters.facility) {
      semanticTarget = sanitizedFilters.facility;
    } else {
      // Look into entities array as secondary lookup
      const targetEntity = entities.find(e =>
        e && ['alias', 'room_name', 'category', 'department', 'facility'].includes(e.type)
      );
      if (targetEntity && targetEntity.value) {
        semanticTarget = targetEntity.value;
      }
    }

    // ── 9. Meaningful Target Validation for Active Queries ──────────────────
    if (!semanticTarget && Object.keys(sanitizedFilters).length === 0) {
      throw new Error(`Empty semantic target: intent "${intent}" requires at least one identifiable target or filter.`);
    }

    // ── 10. Operational Flags Assignment ───────────────────────────────────
    const requiresNearest = intent === 'FIND_NEAREST' || intent === 'EMERGENCY_EXIT';
    const requiresRoute = intent === 'NAVIGATE_TO' || intent === 'FIND_NEAREST' || intent === 'EMERGENCY_EXIT';

    const graphQuery = Object.freeze({
      operation,
      filters: Object.freeze(sanitizedFilters),
      semanticTarget,
      requiresNearest,
      requiresRoute,
      confidence: Math.min(1.0, Math.max(0.0, confidence)),
      ambiguity
    });

    return graphQuery;
  }

  /**
   * Validates that a query object strictly adheres to the graph query format.
   *
   * @param {object} query
   * @returns {{ valid: boolean, errors: Array<string> }}
   */
  validateGraphQuery(query) {
    const errors = [];
    if (!query || typeof query !== 'object') {
      return { valid: false, errors: ['Graph query must be a non-null object.'] };
    }

    const requiredKeys = [
      'operation',
      'filters',
      'semanticTarget',
      'requiresNearest',
      'requiresRoute',
      'confidence',
      'ambiguity'
    ];

    for (const key of requiredKeys) {
      if (!(key in query)) {
        errors.push(`Missing required graph query field: "${key}".`);
      }
    }

    if (query.operation && !Object.values(ALLOWED_OPERATIONS).includes(query.operation)) {
      errors.push(`Invalid graph query operation: "${query.operation}".`);
    }

    if (query.filters && (typeof query.filters !== 'object' || Array.isArray(query.filters))) {
      errors.push('Graph query filters must be a plain object.');
    } else if (query.filters) {
      if ('targetNodeId' in query.filters || 'nodeId' in query.filters) {
        errors.push('Direct node-selection fields are strictly forbidden in graph query filters.');
      }
      for (const k of Object.keys(query.filters)) {
        if (!ALLOWED_FILTERS.includes(k)) {
          errors.push(`Unknown filter key: "${k}".`);
        }
      }
    }

    if (query.confidence !== undefined && (typeof query.confidence !== 'number' || query.confidence < 0 || query.confidence > 1)) {
      errors.push('Graph query confidence must be a number between 0.0 and 1.0.');
    }

    if (query.ambiguity !== undefined && typeof query.ambiguity !== 'boolean') {
      errors.push('Graph query ambiguity must be a boolean.');
    }

    return {
      valid: errors.length === 0,
      errors
    };
  }
}

module.exports = new GraphQueryGeneratorService();
