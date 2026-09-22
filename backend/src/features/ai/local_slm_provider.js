const { BaseSlmProvider } = require('./slm_provider');

/**
 * Local SLM Provider Adapter (Owner: Surabhi)
 *
 * Implements BaseSlmProvider for local LLM/SLM runtimes (such as Ollama).
 * Queries the local runtime via HTTP with strict timeouts, json formatting,
 * and security gates.
 *
 * CRITICAL SECURITY INVARIANTS:
 * 1. Model output is strictly constrained to structured query JSON.
 * 2. The adapter NEVER executes model-generated code, SQL, or shell commands.
 * 3. The adapter rejects model-emitted destination IDs (targetNodeId).
 * 4. Timeouts and runtime connection failures return safe, controlled fallbacks
 *    without leaking stack traces or crashing the controller.
 * 5. Configuration is environment-driven with safe defaults (no hardcoded secrets).
 */
class LocalSlmProvider extends BaseSlmProvider {
  /**
   * @param {object} [options]
   * @param {string} [options.baseUrl] Local runtime base URL (default: process.env.SLM_BASE_URL || 'http://localhost:11434')
   * @param {string} [options.model] Local model identifier (default: process.env.SLM_MODEL || 'llama3.2')
   * @param {number} [options.timeoutMs] Timeout in ms (default: process.env.SLM_TIMEOUT_MS || 10000)
   * @param {Function} [options.fetchClient] Dependency-injected fetch implementation (defaults to globalThis.fetch)
   */
  constructor(options = {}) {
    super();
    this.baseUrl = (options.baseUrl || process.env.SLM_BASE_URL || 'http://localhost:11434').replace(/\/+$/, '');
    this.model = options.model || process.env.SLM_MODEL || 'llama3.2';
    this.timeoutMs = typeof options.timeoutMs === 'number'
      ? options.timeoutMs
      : (parseInt(process.env.SLM_TIMEOUT_MS, 10) || 10000);
    this.fetchClient = options.fetchClient || globalThis.fetch;
  }

  /**
   * Builds the scoped prompt for the local SLM to extract indoor query semantics.
   * @private
   */
  _buildPrompt(text, userContext) {
    const accessibleHint = userContext && userContext.accessible ? ' User requires accessible routing.' : '';
    const floorHint = userContext && userContext.currentFloorId ? ` Current floor ID: ${userContext.currentFloorId}.` : '';

    return `You are the indoor query extraction engine for MapLess AI.
Analyze the user query and output a strictly valid JSON object.

Allowed intents:
- "FIND_NEAREST": user seeks the nearest room, amenity, or category.
- "NAVIGATE_TO": user wants directions to a destination.
- "LOCATE_ROOM": user asks where a room or location is.
- "QUERY_INFO": user asks about hours, wifi, or facility information.
- "EMERGENCY_EXIT": user needs to evacuate or find emergency exits.
- "FALLBACK": query is off-topic, unsupported, or cannot be understood.

Allowed entity types: "category", "room_name", "alias", "department", "facility", "accessibility", "floor", "node".
Allowed constraint keys: "nodeId", "name", "alias", "category", "tag", "department", "accessible", "facility", "floor", "capacityMin".

CRITICAL SECURITY RULES:
1. NEVER output "targetNodeId". Destination selection is reserved exclusively for the graph engine.
2. Output ONLY the JSON object. No markdown ticks, no commentary.

Expected JSON schema:
{
  "intent": string,
  "entities": [ { "type": string, "value": string } ],
  "constraints": { ... },
  "confidence": float (0.0 to 1.0),
  "ambiguity": boolean,
  "reason": string
}

User query: "${text}"${accessibleHint}${floorHint}`;
  }

  /**
   * Generates a structured query by invoking the local SLM endpoint.
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
    if (!input || typeof input !== 'object' || typeof input.text !== 'string' || !input.text.trim()) {
      return this._buildFallback('empty or invalid query text');
    }

    const promptText = this._buildPrompt(input.text, input.userContext);
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.timeoutMs);

    try {
      const response = await this.fetchClient(`${this.baseUrl}/api/generate`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          model: this.model,
          prompt: promptText,
          stream: false,
          format: 'json'
        }),
        signal: controller.signal
      });
      clearTimeout(timer);

      if (!response.ok) {
        return this._buildFallback(`local SLM runtime error: HTTP ${response.status}`);
      }

      const data = await response.json();
      const rawText = data && typeof data.response === 'string' ? data.response.trim() : '';

      let parsed;
      try {
        parsed = JSON.parse(rawText);
      } catch (err) {
        return this._buildFallback('model returned malformed non-JSON output');
      }

      if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
        return this._buildFallback('model returned non-object JSON');
      }

      // Security Invariant: Model MUST NOT emit targetNodeId
      if (parsed.targetNodeId !== undefined && parsed.targetNodeId !== null) {
        return this._buildFallback('forbidden field targetNodeId emitted by model');
      }

      return {
        intent: typeof parsed.intent === 'string' ? parsed.intent : 'FALLBACK',
        entities: Array.isArray(parsed.entities) ? parsed.entities : [],
        constraints: parsed.constraints && typeof parsed.constraints === 'object' && !Array.isArray(parsed.constraints) ? parsed.constraints : {},
        confidence: typeof parsed.confidence === 'number' ? parsed.confidence : 0.0,
        ambiguity: typeof parsed.ambiguity === 'boolean' ? parsed.ambiguity : false,
        reason: typeof parsed.reason === 'string' ? parsed.reason : 'local SLM extraction'
      };
    } catch (err) {
      clearTimeout(timer);
      if (err.name === 'AbortError' || err.code === 'ABORT_ERR') {
        return this._buildFallback('local SLM request timed out');
      }
      return this._buildFallback('local SLM runtime unavailable');
    }
  }

  /**
   * Helper: Builds a safe fallback structured result.
   * @private
   */
  _buildFallback(reason) {
    return {
      intent: 'FALLBACK',
      entities: [],
      constraints: {},
      confidence: 0.0,
      ambiguity: false,
      reason
    };
  }
}

module.exports = {
  LocalSlmProvider
};
