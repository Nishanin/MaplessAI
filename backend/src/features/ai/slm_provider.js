const { validateContract } = require('../../utils/schema_validator');

/**
 * Safe SLM Provider Interface & Hardened Output Validator (Owner: Surabhi)
 *
 * Defines the abstract provider contract, strict JSON schema and semantic
 * consistency validation, and safe provider selection.
 *
 * CRITICAL SECURITY INVARIANTS:
 * 1. Providers return structured extraction data only — NEVER executable code or SQL.
 * 2. Providers are strictly FORBIDDEN from deciding or returning destination node IDs.
 *    targetNodeId is derived exclusively by the SemanticGraphService.
 * 3. Unexpected or non-whitelisted fields are strictly rejected via JSON schema validation.
 * 4. Injection patterns (SQL, script tags, URLs, shell commands) are strictly detected and rejected.
 * 5. Provider selection is restricted to a fixed allowlist of local providers.
 * 6. Semantic consistency rules guarantee that navigation and lookup intents contain
 *    valid entity and constraint targets before reaching the Semantic Knowledge Graph.
 */

const ALLOWED_INTENTS = Object.freeze([
  'FIND_NEAREST',
  'NAVIGATE_TO',
  'LOCATE_ROOM',
  'QUERY_INFO',
  'EMERGENCY_EXIT',
  'FALLBACK'
]);

const ALLOWED_ENTITY_TYPES = Object.freeze([
  'category',
  'room_name',
  'alias',
  'department',
  'facility',
  'accessibility',
  'floor',
  'node'
]);

const ALLOWED_CONSTRAINTS = Object.freeze([
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

const ALLOWED_PROVIDERS = Object.freeze(['deterministic', 'mock', 'local']);

const FORBIDDEN_SECURITY_PATTERNS = Object.freeze([
  {
    name: 'SQL statement',
    regex: /\b(SELECT\s+.*\s+FROM|INSERT\s+INTO|UPDATE\s+\w+\s+SET|DELETE\s+FROM|DROP\s+TABLE|UNION\s+SELECT|ALTER\s+TABLE)\b/i
  },
  {
    name: 'Script tag / HTML code',
    regex: /<script\b[^>]*>/i
  },
  {
    name: 'URL / external endpoint',
    regex: /\b(https?:\/\/|ftp:\/\/|file:\/\/)\b/i
  },
  {
    name: 'Shell command',
    regex: /\b(rm\s+-rf|chmod\s+|sh\s+-c|bash\s+-c|curl\s+|wget\s+)\b/i
  }
]);

/**
 * Abstract Base Class for SLM Providers.
 */
class BaseSlmProvider {
  /**
   * Generates a structured query from natural language input.
   *
   * @param {{ text: string, userContext?: object }} input
   * @returns {Promise<{
   *   intent: string,
   *   entities: Array<{ type: string, value: string }>,
   *   constraints: object,
   *   confidence: number,
   *   ambiguity: boolean,
   *   reason: string
   * }>}
   */
  async generateStructuredQuery(input) {
    throw new Error('generateStructuredQuery must be implemented by SLM provider subclass.');
  }
}

/**
 * Recursively scans an object for malicious injection patterns.
 * @private
 */
function scanForSecurityViolations(obj, path, errors) {
  if (typeof obj === 'string') {
    for (const pattern of FORBIDDEN_SECURITY_PATTERNS) {
      if (pattern.regex.test(obj)) {
        errors.push(`Security violation: Forbidden pattern (${pattern.name}) detected in ${path || 'value'}.`);
      }
    }
  } else if (Array.isArray(obj)) {
    obj.forEach((item, index) => scanForSecurityViolations(item, `${path}[${index}]`, errors));
  } else if (obj && typeof obj === 'object') {
    for (const [k, v] of Object.entries(obj)) {
      scanForSecurityViolations(v, path ? `${path}.${k}` : k, errors);
    }
  }
}

/**
 * Validates semantic consistency between recognized intent and extracted entities/constraints.
 * @private
 */
function validateSemanticConsistency(output, errors) {
  if (!output.intent || typeof output.intent !== 'string') return;

  const hasEntityOfTypes = (...types) =>
    Array.isArray(output.entities) && output.entities.some(e => e && types.includes(e.type));

  const hasConstraintOfKeys = (...keys) =>
    output.constraints &&
    typeof output.constraints === 'object' &&
    keys.some(k => output.constraints[k] !== undefined && output.constraints[k] !== null);

  switch (output.intent) {
    case 'NAVIGATE_TO': {
      // Must contain a meaningful destination entity or constraint
      const hasDestination =
        hasEntityOfTypes('room_name', 'alias', 'category', 'facility', 'department', 'node') ||
        hasConstraintOfKeys('name', 'alias', 'category', 'facility', 'department', 'nodeId');
      if (!hasDestination) {
        errors.push('Semantic consistency violation: NAVIGATE_TO intent requires a meaningful destination entity or constraint.');
      }
      break;
    }
    case 'FIND_NEAREST': {
      // Must contain a meaningful facility/category/entity target
      const hasTarget =
        hasEntityOfTypes('category', 'facility', 'alias', 'room_name') ||
        hasConstraintOfKeys('category', 'facility', 'alias', 'name');
      if (!hasTarget) {
        errors.push('Semantic consistency violation: FIND_NEAREST intent requires a target category, facility, alias, or room entity.');
      }
      break;
    }
    case 'LOCATE_ROOM': {
      // Must contain room-related entity or constraint
      const hasRoomTarget =
        hasEntityOfTypes('room_name', 'alias', 'category', 'department', 'node') ||
        hasConstraintOfKeys('name', 'alias', 'category', 'department', 'nodeId');
      if (!hasRoomTarget) {
        errors.push('Semantic consistency violation: LOCATE_ROOM intent requires room-related entity or constraint.');
      }
      break;
    }
    case 'EMERGENCY_EXIT': {
      // Must not target an incompatible non-exit specific room without emergency exit category
      if (hasConstraintOfKeys('name') && !hasConstraintOfKeys('category')) {
        errors.push('Semantic consistency violation: EMERGENCY_EXIT must target emergency exit category rather than unrelated specific rooms.');
      }
      break;
    }
    case 'FALLBACK':
    case 'QUERY_INFO':
    default:
      break;
  }
}

/**
 * Hardened validation and normalization of raw provider output.
 * Enforces JSON schema contract, security boundaries, and semantic consistency.
 *
 * @param {any} output Raw provider output
 * @returns {{
 *   valid: boolean,
 *   errors: Array<string>,
 *   normalized: object|null
 * }}
 */
function validateProviderOutput(output) {
  const errors = [];

  if (!output || typeof output !== 'object' || Array.isArray(output)) {
    return {
      valid: false,
      errors: ['Provider output must be a non-null object.'],
      normalized: null
    };
  }

  // ── 1. Security Invariant: Providers MUST NOT supply targetNodeId ─────────
  if (output.targetNodeId !== undefined) {
    errors.push('Security violation: Provider cannot supply targetNodeId. Destination resolution is reserved for SemanticGraphService.');
  }

  // ── 2. Strict Type Checks Before Coercion ─────────────────────────────────
  if (typeof output.intent !== 'string' || !ALLOWED_INTENTS.includes(output.intent)) {
    errors.push(`Invalid intent: "${output.intent}". Allowed intents: ${ALLOWED_INTENTS.join(', ')}.`);
  }

  if (output.confidence === null || typeof output.confidence !== 'number' || isNaN(output.confidence) || output.confidence < 0.0 || output.confidence > 1.0) {
    errors.push(`Invalid confidence: ${output.confidence}. Must be a float between 0.0 and 1.0.`);
  }

  if (typeof output.ambiguity !== 'boolean') {
    errors.push(`Invalid ambiguity: ${output.ambiguity}. Must be a boolean.`);
  }

  if (output.entities && Array.isArray(output.entities)) {
    output.entities.forEach((ent, idx) => {
      if (!ent || typeof ent !== 'object' || typeof ent.type !== 'string' || typeof ent.value !== 'string') {
        errors.push(`Invalid entity at index ${idx}: must be an object with { type: string, value: string }.`);
      } else if (!ALLOWED_ENTITY_TYPES.includes(ent.type)) {
        errors.push(`Unsupported entity type "${ent.type}" at index ${idx}.`);
      }
    });
  } else if (!output.entities || !Array.isArray(output.entities)) {
    errors.push('Invalid entities: must be an array.');
  }

  if (output.constraints && typeof output.constraints === 'object' && !Array.isArray(output.constraints)) {
    for (const key of Object.keys(output.constraints)) {
      if (!ALLOWED_CONSTRAINTS.includes(key)) {
        errors.push(`Unknown constraint field "${key}" is not permitted.`);
      }
    }
  } else if (output.constraints !== undefined && (typeof output.constraints !== 'object' || output.constraints === null || Array.isArray(output.constraints))) {
    errors.push('Invalid constraints: must be an object.');
  }

  // ── 3. Formal JSON Schema Contract Validation (run on clone to avoid mutation) ─
  try {
    const clone = JSON.parse(JSON.stringify(output));
    const contractValidation = validateContract('slm-provider-output', clone);
    if (!contractValidation.valid) {
      for (const err of contractValidation.errors) {
        const field = err.instancePath ? err.instancePath.replace(/^\//, '') : 'output';
        if (err.keyword === 'additionalProperties') {
          const msg = `Unknown field "${err.params.additionalProperty}" is not permitted in provider output.`;
          if (!errors.includes(msg)) errors.push(msg);
        } else if (err.keyword === 'required') {
          const msg = `Missing required field: ${err.params.missingProperty}.`;
          if (!errors.includes(msg)) errors.push(msg);
        }
      }
    }
  } catch (e) {
    // If serialization fails, it will already be caught by object check
  }

  // ── 4. Security & Injection Scanning ──────────────────────────────────────
  scanForSecurityViolations(output, '', errors);

  // ── 5. Semantic Consistency Validation ────────────────────────────────────
  validateSemanticConsistency(output, errors);

  if (errors.length > 0) {
    return {
      valid: false,
      errors,
      normalized: null
    };
  }

  // Safe normalized output
  return {
    valid: true,
    errors: [],
    normalized: {
      intent: output.intent,
      entities: output.entities.map(e => ({ type: e.type, value: String(e.value) })),
      constraints: { ...output.constraints },
      confidence: output.confidence,
      ambiguity: output.ambiguity,
      reason: typeof output.reason === 'string' ? output.reason : ''
    }
  };
}

/**
 * Provider factory: returns the configured SLM provider instance.
 *
 * @param {string} [requestedProvider] Optional explicit provider name
 * @param {object} [options] Optional provider initialization options
 * @returns {BaseSlmProvider}
 */
function getSlmProvider(requestedProvider, options = {}) {
  const providerName = (requestedProvider || process.env.SLM_PROVIDER || 'deterministic').toLowerCase().trim();

  if (!ALLOWED_PROVIDERS.includes(providerName)) {
    throw new Error(`Unsupported SLM provider: "${providerName}". Allowed providers: ${ALLOWED_PROVIDERS.join(', ')}.`);
  }

  // Lazy require to avoid circular dependencies
  const { MockSlmProvider } = require('./mock_slm_provider');

  switch (providerName) {
    case 'local': {
      const { LocalSlmProvider } = require('./local_slm_provider');
      return new LocalSlmProvider(options);
    }
    case 'mock':
    case 'deterministic':
    default:
      return MockSlmProvider.getInstance();
  }
}

module.exports = {
  BaseSlmProvider,
  validateProviderOutput,
  validateSemanticConsistency,
  getSlmProvider,
  ALLOWED_INTENTS,
  ALLOWED_ENTITY_TYPES,
  ALLOWED_CONSTRAINTS,
  ALLOWED_PROVIDERS
};
