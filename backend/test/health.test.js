const request = require('supertest');
const app = require('../src/app');

describe('GET /health Endpoint', () => {
  it('should return 200 OK with expected service status payload', async () => {
    const response = await request(app).get('/health');

    expect(response.statusCode).toBe(200);
    expect(response.headers['content-type']).toMatch(/json/);
    expect(response.body).toEqual({
      service: 'mapless-backend',
      status: 'ok'
    });
  });

  it('should return 404 for nonexistent route', async () => {
    const response = await request(app).get('/api/v1/unknown-endpoint');
    expect(response.statusCode).toBe(404);
    expect(response.body.error).toBeDefined();
    expect(response.body.error.code).toBe('NOT_FOUND');
  });
});
