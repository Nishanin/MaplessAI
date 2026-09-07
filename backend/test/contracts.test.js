const fs = require('fs');
const path = require('path');
const { validateContract } = require('../src/utils/schema_validator');

describe('Shared JSON Contracts & Mock Dataset Adherence', () => {
  const mockDataPath = path.resolve(__dirname, '../../test_data/vit_floor_1.json');
  let mockData;

  beforeAll(() => {
    expect(fs.existsSync(mockDataPath)).toBe(true);
    mockData = JSON.parse(fs.readFileSync(mockDataPath, 'utf8'));
  });

  it('should validate Building against building.schema.json', () => {
    const result = validateContract('building', mockData.building);
    expect(result.valid).toBe(true);
    expect(result.errors).toEqual([]);
  });

  it('should validate Floor against floor.schema.json', () => {
    const result = validateContract('floor', mockData.floor);
    expect(result.valid).toBe(true);
    expect(result.errors).toEqual([]);
  });

  it('should validate all Nodes against node.schema.json', () => {
    expect(mockData.nodes.length).toBeGreaterThan(0);
    mockData.nodes.forEach((node) => {
      const result = validateContract('node', node);
      if (!result.valid) {
        console.error('Node validation failure:', node.id, result.errors);
      }
      expect(result.valid).toBe(true);
    });
  });

  it('should validate all Edges against edge.schema.json', () => {
    expect(mockData.edges.length).toBeGreaterThan(0);
    mockData.edges.forEach((edge) => {
      const result = validateContract('edge', edge);
      if (!result.valid) {
        console.error('Edge validation failure:', edge.id, result.errors);
      }
      expect(result.valid).toBe(true);
    });
  });

  it('should validate all SemanticMetadata against semantic-metadata.schema.json', () => {
    expect(mockData.semanticMetadata.length).toBeGreaterThan(0);
    mockData.semanticMetadata.forEach((meta) => {
      const result = validateContract('semantic-metadata', meta);
      if (!result.valid) {
        console.error('Semantic metadata failure:', meta.entityId, result.errors);
      }
      expect(result.valid).toBe(true);
    });
  });

  it('should validate NavigationRequest against navigation-request.schema.json', () => {
    const sampleNavRequest = {
      buildingId: 'vit-ce',
      startNodeId: 'reception',
      destinationNodeId: 'lab-101',
      preferences: {
        accessible: true,
        avoidStairs: true,
        avoidBlockedEdges: true
      }
    };
    const result = validateContract('navigation-request', sampleNavRequest);
    expect(result.valid).toBe(true);
  });

  it('should validate AiQuery against ai-query.schema.json', () => {
    const sampleAiQuery = {
      text: 'Where is the nearest computer lab?',
      buildingId: 'vit-ce',
      userContext: {
        currentNodeId: 'reception',
        accessible: true,
        currentFloorId: 'floor-1'
      }
    };
    const result = validateContract('ai-query', sampleAiQuery);
    expect(result.valid).toBe(true);
  });
});
