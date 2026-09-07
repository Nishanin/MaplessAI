const config = require('./env');

/**
 * Database client provider stub.
 * In production, this manages the pg.Pool instance.
 * For initial setup, it provides connection state and query stubbing.
 */
class Database {
  constructor() {
    this.isConnected = false;
    this.config = config.databaseUrl;
  }

  async connect() {
    // Database connection placeholder - avoids failing if local PG is not running
    this.isConnected = true;
    return true;
  }

  async query(text, params = []) {
    if (!this.isConnected) {
      await this.connect();
    }
    // Stub implementation for initial repository setup
    return { rows: [], rowCount: 0 };
  }

  async close() {
    this.isConnected = false;
  }
}

const db = new Database();
module.exports = db;
