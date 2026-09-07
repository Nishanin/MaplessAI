const { Router } = require('express');
const controller = require('./versioning.controller');

const router = Router();

// Versioning routes (Owner: Piyush)
router.post('/buildings/:buildingId/snapshots', controller.createSnapshot);
router.get('/buildings/:buildingId/history', controller.getHistory);
router.post('/buildings/:buildingId/compare', controller.compareVersions);
router.post('/buildings/:buildingId/rollback', controller.rollbackVersion);

module.exports = router;
