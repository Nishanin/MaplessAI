const fs = require('fs');
const path = require('path');
const request = require('supertest');
const app = require('../src/app');
const versioningService = require('../src/features/versioning/versioning.service');
const versioningRepo = require('../src/features/versioning/versioning.repository');
const { computeSnapshotDiff } = require('../src/features/versioning/version_diff');
const { validateContract } = require('../src/utils/schema_validator');

describe('Map Versioning Feature Suite (Owner: Piyush)', () => {
  const vitDataPath = path.resolve(__dirname, '../../test_data/vit_floor_1.json');
  let vitFloor1;

  beforeAll(() => {
    expect(fs.existsSync(vitDataPath)).toBe(true);
    vitFloor1 = JSON.parse(fs.readFileSync(vitDataPath, 'utf8'));
  });

  describe('Contract Validation for Versioning', () => {
    it('should validate complete vit_floor_1 snapshot against version-snapshot.schema.json', () => {
      const snapshotPayload = {
        buildingId: 'vit-ce',
        building: vitFloor1.building,
        floors: [vitFloor1.floor],
        nodes: vitFloor1.nodes,
        edges: vitFloor1.edges,
        semanticMetadata: vitFloor1.semanticMetadata
      };

      const result = validateContract('version-snapshot', snapshotPayload);
      expect(result.valid).toBe(true);
      expect(result.errors).toEqual([]);
    });

    it('should validate MapVersion structure against version.schema.json', async () => {
      const v = await versioningService.createVersion(
        'contract-building',
        {
          buildingId: 'contract-building',
          nodes: [{ id: 'n1', name: 'Node 1', category: 'entrance', floorId: 'f1', x: 0, y: 0, accessible: true }],
          edges: []
        },
        'Initial contract validation version',
        'piyush-tester'
      );

      const result = validateContract('version', v);
      expect(result.valid).toBe(true);
      expect(result.errors).toEqual([]);
    });
  });

  describe('Sequential Version Publishing & Immutability', () => {
    const buildingId = 'bld-seq-test';

    it('1 & 2. should create first and second versions sequentially', async () => {
      const v1 = await versioningService.createVersion(
        buildingId,
        vitFloor1,
        'Initial v1 publishing',
        'piyush'
      );

      expect(v1.versionNumber).toBe(1);
      expect(v1.versionTag).toBe('v1.0.0');
      expect(v1.buildingId).toBe(buildingId);
      expect(v1.createdBy).toBe('piyush');

      const v2 = await versioningService.createVersion(
        buildingId,
        vitFloor1,
        'Second update publishing',
        'piyush'
      );

      expect(v2.versionNumber).toBe(2);
      expect(v2.versionTag).toBe('v2.0.0');
    });

    it('3. version numbers are strictly monotonic sequential', async () => {
      const v3 = await versioningService.createVersion(
        buildingId,
        vitFloor1,
        'Third update',
        'piyush'
      );
      expect(v3.versionNumber).toBe(3);
    });

    it('4 & 5. version numbers are independent per building', async () => {
      const otherBuilding = 'bld-independent-campus';
      const otherV1 = await versioningService.createVersion(
        otherBuilding,
        vitFloor1,
        'Campus B first version',
        'piyush'
      );

      expect(otherV1.buildingId).toBe(otherBuilding);
      expect(otherV1.versionNumber).toBe(1);

      const otherV2 = await versioningService.createVersion(
        otherBuilding,
        vitFloor1,
        'Campus B second version',
        'piyush'
      );
      expect(otherV2.versionNumber).toBe(2);

      // Verify original building is unaffected
      const histSeq = await versioningService.getVersionHistory(buildingId);
      expect(histSeq[0].versionNumber).toBe(3);
    });

    it('6. UNIQUE(building_id, version_number) invariant is enforced', async () => {
      const tx = await versioningRepo.beginTransaction(buildingId);
      try {
        await expect(
          versioningRepo.insertVersion({
            buildingId,
            versionNumber: 1, // Already exists for this building
            versionTag: 'v1.0.0-duplicate',
            changeSummary: 'Testing duplicate collision',
            createdBy: 'attacker',
            graphSnapshot: {}
          }, tx)
        ).rejects.toThrow(/Duplicate version number 1/);
      } finally {
        await versioningRepo.rollbackTransaction(tx);
      }
    });

    it('7 & 8. published versions are strictly immutable and historical snapshots remain preserved', async () => {
      const bldImmutable = 'bld-immutable-audit';
      const originalNodeCount = vitFloor1.nodes.length;

      const v1 = await versioningService.createVersion(
        bldImmutable,
        vitFloor1,
        'Baseline snapshot',
        'piyush'
      );

      // Attempt external mutation of payload object
      vitFloor1.nodes.push({ id: 'mutated-rogue-node', name: 'Rogue', x: 0, y: 0, accessible: true });

      // Re-fetch v1 from service
      const fetchedV1 = await versioningService.getVersion(bldImmutable, 1);
      expect(fetchedV1.graphSnapshot.nodes.length).toBe(originalNodeCount);
      expect(fetchedV1.graphSnapshot.nodes.find(n => n.id === 'mutated-rogue-node')).toBeUndefined();

      // Clean up local fixture mutation
      vitFloor1.nodes.pop();
    });
  });

  describe('Graph Diff Engine', () => {
    it('9. accurately detects added, removed, and modified nodes, edges, and semantic metadata', () => {
      const baseSnapshot = JSON.parse(JSON.stringify(vitFloor1));
      const targetSnapshot = JSON.parse(JSON.stringify(vitFloor1));

      // Modify target:
      // 1. Add a new node 'lab-102'
      targetSnapshot.nodes.push({
        id: 'lab-102',
        name: 'AI Robotics Lab',
        category: 'laboratory',
        floorId: 'floor-1',
        x: 35.0,
        y: 30.0,
        accessible: true
      });

      // 2. Remove 'library' node
      targetSnapshot.nodes = targetSnapshot.nodes.filter(n => n.id !== 'library');

      // 3. Modify 'entrance' node
      const entrance = targetSnapshot.nodes.find(n => n.id === 'entrance');
      entrance.name = 'Renovated Grand Entrance';

      // 4. Add an edge
      targetSnapshot.edges.push({
        id: 'edge-corridor-lab102',
        startNodeId: 'corridor',
        endNodeId: 'lab-102',
        distance: 12.0,
        bearing: 45.0,
        accessible: true,
        blocked: false
      });

      // 5. Remove an edge
      targetSnapshot.edges = targetSnapshot.edges.filter(e => e.id !== 'edge-entrance-reception');

      // 6. Modify semantic metadata for 'lab-101'
      const labMeta = targetSnapshot.semanticMetadata.find(m => m.entityId === 'lab-101');
      labMeta.capacity = 60;
      labMeta.tags.push('quantum-computing');

      const diffResult = computeSnapshotDiff(baseSnapshot, targetSnapshot);

      // Assertions
      expect(diffResult.nodesAdded.map(n => n.id)).toContain('lab-102');
      expect(diffResult.nodesRemoved.map(n => n.id)).toContain('library');
      expect(diffResult.nodesModified.length).toBe(1);
      expect(diffResult.nodesModified[0].id).toBe('entrance');
      expect(diffResult.nodesModified[0].after.name).toBe('Renovated Grand Entrance');

      expect(diffResult.edgesAdded.map(e => e.id)).toContain('edge-corridor-lab102');
      expect(diffResult.edgesRemoved.map(e => e.id)).toContain('edge-entrance-reception');

      expect(diffResult.semanticMetadataModified.length).toBe(1);
      expect(diffResult.semanticMetadataModified[0].after.capacity).toBe(60);

      expect(diffResult.summary.nodesChanged).toBe(3);
    });
  });

  describe('Rollback Engine', () => {
    const bldRollback = 'bld-rollback-demo';

    it('10 & 11. rollback creates a NEW sequential version without modifying the source version', async () => {
      // Create v1 with 8 nodes
      const v1 = await versioningService.createVersion(
        bldRollback,
        vitFloor1,
        'Original baseline v1',
        'piyush'
      );
      expect(v1.versionNumber).toBe(1);

      // Create v2 with a modified graph (9 nodes)
      const modifiedGraph = JSON.parse(JSON.stringify(vitFloor1));
      modifiedGraph.nodes.push({ id: 'temp-kiosk', name: 'Temporary Kiosk', category: 'service', floorId: 'floor-1', x: 5, y: 5, accessible: true });
      const v2 = await versioningService.createVersion(
        bldRollback,
        modifiedGraph,
        'Added temporary kiosk v2',
        'piyush'
      );
      expect(v2.versionNumber).toBe(2);

      // Rollback to v1
      const v3 = await versioningService.rollbackVersion(
        bldRollback,
        1,
        'ops-lead',
        'Kiosk removed, rolling back to baseline'
      );

      // Check new version properties
      expect(v3.versionNumber).toBe(3);
      expect(v3.parentVersionId).toBe(v1.id);
      expect(v3.createdBy).toBe('ops-lead');
      expect(v3.changeSummary).toContain('Kiosk removed');
      expect(v3.graphSnapshot.nodes.length).toBe(vitFloor1.nodes.length);
      expect(v3.graphSnapshot.nodes.find(n => n.id === 'temp-kiosk')).toBeUndefined();

      // Ensure Source Version v1 is 100% UNCHANGED
      const sourceV1 = await versioningService.getVersion(bldRollback, 1);
      expect(sourceV1.versionNumber).toBe(1);
      expect(sourceV1.changeSummary).toBe('Original baseline v1');
      expect(sourceV1.createdBy).toBe('piyush');

      // Ensure Version history contains all 3 versions chronologically
      const history = await versioningService.getVersionHistory(bldRollback);
      expect(history.length).toBe(3);
      expect(history.map(h => h.versionNumber)).toEqual([3, 2, 1]);
    });
  });

  describe('Transaction Safety & Concurrency', () => {
    it('12. transaction rolls back completely on publication failure without partial leak', async () => {
      const bldTx = 'bld-tx-failure-test';

      const failingRepo = {
        beginTransaction: () => versioningRepo.beginTransaction(bldTx),
        getNextVersionNumber: () => Promise.resolve(1),
        getActiveMapState: () => Promise.resolve({ nodes: [], edges: [] }),
        insertVersion: () => Promise.reject(new Error('Simulated database write IO failure')),
        rollbackTransaction: jest.fn(tx => versioningRepo.rollbackTransaction(tx)),
        commitTransaction: () => Promise.resolve()
      };

      const customService = new (versioningService.constructor)(failingRepo);

      await expect(
        customService.createVersion(bldTx, vitFloor1, 'Failing commit', 'tester')
      ).rejects.toThrow('Simulated database write IO failure');

      expect(failingRepo.rollbackTransaction).toHaveBeenCalled();

      // Verify no version was persisted in repository
      const hist = await versioningService.getVersionHistory(bldTx);
      expect(hist.length).toBe(0);
    });

    it('13. concurrent publishing for the SAME building safely serializes without duplicate versions', async () => {
      const bldConcurrent = 'bld-concurrency-test';

      // Fire 5 simultaneous publish operations for the same building
      const tasks = Array.from({ length: 5 }).map((_, i) =>
        versioningService.createVersion(
          bldConcurrent,
          vitFloor1,
          `Concurrent publish batch ${i + 1}`,
          `worker-${i + 1}`
        )
      );

      const results = await Promise.all(tasks);

      // Extract assigned version numbers
      const versionNumbers = results.map(r => r.versionNumber).sort((a, b) => a - b);
      expect(versionNumbers).toEqual([1, 2, 3, 4, 5]);

      // All 5 must have unique IDs and sequential tags
      const uniqueIds = new Set(results.map(r => r.id));
      expect(uniqueIds.size).toBe(5);

      const history = await versioningService.getVersionHistory(bldConcurrent);
      expect(history.length).toBe(5);
    });

    it('14. concurrent publishing for DIFFERENT buildings proceed independently without deadlock', async () => {
      const bldA = 'bld-concurrent-alpha';
      const bldB = 'bld-concurrent-beta';

      const [pubA, pubB] = await Promise.all([
        versioningService.createVersion(bldA, vitFloor1, 'Alpha publish', 'worker-a'),
        versioningService.createVersion(bldB, vitFloor1, 'Beta publish', 'worker-b')
      ]);

      expect(pubA.buildingId).toBe(bldA);
      expect(pubA.versionNumber).toBe(1);

      expect(pubB.buildingId).toBe(bldB);
      expect(pubB.versionNumber).toBe(1);
    });
  });

  describe('HTTP REST API Integration via Express Router', () => {
    const apiBuilding = 'vit-api-demo';

    it('POST /api/v1/versioning/buildings/:buildingId/snapshots should publish version', async () => {
      const res = await request(app)
        .post(`/api/v1/versioning/buildings/${apiBuilding}/snapshots`)
        .send({
          snapshotData: vitFloor1,
          changeSummary: 'API snapshot walkthrough',
          createdBy: 'nishant-creator'
        });

      expect(res.statusCode).toBe(201);
      expect(res.body.success).toBe(true);
      expect(res.body.version).toBeDefined();
      expect(res.body.version.versionNumber).toBe(1);
      expect(res.body.version.createdBy).toBe('nishant-creator');
    });

    it('GET /api/v1/versioning/buildings/:buildingId/history should retrieve history list', async () => {
      const res = await request(app)
        .get(`/api/v1/versioning/buildings/${apiBuilding}/history`);

      expect(res.statusCode).toBe(200);
      expect(res.body.buildingId).toBe(apiBuilding);
      expect(Array.isArray(res.body.versions)).toBe(true);
      expect(res.body.versions.length).toBeGreaterThanOrEqual(1);
    });

    it('GET /api/v1/versioning/buildings/:buildingId/versions/:versionId should retrieve specific version', async () => {
      const res = await request(app)
        .get(`/api/v1/versioning/buildings/${apiBuilding}/versions/1`);

      expect(res.statusCode).toBe(200);
      expect(res.body.version.versionNumber).toBe(1);
      expect(res.body.version.graphSnapshot.nodes).toBeDefined();
    });

    it('POST /api/v1/versioning/buildings/:buildingId/compare should return diff', async () => {
      // Publish v2 with 1 node added
      const mod = JSON.parse(JSON.stringify(vitFloor1));
      mod.nodes.push({ id: 'auditorium', name: 'Main Auditorium', category: 'facility', floorId: 'floor-1', x: 50, y: 50, accessible: true });

      await request(app)
        .post(`/api/v1/versioning/buildings/${apiBuilding}/snapshots`)
        .send({
          snapshotData: mod,
          changeSummary: 'Added auditorium',
          createdBy: 'nishant-creator'
        });

      const diffRes = await request(app)
        .post(`/api/v1/versioning/buildings/${apiBuilding}/compare`)
        .send({
          baseVersion: 1,
          targetVersion: 2
        });

      expect(diffRes.statusCode).toBe(200);
      expect(diffRes.body.diff.nodesAdded.map(n => n.id)).toContain('auditorium');
    });

    it('POST /api/v1/versioning/buildings/:buildingId/rollback should rollback to previous version as new version', async () => {
      const res = await request(app)
        .post(`/api/v1/versioning/buildings/${apiBuilding}/rollback`)
        .send({
          targetVersion: 1,
          restoredBy: 'piyush-admin',
          reason: 'Emergency rollback to baseline'
        });

      expect(res.statusCode).toBe(200);
      expect(res.body.success).toBe(true);
      expect(res.body.newVersion.versionNumber).toBe(3); // v1 -> v2 -> rollback is v3
      expect(res.body.newVersion.graphSnapshot.nodes.find(n => n.id === 'auditorium')).toBeUndefined();
    });

    it('should return 400 when missing required audit fields on snapshot creation', async () => {
      const res = await request(app)
        .post(`/api/v1/versioning/buildings/${apiBuilding}/snapshots`)
        .send({
          snapshotData: {}
          // missing changeSummary and createdBy
        });

      expect(res.statusCode).toBe(400);
      expect(res.body.error.code).toBe('MISSING_FIELDS');
    });

    it('should return 404 when querying nonexistent version', async () => {
      const res = await request(app)
        .get(`/api/v1/versioning/buildings/${apiBuilding}/versions/9999`);

      expect(res.statusCode).toBe(404);
      expect(res.body.error.code).toBe('VERSION_NOT_FOUND');
    });
  });
});
