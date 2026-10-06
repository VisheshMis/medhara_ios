// Medha Windows Desktop — Database Manager
// High-performance SQLite engine with WAL mode and FTS5 full-text search

const path = require('path');
const fs = require('fs');
const Database = require('better-sqlite3');
const { DatabaseMigrations } = require('./migrations');
const { MockDataSeeder } = require('./seeder');

class DatabaseManager {
    constructor(dbPath = null) {
        if (!dbPath) {
            // Default desktop path: user profile or project directory
            const appDataDir = process.env.APPDATA || (process.platform === 'darwin' ? path.join(process.env.HOME, 'Library', 'Application Support') : path.join(process.env.HOME, '.config'));
            const medhaDir = path.join(appDataDir, 'Medha');
            if (!fs.existsSync(medhaDir)) {
                fs.mkdirSync(medhaDir, { recursive: true });
            }
            this.dbPath = path.join(medhaDir, 'medha.sqlite');
        } else {
            this.dbPath = dbPath;
        }

        this.db = null;
        this.init();
    }

    init() {
        this.db = new Database(this.dbPath);

        // Performance pragmas
        this.db.pragma('journal_mode = WAL');
        this.db.pragma('synchronous = NORMAL');
        this.db.pragma('foreign_keys = ON');
        this.db.pragma('temp_store = MEMORY');

        // Execute migrations
        DatabaseMigrations.registerMigrations(this.db);

        // Seed initial content if empty
        MockDataSeeder.seedIfMissing(this.db);
    }

    getDatabase() {
        return this.db;
    }

    close() {
        if (this.db) {
            this.db.close();
            this.db = null;
        }
    }
}

module.exports = { DatabaseManager };
