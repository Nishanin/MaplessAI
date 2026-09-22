const IVersioningService = require('./versioning.service.interface');
const repository = require('./versioning.repository');
const { computeSnapshotDiff } = require('./version_diff');

class VersioningService extends IVersioningService {
  constructor(repo = repository) {
    super();
    this.repo = repo;
  }

  /**
   * Publishes an immutable map snapshot within a serializing transaction.
   * @param {string} buildingId - Building identifier
   * @param {object} snapshotData - Provided map snapshot or empty object
   * @param {string} changeSummary - Audit description
   * @param {string} createdBy - Author/actor identifier
   * @param {object} [options] - Optional overrides (versionTag, status, parentVersionId)
   * @returns {Promise<object>} Published MapVersion record
   */
  async createVersion(buildingId, snapshotData, changeSummary, createdBy, options = {}) {
    if (!buildingId) {
      const err = new Error('buildingId is required');
      err.code = 'INVALID_INPUT';
      err.statusCode = 400;
      throw err;
    }
    if (!changeSummary || !createdBy) {
      const err = new Error('changeSummary and createdBy are required fields');
      err.code = 'MISSING_FIELDS';
      err.statusCode = 400;
      throw err;
    }

    const tx = await this.repo.beginTransaction(buildingId);
    try {
      // 1. Determine next version number while holding the per-building lock
      const nextVersionNumber = await this.repo.getNextVersionNumber(buildingId, tx);
      const versionTag = options.versionTag || `v${nextVersionNumber}.0.0`;

      // 2. Resolve complete snapshot
      let finalSnapshot;
      const hasGraphContent = snapshotData && 
        ((Array.isArray(snapshotData.nodes) && snapshotData.nodes.length > 0) || 
         (Array.isArray(snapshotData.edges) && snapshotData.edges.length > 0));

      if (hasGraphContent) {
        finalSnapshot = JSON.parse(JSON.stringify(snapshotData));
      } else {
        // Fallback: construct snapshot from active database/store state
        const activeState = await this.repo.getActiveMapState(buildingId);
        finalSnapshot = JSON.parse(JSON.stringify(activeState));
      }

      finalSnapshot.buildingId = buildingId;
      if (!finalSnapshot.nodes) finalSnapshot.nodes = [];
      if (!finalSnapshot.edges) finalSnapshot.edges = [];
      if (!finalSnapshot.semanticMetadata) finalSnapshot.semanticMetadata = [];

      // 3. Persist immutable version record
      const versionRecord = await this.repo.insertVersion({
        buildingId,
        versionNumber: nextVersionNumber,
        versionTag,
        changeSummary,
        createdBy,
        status: options.status || 'published',
        publishedBy: options.publishedBy || createdBy,
        parentVersionId: options.parentVersionId || null,
        graphSnapshot: finalSnapshot
      }, tx);

      // 4. Update current active map state to reflect this published state
      await this.repo.restoreActiveMapState(buildingId, finalSnapshot, tx);

      // 5. Commit transaction & release locks
      await this.repo.commitTransaction(tx);
      return versionRecord;
    } catch (err) {
      await this.repo.rollbackTransaction(tx);
      throw err;
    }
  }

  /**
   * Retrieves complete version history for a building, ordered newest to oldest.
   * @param {string} buildingId
   * @returns {Promise<Array<object>>}
   */
  async getVersionHistory(buildingId) {
    if (!buildingId) {
      const err = new Error('buildingId is required');
      err.code = 'INVALID_INPUT';
      err.statusCode = 400;
      throw err;
    }
    return this.repo.findHistoryByBuilding(buildingId);
  }

  /**
   * Retrieves a single version by ID or version number.
   * @param {string} buildingId
   * @param {string|number} versionIdOrNumber
   * @returns {Promise<object>}
   */
  async getVersion(buildingId, versionIdOrNumber) {
    const version = await this.repo.findVersion(buildingId, versionIdOrNumber);
    if (!version) {
      const err = new Error(`Version '${versionIdOrNumber}' not found for building '${buildingId}'`);
      err.code = 'VERSION_NOT_FOUND';
      err.statusCode = 404;
      throw err;
    }
    return version;
  }

  /**
   * Computes semantic and spatial differences between two version snapshots.
   * @param {string} buildingId
   * @param {number|string} baseVersionIdOrNum
   * @param {number|string} targetVersionIdOrNum
   * @returns {Promise<object>}
   */
  async compareVersions(buildingId, baseVersionIdOrNum, targetVersionIdOrNum) {
    const baseVersion = await this.getVersion(buildingId, baseVersionIdOrNum);
    const targetVersion = await this.getVersion(buildingId, targetVersionIdOrNum);

    const diff = computeSnapshotDiff(baseVersion.graphSnapshot, targetVersion.graphSnapshot);

    return {
      buildingId,
      baseVersion: baseVersion.versionNumber,
      targetVersion: targetVersion.versionNumber,
      diff,
      message: `Diff computed between v${baseVersion.versionNumber} and v${targetVersion.versionNumber}`
    };
  }

  /**
   * Restores map state to a prior snapshot by creating a NEW sequential version.
   * Preserves immutable history: the source version is NEVER modified.
   * @param {string} buildingId
   * @param {number|string} targetVersionIdOrNum - Version to restore from
   * @param {string} restoredBy - Actor requesting rollback
   * @param {string} [reason] - Optional explanation
   * @returns {Promise<object>} Newly created MapVersion representing the rollback
   */
  async rollbackVersion(buildingId, targetVersionIdOrNum, restoredBy, reason) {
    if (!restoredBy) {
      const err = new Error('restoredBy is required');
      err.code = 'MISSING_FIELDS';
      err.statusCode = 400;
      throw err;
    }

    // 1. Fetch target version snapshot before entering transaction
    const targetVersion = await this.getVersion(buildingId, targetVersionIdOrNum);

    const tx = await this.repo.beginTransaction(buildingId);
    try {
      const nextVersionNumber = await this.repo.getNextVersionNumber(buildingId, tx);
      const versionTag = `v${nextVersionNumber}.0.0-rollback-v${targetVersion.versionNumber}`;
      const changeSummary = reason || `Rollback active map state to Version ${targetVersion.versionNumber} (${targetVersion.versionTag})`;

      // 2. Clone the historical snapshot
      const restoredSnapshot = JSON.parse(JSON.stringify(targetVersion.graphSnapshot));

      // 3. Atomically restore active database tables
      await this.repo.restoreActiveMapState(buildingId, restoredSnapshot, tx);

      // 4. Insert new version record with lineage back to targetVersion.id
      const newVersion = await this.repo.insertVersion({
        buildingId,
        versionNumber: nextVersionNumber,
        versionTag,
        changeSummary,
        createdBy: restoredBy,
        publishedBy: restoredBy,
        parentVersionId: targetVersion.id,
        status: 'published',
        graphSnapshot: restoredSnapshot
      }, tx);

      // 5. Commit transaction
      await this.repo.commitTransaction(tx);
      return newVersion;
    } catch (err) {
      await this.repo.rollbackTransaction(tx);
      throw err;
    }
  }
}

module.exports = new VersioningService();
