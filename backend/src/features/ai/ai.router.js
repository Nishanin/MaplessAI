const { Router } = require('express');
const controller = require('./ai.controller');

const router = Router();

// AI & Semantic Query routes (Owner: Surabhi)
router.post('/query', controller.processQuery);

module.exports = router;
