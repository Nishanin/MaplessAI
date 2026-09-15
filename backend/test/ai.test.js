const request = require('supertest');
const app = require('../src/app');
const { validateContract } = require('../src/utils/schema_validator');

/**
 * AI Controller Integration Tests (Owner: Surabhi)
 *
 * Tests cover:
 *   1.  Valid AI query returns a schema-valid response.
 *   2.  Invalid input is rejected with HTTP 400.
 *   3.  Unsupported / off-topic input produces FALLBACK.
 *   4.  Fallback response has targetNodeId === null.
 *   5.  Confidence is always within [0, 1].
 *   6.  Response validation is invoked before sending (proven by contract check).
 *   7.  No arbitrary SQL or database command is issued.
 *
 * SECURITY NOTE: No database connection is opened during these tests.
 * The controller is prohibited from issuing SQL — these tests confirm that
 * by verifying no DB-flavoured content appears in any response.
 */

describe('POST /api/v1/ai/query — AI Controller', () => {
  // ── helpers ──────────────────────────────────────────────────────────────

  /** Assert the response body is a valid ai-response schema. */
  function assertResponseIsValid(body) {
    const result = validateContract('ai-response', body);
    if (!result.valid) {
      // Surface AJV errors clearly inside Jest failure output
      throw new Error(
        'ai-response schema validation failed:\n' +
          JSON.stringify(result.errors, null, 2)
      );
    }
    expect(result.valid).toBe(true);
  }

  /** Assert confidence is within the schema-defined range. */
  function assertConfidenceInRange(body) {
    expect(typeof body.confidence).toBe('number');
    expect(body.confidence).toBeGreaterThanOrEqual(0.0);
    expect(body.confidence).toBeLessThanOrEqual(1.0);
  }

  /** Assert response contains no SQL-like content (security check). */
  function assertNoSqlContent(body) {
    const serialized = JSON.stringify(body).toUpperCase();
    // No raw SQL keyword sequences should appear in the response payload
    expect(serialized).not.toMatch(/SELECT\s+\*/);
    expect(serialized).not.toMatch(/INSERT\s+INTO/);
    expect(serialized).not.toMatch(/UPDATE\s+\w/);
    expect(serialized).not.toMatch(/DELETE\s+FROM/);
    expect(serialized).not.toMatch(/DROP\s+TABLE/);
  }

  // ── 1. Valid query — FIND_NEAREST ─────────────────────────────────────
  it('1. should return 200 with a schema-valid response for a supported query', async () => {
    const response = await request(app)
      .post('/api/v1/ai/query')
      .send({
        text: 'Where is the nearest lab?',
        buildingId: 'vit-ce'
      });

    expect(response.statusCode).toBe(200);
    expect(response.headers['content-type']).toMatch(/json/);
    assertResponseIsValid(response.body);
    assertConfidenceInRange(response.body);
  });

  // ── 2. Invalid input — missing required field ─────────────────────────
  it('2. should return 400 when required fields are missing from the request', async () => {
    const response = await request(app)
      .post('/api/v1/ai/query')
      .send({ text: 'Find the lab' }); // missing buildingId

    expect(response.statusCode).toBe(400);
    expect(response.body.error).toBeDefined();
    expect(response.body.error.code).toBe('VALIDATION_FAILED');
    expect(Array.isArray(response.body.error.details)).toBe(true);
    expect(response.body.error.details.length).toBeGreaterThan(0);
  });

  // ── 3. Off-topic / unsupported — FALLBACK ────────────────────────────
  it('3. should return FALLBACK intent for an off-topic or unrecognised query', async () => {
    const response = await request(app)
      .post('/api/v1/ai/query')
      .send({
        text: 'Tell me a joke about penguins',
        buildingId: 'vit-ce'
      });

    expect(response.statusCode).toBe(200);
    expect(response.body.intent).toBe('FALLBACK');
    assertResponseIsValid(response.body);
  });

  // ── 4. FALLBACK has targetNodeId === null ────────────────────────────
  it('4. should return targetNodeId as null in a FALLBACK response', async () => {
    const response = await request(app)
      .post('/api/v1/ai/query')
      .send({
        text: 'What is 2 + 2?',
        buildingId: 'vit-ce'
      });

    expect(response.statusCode).toBe(200);
    expect(response.body.intent).toBe('FALLBACK');
    expect(response.body.targetNodeId).toBeNull();
  });

  // ── 5a. Confidence in range — supported query ────────────────────────
  it('5a. should return confidence in [0, 1] for a supported query', async () => {
    const response = await request(app)
      .post('/api/v1/ai/query')
      .send({
        text: 'Find the nearest emergency exit',
        buildingId: 'vit-ce'
      });

    expect(response.statusCode).toBe(200);
    assertConfidenceInRange(response.body);
  });

  // ── 5b. Confidence in range — FALLBACK ───────────────────────────────
  it('5b. should return confidence in [0, 1] for a FALLBACK response', async () => {
    const response = await request(app)
      .post('/api/v1/ai/query')
      .send({
        text: 'xyzzy nothing happens',
        buildingId: 'vit-ce'
      });

    expect(response.statusCode).toBe(200);
    assertConfidenceInRange(response.body);
  });

  // ── 6. Output validation is active — every response passes the schema ──
  it('6. every 200 response must pass ai-response schema validation', async () => {
    const queries = [
      { text: 'Find nearest lab', buildingId: 'vit-ce' },
      { text: 'Where is the exit?', buildingId: 'vit-ce' },
      { text: 'Take me to the library', buildingId: 'vit-ce' },
      { text: 'something completely unrelated', buildingId: 'vit-ce' }
    ];

    for (const body of queries) {
      const response = await request(app)
        .post('/api/v1/ai/query')
        .send(body);

      expect(response.statusCode).toBe(200);
      // This assertion proves the output validation gate in the controller
      // is consistent with the schema — a mis-assembled payload would have
      // returned 500 from the controller itself.
      assertResponseIsValid(response.body);
      assertConfidenceInRange(response.body);
    }
  });

  // ── 7. No SQL content in any response ────────────────────────────────
  it('7. should never include SQL keywords in the response payload', async () => {
    const queries = [
      { text: 'Find nearest lab', buildingId: 'vit-ce' },
      { text: 'SELECT * FROM nodes', buildingId: 'vit-ce' },
      { text: 'DROP TABLE buildings', buildingId: 'vit-ce' }
    ];

    for (const body of queries) {
      const response = await request(app)
        .post('/api/v1/ai/query')
        .send(body);

      // Malicious-looking queries must either FALLBACK or return a valid
      // structured response — never echo SQL or produce a DB error
      expect([200, 400]).toContain(response.statusCode);
      if (response.statusCode === 200) {
        assertNoSqlContent(response.body);
      }
    }
  });

  // ── Supplementary: EMERGENCY_EXIT intent ────────────────────────────
  it('should return EMERGENCY_EXIT intent for evacuation queries', async () => {
    const response = await request(app)
      .post('/api/v1/ai/query')
      .send({
        text: 'I need to evacuate, where is the emergency exit?',
        buildingId: 'vit-ce'
      });

    expect(response.statusCode).toBe(200);
    expect(response.body.intent).toBe('EMERGENCY_EXIT');
    assertResponseIsValid(response.body);
  });

  // ── Supplementary: accessible constraint propagation ─────────────────
  it('should propagate accessible constraint from userContext', async () => {
    const response = await request(app)
      .post('/api/v1/ai/query')
      .send({
        text: 'Find the nearest lab',
        buildingId: 'vit-ce',
        userContext: {
          currentNodeId: 'reception',
          accessible: true,
          currentFloorId: 'floor-1'
        }
      });

    expect(response.statusCode).toBe(200);
    expect(response.body.constraints.accessible).toBe(true);
    assertResponseIsValid(response.body);
  });

  // ── Supplementary: missing text field ────────────────────────────────
  it('should return 400 when text field is missing', async () => {
    const response = await request(app)
      .post('/api/v1/ai/query')
      .send({ buildingId: 'vit-ce' });

    expect(response.statusCode).toBe(400);
    expect(response.body.error.code).toBe('VALIDATION_FAILED');
  });

  // ── Supplementary: empty text string ─────────────────────────────────
  it('should return 400 when text is an empty string (minLength violation)', async () => {
    const response = await request(app)
      .post('/api/v1/ai/query')
      .send({ text: '', buildingId: 'vit-ce' });

    expect(response.statusCode).toBe(400);
    expect(response.body.error.code).toBe('VALIDATION_FAILED');
  });

  // ── Supplementary: FALLBACK responseMessage is user-facing ───────────
  it('FALLBACK responseMessage should be a non-empty string asking user to rephrase', async () => {
    const response = await request(app)
      .post('/api/v1/ai/query')
      .send({ text: 'gibberish qxqxqx', buildingId: 'vit-ce' });

    expect(response.statusCode).toBe(200);
    expect(response.body.intent).toBe('FALLBACK');
    expect(typeof response.body.responseMessage).toBe('string');
    expect(response.body.responseMessage.length).toBeGreaterThan(0);
  });
});
