const { Router } = require('express');
const controller = require('./mapping.controller');

const router = Router();

// Mapping routes (Owner: Nishant)
router.get('/buildings', controller.getBuildings);
router.get('/buildings/:buildingId/floors/:floorId/graph', controller.getFloorGraph);
router.post('/buildings/:buildingId/floors/:floorId/nodes', controller.createNode);
router.post('/buildings/:buildingId/floors/:floorId/edges', controller.createEdge);

module.exports = router;
