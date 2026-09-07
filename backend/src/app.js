const express = require('express');
const cors = require('cors');
const config = require('./config/env');
const requestLogger = require('./middleware/request_logger');
const errorHandler = require('./middleware/error_handler');

// Feature Routers
const mappingRouter = require('./features/mapping/mapping.router');
const navigationRouter = require('./features/navigation/navigation.router');
const aiRouter = require('./features/ai/ai.router');
const versioningRouter = require('./features/versioning/versioning.router');

const app = express();

// Global Middleware
app.use(cors({ origin: config.corsOrigin }));
app.use(express.json());
app.use(requestLogger);

// Health Check Endpoint (Required by spec)
app.get('/health', (req, res) => {
  res.status(200).json({
    service: 'mapless-backend',
    status: 'ok'
  });
});

// Established API Route Namespaces
app.use('/api/v1/mapping', mappingRouter);
app.use('/api/v1/navigation', navigationRouter);
app.use('/api/v1/ai', aiRouter);
app.use('/api/v1/versioning', versioningRouter);

// 404 Handler
app.use((req, res, next) => {
  res.status(404).json({
    error: {
      code: 'NOT_FOUND',
      message: `Route not found: ${req.method} ${req.originalUrl}`,
      timestamp: new Date().toISOString()
    }
  });
});

// Centralized Error Handling Middleware
app.use(errorHandler);

module.exports = app;
