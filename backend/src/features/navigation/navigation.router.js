const { Router } = require('express');
const controller = require('./navigation.controller');

const router = Router();

// Navigation routes (Owner: Pratik)
router.post('/route', controller.computeRoute);

module.exports = router;
