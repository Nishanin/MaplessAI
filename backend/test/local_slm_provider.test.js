const { getSlmProvider, validateProviderOutput } = require('../src/features/ai/slm_provider');
const { LocalSlmProvider } = require('../src/features/ai/local_slm_provider');
const { MockSlmProvider } = require('../src/features/ai/mock_slm_provider');

/**
 * Local SLM Provider Unit Tests (Owner: Surabhi)
 *
 * Tests cover:
 *   1. Provider selection for 'local'.
 *   2. Successful valid JSON response parsing.
 *   3. Malformed JSON handling returns safe fallback.
 *   4. Unsupported intent handling.
 *   5. Unsupported entity type handling.
 *   6. Unsupported constraint key handling.
 *   7. Forbidden targetNodeId handling.
 *   8. Runtime failure / connection failure.
 *   9. Timeout behavior.
 *   10. No regression in existing mock and deterministic providers.
 */

describe('LocalSlmProvider — Unit Tests (with Mocked Fetch)', () => {
  // Helper to create a fake fetch client returning given status and payload
  function createMockFetch(status, responsePayload, throwsError = null) {
    return jest.fn().mockImplementation(() => {
      if (throwsError) {
        return Promise.reject(throwsError);
      }
      return Promise.resolve({
        ok: status >= 200 && status < 300,
        status,
        json: async () => responsePayload
      });
    });
  }

  // ── 1. Provider Selection ─────────────────────────────────────────────────
  it('1. should select and instantiate LocalSlmProvider when provider is "local"', () => {
    const provider = getSlmProvider('local');
    expect(provider).toBeInstanceOf(LocalSlmProvider);
    expect(provider.baseUrl).toBe('http://localhost:11434');
    expect(provider.model).toBe('llama3.2');
  });

  // ── 2. Successful Valid JSON Response ─────────────────────────────────────
  it('2. should parse successful Ollama JSON output into structured query', async () => {
    const mockModelOutput = {
      intent: 'FIND_NEAREST',
      entities: [{ type: 'category', value: 'laboratory' }],
      constraints: { category: 'laboratory', accessible: true },
      confidence: 0.92,
      ambiguity: false,
      reason: 'user requested nearest lab'
    };

    const mockFetch = createMockFetch(200, {
      response: JSON.stringify(mockModelOutput)
    });

    const provider = new LocalSlmProvider({ fetchClient: mockFetch });
    const result = await provider.generateStructuredQuery({
      text: 'Where is the nearest lab?'
    });

    expect(result.intent).toBe('FIND_NEAREST');
    expect(result.constraints.category).toBe('laboratory');
    expect(result.confidence).toBe(0.92);
    expect(result.ambiguity).toBe(false);

    // Verify it passes strict provider output validation
    const validated = validateProviderOutput(result);
    expect(validated.valid).toBe(true);
    expect(mockFetch).toHaveBeenCalledTimes(1);
  });

  // ── 3. Malformed JSON Response ────────────────────────────────────────────
  it('3. should return safe fallback when model returns malformed non-JSON output', async () => {
    const mockFetch = createMockFetch(200, {
      response: 'I am an AI and I think you want the lab: { invalid json }'
    });

    const provider = new LocalSlmProvider({ fetchClient: mockFetch });
    const result = await provider.generateStructuredQuery({
      text: 'Where is the lab?'
    });

    expect(result.intent).toBe('FALLBACK');
    expect(result.confidence).toBe(0.0);
    expect(result.reason).toMatch(/malformed non-JSON/i);

    const validated = validateProviderOutput(result);
    expect(validated.valid).toBe(true);
  });

  // ── 4. Unsupported Intent ─────────────────────────────────────────────────
  it('4. should be rejected by validation when model emits unsupported intent', async () => {
    const mockModelOutput = {
      intent: 'EXPLODE_BUILDING',
      entities: [],
      constraints: {},
      confidence: 0.85,
      ambiguity: false,
      reason: 'malicious intent'
    };

    const mockFetch = createMockFetch(200, {
      response: JSON.stringify(mockModelOutput)
    });

    const provider = new LocalSlmProvider({ fetchClient: mockFetch });
    const result = await provider.generateStructuredQuery({ text: 'explode' });

    expect(result.intent).toBe('EXPLODE_BUILDING');
    const validated = validateProviderOutput(result);
    expect(validated.valid).toBe(false);
    expect(validated.errors.some(e => e.includes('Invalid intent'))).toBe(true);
  });

  // ── 5. Unsupported Entity Type ────────────────────────────────────────────
  it('5. should be rejected by validation when model emits unsupported entity type', async () => {
    const mockModelOutput = {
      intent: 'LOCATE_ROOM',
      entities: [{ type: 'astrological_sign', value: 'scorpio' }],
      constraints: {},
      confidence: 0.8,
      ambiguity: false,
      reason: 'weird entity'
    };

    const mockFetch = createMockFetch(200, {
      response: JSON.stringify(mockModelOutput)
    });

    const provider = new LocalSlmProvider({ fetchClient: mockFetch });
    const result = await provider.generateStructuredQuery({ text: 'room scorpio' });

    const validated = validateProviderOutput(result);
    expect(validated.valid).toBe(false);
    expect(validated.errors.some(e => e.includes('Unsupported entity type'))).toBe(true);
  });

  // ── 6. Unsupported Constraint Key ─────────────────────────────────────────
  it('6. should be rejected by validation when model emits unknown constraint keys', async () => {
    const mockModelOutput = {
      intent: 'LOCATE_ROOM',
      entities: [],
      constraints: { arbitrarySqlPayload: "SELECT * FROM users" },
      confidence: 0.8,
      ambiguity: false,
      reason: 'test'
    };

    const mockFetch = createMockFetch(200, {
      response: JSON.stringify(mockModelOutput)
    });

    const provider = new LocalSlmProvider({ fetchClient: mockFetch });
    const result = await provider.generateStructuredQuery({ text: 'find room' });

    const validated = validateProviderOutput(result);
    expect(validated.valid).toBe(false);
    expect(validated.errors.some(e => e.includes('Unknown constraint field'))).toBe(true);
  });

  // ── 7. Forbidden targetNodeId ─────────────────────────────────────────────
  it('7. should return fallback when model attempts to emit targetNodeId', async () => {
    const mockModelOutput = {
      intent: 'FIND_NEAREST',
      entities: [{ type: 'category', value: 'laboratory' }],
      constraints: { category: 'laboratory' },
      targetNodeId: 'lab-101', // Strictly forbidden for the SLM to decide!
      confidence: 0.9,
      ambiguity: false,
      reason: 'sneaky model choosing destination'
    };

    const mockFetch = createMockFetch(200, {
      response: JSON.stringify(mockModelOutput)
    });

    const provider = new LocalSlmProvider({ fetchClient: mockFetch });
    const result = await provider.generateStructuredQuery({ text: 'Where is lab?' });

    // LocalSlmProvider actively catches and rejects targetNodeId
    expect(result.intent).toBe('FALLBACK');
    expect(result.confidence).toBe(0.0);
    expect(result.reason).toMatch(/forbidden field targetNodeId/i);
  });

  // ── 8. Runtime Failure (Connection Error / 500) ───────────────────────────
  it('8. should return safe fallback when local runtime returns 500 or connection error', async () => {
    // Case A: HTTP 500
    const mockFetch500 = createMockFetch(500, { error: 'Ollama internal error' });
    const provider500 = new LocalSlmProvider({ fetchClient: mockFetch500 });
    const result500 = await provider500.generateStructuredQuery({ text: 'Where is the lab?' });

    expect(result500.intent).toBe('FALLBACK');
    expect(result500.confidence).toBe(0.0);
    expect(result500.reason).toMatch(/HTTP 500/i);

    // Case B: Connection refused (fetch throws TypeError / ECONNREFUSED)
    const mockFetchConnRefused = createMockFetch(0, null, new Error('connect ECONNREFUSED 127.0.0.1:11434'));
    const providerConn = new LocalSlmProvider({ fetchClient: mockFetchConnRefused });
    const resultConn = await providerConn.generateStructuredQuery({ text: 'Where is the lab?' });

    expect(resultConn.intent).toBe('FALLBACK');
    expect(resultConn.confidence).toBe(0.0);
    expect(resultConn.reason).toMatch(/unavailable/i);
  });

  // ── 9. Timeout Behavior ───────────────────────────────────────────────────
  it('9. should return safe fallback when request times out', async () => {
    const abortError = new Error('The operation was aborted');
    abortError.name = 'AbortError';

    const mockFetchTimeout = createMockFetch(0, null, abortError);
    const provider = new LocalSlmProvider({
      timeoutMs: 50,
      fetchClient: mockFetchTimeout
    });

    const result = await provider.generateStructuredQuery({ text: 'Where is the lab?' });
    expect(result.intent).toBe('FALLBACK');
    expect(result.confidence).toBe(0.0);
    expect(result.reason).toMatch(/timed out/i);
  });

  // ── 10. No Regression in Existing Providers ───────────────────────────────
  it('10. deterministic and mock providers continue functioning identically', async () => {
    const detProvider = getSlmProvider('deterministic');
    expect(detProvider).toBeInstanceOf(MockSlmProvider);

    const detResult = await detProvider.generateStructuredQuery({
      text: 'Find emergency exit'
    });
    expect(detResult.intent).toBe('EMERGENCY_EXIT');
    expect(detResult.constraints.category).toBe('emergency_exit');
  });
});
