const crypto = require('crypto');
const db = require('../../config/database');

/**
 * Mutex for per-building concurrency serialization.
 * Ensures that even in in-memory / local test execution without an external PostgreSQL server,
 * concurrent publishing for the SAME building is serialized, while DIFFERENT buildings proceed concurrently.
 */
class BuildingMutex {
  constructor() {
    this._queues = new Map();
  }

  async acquire(buildingId) {
    while (this._queues.has(buildingId)) {
      await this._queues.get(buildingId);
    }
    let resolver;
    const promise = new Promise((resolve) => {
      resolver = resolve;
    });
    this._queues.set(buildingId, promise);
    return () => {
      this._queues.delete(buildingId);
      resolver();
    };
  }
}

class VersioningRepository {
  constructor(database = db) {
    this.db = database;
    this._buildingMutex = new BuildingMutex();
    // In-memory store used when live PostgreSQL is unavailable or in mock/test mode
    this._inMemoryVersions = [];
    this._inMemoryCurrentMap = new Map(); // buildingId -> { floors, nodes, edges, semanticMetadata }
  }

  isLivePostgres() {
    return Boolean(this.db && this.db.pool && this.db.isConnected);
  }

  /**
   * Begins a transactional scope and locks the target building row.
   * Uses 'SELECT id FROM buildings WHERE id = $1 FOR UPDATE' in PostgreSQL,
   * or a per-building mutex in the mock/in-memory engine.
   * @param {string} buildingId
   * @returns {Promise<object>} Transaction context
   */
  async beginTransaction(buildingId) {
    const releaseLock = await this._buildingMutex.acquire(buildingId);

    if (this.isLivePostgres()) {
      const client = await this.db.pool.connect();
      try {
        await client.query('BEGIN');
        // Lock the building row exclusively for this transaction
        const lockRes = await client.query(
          'SELECT id FROM buildings WHERE id = $1 FOR UPDATE',
          [buildingId]
        );
        if (lockRes.rowCount === 0) {
          // Building not yet in DB; ensure insertion or fail gracefully
          await client.query(
            'INSERT INTO buildings (id, name, address, category, latitude, longitude) VALUES ($1, $1, $1, $1, 0, 0) ON CONFLICT (id) DO NOTHING',
            [buildingId]
          );
          await client.query(
            'SELECT id FROM buildings WHERE id = $1 FOR UPDATE',
            [buildingId]
          );
        }
        return {
          type: 'postgres',
          client,
          buildingId,
          releaseLock
        };
      } catch (err) {
        await client.query('ROLLBACK');
        client.release();
        releaseLock();
        throw err;
      }
    }

    // In-memory transaction context
    return {
      type: 'inmemory',
      buildingId,
      releaseLock,
      stagedVersions: []
    };
  }

  /**
   * Determines the next sequential version number for a building inside a transaction.
   * @param {string} buildingId
   * @param {object} tx - Active transaction
   * @returns {Promise<number>}
   */
  async getNextVersionNumber(buildingId, tx) {
    if (tx.type === 'postgres') {
      const res = await tx.client.query(
        'SELECT COALESCE(MAX(version_number), 0) + 1 AS next_version FROM map_versions WHERE building_id = $1',
        [buildingId]
      );
      return parseInt(res.rows[0].next_version, 10);
    }

    // In-memory: compute max among committed + staged for this building
    const committedForBuilding = this._inMemoryVersions.filter(v => v.building_id === buildingId);
    const stagedForBuilding = tx.stagedVersions.filter(v => v.building_id === buildingId);
    const all = [...committedForBuilding, ...stagedForBuilding];

    if (all.length === 0) return 1;
    const max = Math.max(...all.map(v => v.version_number));
    return max + 1;
  }

  /**
   * Persists an immutable version record inside an active transaction.
   * Enforces UNIQUE(building_id, version_number).
   * @param {object} versionData
   * @param {object} tx
   * @returns {Promise<object>}
   */
  async insertVersion(versionData, tx) {
    const id = versionData.id || crypto.randomUUID();
    const createdAt = versionData.createdAt || new Date().toISOString();
    const publishedAt = versionData.publishedAt || createdAt;
    const publishedBy = versionData.publishedBy || versionData.createdBy;
    const status = versionData.status || 'published';
    const parentVersionId = versionData.parentVersionId || null;

    // Deep clone the snapshot data to enforce pure immutability
    const graphSnapshot = JSON.parse(JSON.stringify(versionData.graphSnapshot || {}));

    if (tx.type === 'postgres') {
      const query = `
        INSERT INTO map_versions (
          id, building_id, version_number, version_tag, graph_snapshot, 
          change_summary, created_by, created_at, status, published_at, 
          published_by, parent_version_id
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
        RETURNING *;
      `;
      const values = [
        id,
        versionData.buildingId,
        versionData.versionNumber,
        versionTag,
        JSON.stringify(graphSnapshot),
        versionData.changeSummary,
        versionData.createdBy,
        createdAt,
        status,
        publishedAt,
        publishedBy,
        parentVersionId
      ];
      try {
        const res = await tx.client.query(query, values);
        return this._formatRow(res.rows[0]);
      } catch (err) {
        if (err.code === '23505') { // Postgres unique_violation
          const conflictError = new Error(`Duplicate version number ${versionData.versionNumber} for building ${versionData.buildingId}`);
          conflictError.code = 'VERSION_CONFLICT';
          conflictError.statusCode = 409;
          throw conflictError;
        }
        throw err;
      }
    }

    // In-memory uniqueness check
    const existing = this._inMemoryVersions.find(
      v => v.building_id === versionData.buildingId && v.version_number === versionData.versionNumber
    ) || tx.stagedVersions.find(
      v => v.building_id === versionData.buildingId && v.version_number === versionData.versionNumber
    );

    if (existing) {
      const conflictError = new Error(`Duplicate version number ${versionData.versionNumber} for building ${versionData.buildingId}`);
      conflictError.code = 'VERSION_CONFLICT';
      conflictError.statusCode = 409;
      throw conflictError;
    }

    const row = {
      id,
      building_id: versionData.buildingId,
      version_number: versionData.versionNumber,
      version_tag: versionData.versionTag,
      graph_snapshot: graphSnapshot,
      change_summary: versionData.changeSummary,
      created_by: versionData.createdBy,
      created_at: createdAt,
      status,
      published_at: publishedAt,
      published_by: publishedBy,
      parent_version_id: parentVersionId
    };

    tx.stagedVersions.push(row);
    return this._formatRow(row);
  }

  /**
   * Commits the active transaction and releases locks.
   * @param {object} tx
   */
  async commitTransaction(tx) {
    try {
      if (tx.type === 'postgres') {
        await tx.client.query('COMMIT');
        tx.client.release();
      } else if (tx.type === 'inmemory') {
        // Commit staged versions into permanent memory
        for (const v of tx.stagedVersions) {
          // Double-check uniqueness
          const conflict = this._inMemoryVersions.find(
            c => c.building_id === v.building_id && c.version_number === v.version_number
          );
          if (conflict) {
            const err = new Error(`Unique constraint conflict: building ${v.building_id} version ${v.version_number} already committed`);
            err.code = 'VERSION_CONFLICT';
            err.statusCode = 409;
            throw err;
          }
          this._inMemoryVersions.push(v);
        }
      }
    } finally {
      if (typeof tx.releaseLock === 'function') {
        tx.releaseLock();
      }
    }
  }

  /**
   * Rolls back the active transaction and releases locks.
   * @param {object} tx
   */
  async rollbackTransaction(tx) {
    try {
      if (tx.type === 'postgres') {
        try {
          await tx.client.query('ROLLBACK');
        } catch (_) {}
        tx.client.release();
      } else if (tx.type === 'inmemory') {
        tx.stagedVersions = [];
      }
    } finally {
      if (typeof tx.releaseLock === 'function') {
        tx.releaseLock();
      }
    }
  }

  /**
   * Retrieves all published versions for a building, sorted newest to oldest.
   * @param {string} buildingId
   * @returns {Promise<Array<object>>}
   */
  async findHistoryByBuilding(buildingId) {
    if (this.isLivePostgres()) {
      const query = `
        SELECT * FROM map_versions 
        WHERE building_id = $1 
        ORDER BY version_number DESC;
      `;
      const res = await this.db.query(query, [buildingId]);
      return res.rows.map(r => this._formatRow(r));
    }

    return this._inMemoryVersions
      .filter(v => v.building_id === buildingId)
      .sort((a, b) => b.version_number - a.version_number)
      .map(v => this._formatRow(v));
  }

  /**
   * Finds a version by its primary UUID or by building and version number.
   * @param {string} buildingId
   * @param {string|number} versionIdOrNumber
   * @returns {Promise<object|null>}
   */
  async findVersion(buildingId, versionIdOrNumber) {
    const isNumber = !isNaN(Number(versionIdOrNumber));
    const versionNum = isNumber ? Number(versionIdOrNumber) : null;

    if (this.isLivePostgres()) {
      let query;
      let params;
      if (isNumber) {
        query = 'SELECT * FROM map_versions WHERE building_id = $1 AND version_number = $2';
        params = [buildingId, versionNum];
      } else {
        query = 'SELECT * FROM map_versions WHERE building_id = $1 AND id = $2';
        params = [buildingId, String(versionIdOrNumber)];
      }
      const res = await this.db.query(query, params);
      if (res.rows.length === 0) return null;
      return this._formatRow(res.rows[0]);
    }

    const found = this._inMemoryVersions.find(v => {
      if (v.building_id !== buildingId) return false;
      if (isNumber) return v.version_number === versionNum;
      return v.id === String(versionIdOrNumber);
    });

    return found ? this._formatRow(found) : null;
  }

  /**
   * Retrieves the current active map state for a building.
   * @param {string} buildingId
   * @returns {Promise<object>}
   */
  async getActiveMapState(buildingId) {
    if (this.isLivePostgres()) {
      const floorsRes = await this.db.query('SELECT * FROM floors WHERE building_id = $1', [buildingId]);
      const floorIds = floorsRes.rows.map(f => f.id);

      let nodes = [];
      let edges = [];
      let semanticMetadata = [];

      if (floorIds.length > 0) {
        const nodesRes = await this.db.query('SELECT * FROM nodes WHERE floor_id = ANY($1)', [floorIds]);
        nodes = nodesRes.rows;
        const nodeIds = nodes.map(n => n.id);

        if (nodeIds.length > 0) {
          const edgesRes = await this.db.query(
            'SELECT * FROM edges WHERE start_node_id = ANY($1) OR end_node_id = ANY($1)',
            [nodeIds]
          );
          edges = edgesRes.rows;

          const metaRes = await this.db.query(
            'SELECT * FROM semantic_metadata WHERE entity_id = ANY($1)',
            [[...nodeIds, ...floorIds, buildingId]]
          );
          semanticMetadata = metaRes.rows;
        }
      }

      return {
        buildingId,
        floors: floorsRes.rows,
        nodes,
        edges,
        semanticMetadata
      };
    }

    // In-memory active map state
    return this._inMemoryCurrentMap.get(buildingId) || {
      buildingId,
      floors: [],
      nodes: [],
      edges: [],
      semanticMetadata: []
    };
  }

  /**
   * Atomically restores the active map state tables from a snapshot.
   * Executed within the rollback transaction.
   * @param {string} buildingId
   * @param {object} snapshot
   * @param {object} tx
   */
  async restoreActiveMapState(buildingId, snapshot, tx) {
    const safeSnapshot = JSON.parse(JSON.stringify(snapshot));

    if (tx.type === 'postgres') {
      const client = tx.client;
      // 1. Delete existing active graph for building
      await client.query('DELETE FROM edges WHERE start_node_id IN (SELECT id FROM nodes WHERE floor_id IN (SELECT id FROM floors WHERE building_id = $1))', [buildingId]);
      await client.query('DELETE FROM nodes WHERE floor_id IN (SELECT id FROM floors WHERE building_id = $1)', [buildingId]);
      await client.query('DELETE FROM semantic_metadata WHERE entity_id = $1 OR entity_id IN (SELECT id FROM floors WHERE building_id = $1)', [buildingId]);
      await client.query('DELETE FROM floors WHERE building_id = $1', [buildingId]);

      // 2. Re-insert floors
      const floors = safeSnapshot.floors || (safeSnapshot.floor ? [safeSnapshot.floor] : []);
      for (const f of floors) {
        await client.query(
          'INSERT INTO floors (id, building_id, floor_number, name, elevation, metadata) VALUES ($1, $2, $3, $4, $5, $6) ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name',
          [f.id, buildingId, f.floorNumber || f.floor_number || 0, f.name || 'Floor', f.elevation || 0.0, JSON.stringify(f.metadata || {})]
        );
      }

      // 3. Re-insert nodes
      const nodes = safeSnapshot.nodes || [];
      for (const n of nodes) {
        await client.query(
          'INSERT INTO nodes (id, name, category, floor_id, x, y, accessible, metadata) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)',
          [n.id, n.name, n.category, n.floorId || n.floor_id, n.x, n.y, n.accessible ?? true, JSON.stringify(n.metadata || {})]
        );
      }

      // 4. Re-insert edges
      const edges = safeSnapshot.edges || [];
      for (const e of edges) {
        await client.query(
          'INSERT INTO edges (id, start_node_id, end_node_id, distance, bearing, accessible, blocked, metadata) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)',
          [e.id, e.startNodeId || e.start_node_id, e.endNodeId || e.end_node_id, e.distance, e.bearing, e.accessible ?? true, e.blocked ?? false, JSON.stringify(e.metadata || {})]
        );
      }

      // 5. Re-insert semantic metadata
      const meta = safeSnapshot.semanticMetadata || safeSnapshot.semantic_metadata || [];
      for (const m of meta) {
        await client.query(
          'INSERT INTO semantic_metadata (entity_id, entity_type, tags, aliases, description, department, operational_hours, capacity, custom_attributes) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)',
          [
            m.entityId || m.entity_id,
            m.entityType || m.entity_type,
            m.tags || [],
            m.aliases || [],
            m.description || null,
            m.department || null,
            m.operationalHours || m.operational_hours || null,
            m.capacity || null,
            JSON.stringify(m.customAttributes || m.custom_attributes || {})
          ]
        );
      }
    } else {
      // In-memory active map update
      this._inMemoryCurrentMap.set(buildingId, {
        buildingId,
        floors: safeSnapshot.floors || (safeSnapshot.floor ? [safeSnapshot.floor] : []),
        nodes: safeSnapshot.nodes || [],
        edges: safeSnapshot.edges || [],
        semanticMetadata: safeSnapshot.semanticMetadata || safeSnapshot.semantic_metadata || []
      });
    }
  }

  /**
   * Helper to set initial mock map state (useful for tests and seed data).
   */
  seedCurrentMapState(buildingId, mapData) {
    this._inMemoryCurrentMap.set(buildingId, JSON.parse(JSON.stringify(mapData)));
  }

  /**
   * Maps DB snake_case columns to clean camelCase application objects.
   */
  _formatRow(row) {
    if (!row) return null;
    let snapshot = row.graph_snapshot;
    if (typeof snapshot === 'string') {
      try {
        snapshot = JSON.parse(snapshot);
      } catch (_) {}
    }

    return {
      id: row.id,
      buildingId: row.building_id,
      versionNumber: row.version_number,
      versionTag: row.version_tag,
      changeSummary: row.change_summary,
      createdBy: row.created_by,
      createdAt: row.created_at instanceof Date ? row.created_at.toISOString() : row.created_at,
      status: row.status || 'published',
      publishedAt: row.published_at instanceof Date ? row.published_at.toISOString() : (row.published_at || row.created_at),
      publishedBy: row.published_by || row.created_by,
      parentVersionId: row.parent_version_id || null,
      graphSnapshot: snapshot || {}
    };
  }
}

module.exports = new VersioningRepository();
