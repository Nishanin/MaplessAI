const service = require('./versioning.service');

/**
 * Map Versioning Controller (Owner: Piyush)
 * Handles version snapshots, audit trail, diffing, and rollbacks.
 */
class VersioningController {
  constructor(versionService = service) {
    this.service = versionService;
    // Bind methods to ensure correct 'this' context in Express routes
    this.createSnapshot = this.createSnapshot.bind(this);
    this.getHistory = this.getHistory.bind(this);
    this.getVersion = this.getVersion.bind(this);
    this.compareVersions = this.compareVersions.bind(this);
    this.rollbackVersion = this.rollbackVersion.bind(this);
  }

  /**
   * POST /api/v1/versioning/buildings/:buildingId/snapshots
   * POST /api/v1/versioning/buildings/:buildingId/versions
   */
  async createSnapshot(req, res, next) {
    try {
      const { buildingId } = req.params;
      const { snapshotData, changeSummary, createdBy, versionTag } = req.body;

      if (!changeSummary || !createdBy) {
        return res.status(400).json({
          error: {
            code: 'MISSING_FIELDS',
            message: 'changeSummary and createdBy are required fields'
          }
        });
      }

      const version = await this.service.createVersion(
        buildingId,
        snapshotData,
        changeSummary,
        createdBy,
        { versionTag }
      );

      return res.status(201).json({
        success: true,
        version,
        message: `Version ${version.versionTag} successfully published`
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /api/v1/versioning/buildings/:buildingId/history
   * GET /api/v1/versioning/buildings/:buildingId/versions
   */
  async getHistory(req, res, next) {
    try {
      const { buildingId } = req.params;
      const versions = await this.service.getVersionHistory(buildingId);

      return res.status(200).json({
        buildingId,
        count: versions.length,
        versions
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * GET /api/v1/versioning/buildings/:buildingId/versions/:versionId
   */
  async getVersion(req, res, next) {
    try {
      const { buildingId, versionId } = req.params;
      const version = await this.service.getVersion(buildingId, versionId);

      return res.status(200).json({
        buildingId,
        version
      });
    } catch (error) {
      next(error);
    }
  }

  /**
   * POST /api/v1/versioning/buildings/:buildingId/compare
   * GET /api/v1/versioning/buildings/:buildingId/versions/diff
   */
  async compareVersions(req, res, next) {
    try {
      const { buildingId } = req.params;
      const baseVersion = req.body?.baseVersion || req.query?.baseVersion;
      const targetVersion = req.body?.targetVersion || req.query?.targetVersion;

      if (baseVersion === undefined || targetVersion === undefined) {
        return res.status(400).json({
          error: {
            code: 'MISSING_PARAMS',
            message: 'Both baseVersion and targetVersion parameters are required for diff'
          }
        });
      }

      const result = await this.service.compareVersions(buildingId, baseVersion, targetVersion);
      return res.status(200).json(result);
    } catch (error) {
      next(error);
    }
  }

  /**
   * POST /api/v1/versioning/buildings/:buildingId/rollback
   * POST /api/v1/versioning/buildings/:buildingId/versions/:versionId/rollback
   */
  async rollbackVersion(req, res, next) {
    try {
      const { buildingId, versionId } = req.params;
      const targetVersion = versionId !== undefined ? versionId : req.body?.targetVersion;
      const restoredBy = req.body?.restoredBy;
      const reason = req.body?.reason;

      if (targetVersion === undefined) {
        return res.status(400).json({
          error: {
            code: 'MISSING_PARAMS',
            message: 'targetVersion is required for rollback'
          }
        });
      }
      if (!restoredBy) {
        return res.status(400).json({
          error: {
            code: 'MISSING_FIELDS',
            message: 'restoredBy is required to authorize and audit the rollback'
          }
        });
      }

      const newVersion = await this.service.rollbackVersion(buildingId, targetVersion, restoredBy, reason);

      return res.status(200).json({
        success: true,
        buildingId,
        restoredVersion: targetVersion,
        newVersion,
        restoredBy,
        restoredAt: newVersion.createdAt,
        message: `Graph successfully rolled back to state of version ${targetVersion}; published as new version ${newVersion.versionNumber}`
      });
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new VersioningController();
