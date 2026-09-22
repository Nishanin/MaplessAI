const { BaseSlmProvider } = require('./slm_provider');
const queryExtractorService = require('./query_extractor.service');

/**
 * Deterministic Mock SLM Provider (Owner: Surabhi)
 *
 * Provides safe, local, deterministic structured query generation for MapLess AI.
 * Backed by QueryExtractorService by default, with optional test hook support.
 *
 * CRITICAL SECURITY INVARIANTS:
 * 1. ZERO network calls.
 * 2. ZERO database access or SQL execution.
 * 3. ZERO filesystem access beyond normal Node.js module loading.
 * 4. NEVER invents destination node IDs.
 * 5. Returns structured extraction objects adhering to MapLess AI contracts.
 */
class MockSlmProvider extends BaseSlmProvider {
  constructor() {
    super();
    this._customMockHandler = null;
  }

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
    if (!input || typeof input !== 'object') {
      return {
        intent: 'FALLBACK',
        entities: [],
        constraints: {},
        confidence: 0.0,
        ambiguity: false,
        reason: 'invalid provider input payload'
      };
    }

    // Allow test suites to inject custom mock responses if explicitly configured
    if (typeof this._customMockHandler === 'function') {
      return this._customMockHandler(input);
    }
    if (this._customMockHandler && typeof this._customMockHandler === 'object') {
      return JSON.parse(JSON.stringify(this._customMockHandler));
    }

    const text = input.text || '';
    const userContext = input.userContext || null;

    // Default deterministic extraction backed by QueryExtractorService
    const result = queryExtractorService.extractQuery(text, userContext);
    return {
      intent: result.intent,
      entities: [...result.entities],
      constraints: { ...result.constraints },
      confidence: result.confidence,
      ambiguity: result.ambiguity,
      reason: result.reason
    };
  }

  /**
   * Test Hook: Configures a custom mock response or handler for unit testing.
   * @param {object|Function|null} handler
   */
  setMockResponse(handler) {
    this._customMockHandler = handler;
  }

  /**
   * Test Hook: Clears custom mock responses, restoring default deterministic extraction.
   */
  clearMockResponse() {
    this._customMockHandler = null;
  }

  /**
   * Returns singleton instance.
   * @returns {MockSlmProvider}
   */
  static getInstance() {
    if (!MockSlmProvider._instance) {
      MockSlmProvider._instance = new MockSlmProvider();
    }
    return MockSlmProvider._instance;
  }
}

MockSlmProvider._instance = null;

module.exports = {
  MockSlmProvider
};
