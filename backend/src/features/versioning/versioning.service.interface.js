/**
 * Map Versioning Service Interface (Owner: Piyush)
 * Defines the contract for snapshot creation, history retrieval, diffing, and rollback.
 *
 * Isolated from mapping and navigation implementations.
 */
class IVersioningService {
  /**
   * Creates an immutable snapshot of the building's current spatial graph.
   * @param {string} buildingId - Unique identifier of the building
   * @param {object} snapshotData - Complete serialized graph state
   * @param {string} changeSummary - Description of updates
   * @param {string} createdBy - Author or contributor identifier
   * @returns {Promise<object>} Created version metadata
   */
  async createVersion(buildingId, snapshotData, changeSummary, createdBy) {
    throw new Error('createVersion() not implemented');
  }

  /**
   * Retrieves chronological version audit history for a building.
   * @param {string} buildingId - Unique identifier of the building
   * @returns {Promise<Array<object>>} List of historical versions
   */
  async getVersionHistory(buildingId) {
    throw new Error('getVersionHistory() not implemented');
  }

  /**
   * Computes topological and semantic differences between two snapshots.
   * @param {string} buildingId - Unique identifier of the building
   * @param {number} baseVersion - Starting version number
   * @param {number} targetVersion - Target version number to compare against
   * @returns {Promise<object>} Graph diff (nodes added/removed/modified, edges added/removed/modified)
   */
  async compareVersions(buildingId, baseVersion, targetVersion) {
    throw new Error('compareVersions() not implemented');
  }

  /**
   * Restores active building graph state to a prior immutable snapshot.
   * @param {string} buildingId - Unique identifier of the building
   * @param {number} targetVersion - Version number to restore
   * @param {string} restoredBy - Authorizer ID
   * @returns {Promise<object>} Rollback result confirmation
   */
  async rollbackVersion(buildingId, targetVersion, restoredBy) {
    throw new Error('rollbackVersion() not implemented');
  }
}

module.exports = IVersioningService;
