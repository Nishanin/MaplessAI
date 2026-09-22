const { Router } = require('express');
const controller = require('./versioning.controller');

const router = Router();

// Versioning routes (Owner: Piyush)
// 1. Snapshot publication (support contract path + REST versions path)
router.post('/buildings/:buildingId/snapshots', controller.createSnapshot);
router.post('/buildings/:buildingId/versions', controller.createSnapshot);

// 2. Version history list
router.get('/buildings/:buildingId/history', controller.getHistory);
router.get('/buildings/:buildingId/versions', controller.getHistory);

// 3. Version diff (support POST /compare + GET /versions/diff)
router.post('/buildings/:buildingId/compare', controller.compareVersions);
router.get('/buildings/:buildingId/versions/diff', controller.compareVersions);

// 4. Rollback (support contract path + REST path)
router.post('/buildings/:buildingId/rollback', controller.rollbackVersion);
router.post('/buildings/:buildingId/versions/:versionId/rollback', controller.rollbackVersion);

// 5. Get single version details (placed after /diff to avoid path collision)
router.get('/buildings/:buildingId/versions/:versionId', controller.getVersion);

module.exports = router;
