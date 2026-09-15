/**
 * Safe SLM Provider Interface & Output Validator (Owner: Surabhi)
 *
 * Defines the abstract provider contract, strict output validation and normalization,
 * and safe provider selection.
 *
 * CRITICAL SECURITY INVARIANTS:
 * 1. Providers return structured extraction data only — NEVER executable code or SQL.
 * 2. Providers are strictly FORBIDDEN from deciding or returning destination node IDs.
 *    targetNodeId is derived exclusively by the SemanticGraphService.
 * 3. Non-whitelisted constraint fields are stripped during validation.
 * 4. Provider selection is restricted to a fixed allowlist of local providers.
 * 5. No network, database, shell, or arbitrary module loading is permitted.
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

const ALLOWED_PROVIDERS = Object.freeze(['deterministic', 'mock']);

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
 * Validates and normalizes raw provider output.
 * Ensures the output complies with schema requirements, whitelists, and security boundaries.
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

  // 1. Validate intent
  if (typeof output.intent !== 'string' || !ALLOWED_INTENTS.includes(output.intent)) {
    errors.push(`Invalid intent: "${output.intent}". Allowed intents: ${ALLOWED_INTENTS.join(', ')}.`);
  }

  // 2. Validate confidence
  if (typeof output.confidence !== 'number' || isNaN(output.confidence) || output.confidence < 0.0 || output.confidence > 1.0) {
    errors.push(`Invalid confidence: ${output.confidence}. Must be a float between 0.0 and 1.0.`);
  }

  // 3. Validate ambiguity
  if (typeof output.ambiguity !== 'boolean') {
    errors.push(`Invalid ambiguity: ${output.ambiguity}. Must be a boolean.`);
  }

  // 4. Validate reason
  if (typeof output.reason !== 'string') {
    errors.push('Invalid reason: must be a plain text string.');
  }

  // 5. Validate entities
  const normalizedEntities = [];
  if (!Array.isArray(output.entities)) {
    errors.push('Invalid entities: must be an array.');
  } else {
    for (let i = 0; i < output.entities.length; i++) {
      const ent = output.entities[i];
      if (!ent || typeof ent !== 'object' || typeof ent.type !== 'string' || typeof ent.value !== 'string') {
        errors.push(`Invalid entity at index ${i}: must be an object with { type: string, value: string }.`);
      } else if (!ALLOWED_ENTITY_TYPES.includes(ent.type)) {
        errors.push(`Unsupported entity type "${ent.type}" at index ${i}.`);
      } else {
        normalizedEntities.push({
          type: ent.type,
          value: String(ent.value)
        });
      }
    }
  }

  // 6. Validate and whitelist constraints
  const normalizedConstraints = {};
  if (output.constraints !== undefined && output.constraints !== null) {
    if (typeof output.constraints !== 'object' || Array.isArray(output.constraints)) {
      errors.push('Invalid constraints: must be an object.');
    } else {
      for (const [key, value] of Object.entries(output.constraints)) {
        if (!ALLOWED_CONSTRAINTS.includes(key)) {
          // Unknown / non-whitelisted constraint key: safely strip or record error
          // In MapLess AI, we safely reject non-whitelisted keys to avoid unexpected interpretation
          errors.push(`Unknown constraint field "${key}" is not permitted.`);
        } else if (value !== undefined && value !== null) {
          // Type-check recognized constraint fields
          if (key === 'accessible' && typeof value !== 'boolean') {
            errors.push('Constraint "accessible" must be a boolean.');
          } else if ((key === 'floor' || key === 'capacityMin') && typeof value !== 'number') {
            errors.push(`Constraint "${key}" must be a number.`);
          } else {
            normalizedConstraints[key] = value;
          }
        }
      }
    }
  }

  // 7. Security Invariant: Providers MUST NOT supply targetNodeId
  if (output.targetNodeId !== undefined && output.targetNodeId !== null) {
    errors.push('Security violation: Provider cannot supply targetNodeId. Destination resolution is reserved for SemanticGraphService.');
  }

  if (errors.length > 0) {
    return {
      valid: false,
      errors,
      normalized: null
    };
  }

  return {
    valid: true,
    errors: [],
    normalized: {
      intent: output.intent,
      entities: normalizedEntities,
      constraints: normalizedConstraints,
      confidence: output.confidence,
      ambiguity: output.ambiguity,
      reason: output.reason
    }
  };
}

/**
 * Provider factory: returns the configured SLM provider instance.
 *
 * @param {string} [requestedProvider] Optional explicit provider name
 * @returns {BaseSlmProvider}
 */
function getSlmProvider(requestedProvider) {
  const providerName = (requestedProvider || process.env.SLM_PROVIDER || 'deterministic').toLowerCase().trim();

  if (!ALLOWED_PROVIDERS.includes(providerName)) {
    throw new Error(`Unsupported SLM provider: "${providerName}". Allowed providers: ${ALLOWED_PROVIDERS.join(', ')}.`);
  }

  // Lazy require to avoid circular dependencies
  const { MockSlmProvider } = require('./mock_slm_provider');

  switch (providerName) {
    case 'mock':
    case 'deterministic':
    default:
      return MockSlmProvider.getInstance();
  }
}

module.exports = {
  BaseSlmProvider,
  validateProviderOutput,
  getSlmProvider,
  ALLOWED_INTENTS,
  ALLOWED_ENTITY_TYPES,
  ALLOWED_CONSTRAINTS,
  ALLOWED_PROVIDERS
};
