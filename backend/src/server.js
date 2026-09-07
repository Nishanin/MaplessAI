const app = require('./app');
const config = require('./config/env');
const db = require('./config/database');

async function startServer() {
  try {
    // Initialize database connectivity
    await db.connect();

    app.listen(config.port, () => {
      console.log(`=========================================`);
      console.log(`  MapLess AI Backend Service`);
      console.log(`  Environment: ${config.env}`);
      console.log(`  Port:        ${config.port}`);
      console.log(`  Health:      http://localhost:${config.port}/health`);
      console.log(`=========================================`);
    });
  } catch (error) {
    console.error('Fatal: Failed to start MapLess AI backend server:', error);
    process.exit(1);
  }
}

if (require.main === module) {
  startServer();
}

module.exports = { startServer };
