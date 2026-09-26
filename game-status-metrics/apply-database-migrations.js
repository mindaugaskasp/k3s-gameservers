"use strict";

const fs = require("fs");
const path = require("path");
const { GAME } = require("./config");

// Each game's database has its own migrations, never shared with another game's.
const MIGRATIONS_DIR = path.join(__dirname, "migrations", GAME);

// One row per applied migration, like Doctrine's doctrine_migration_versions:
// https://www.doctrine-project.org/projects/doctrine-migrations/en/current/
const MIGRATION_TABLE = `
  CREATE TABLE IF NOT EXISTS migration (
    version TEXT PRIMARY KEY,
    executed_at INTEGER NOT NULL
  );
`;

/** This game's migrations, oldest first: the filename is the version. */
function readMigrations() {
  return fs
    .readdirSync(MIGRATIONS_DIR)
    .filter((file) => file.endsWith(".js"))
    .sort()
    .map((file) => ({ version: path.basename(file, ".js"), up: require(path.join(MIGRATIONS_DIR, file)).up }));
}

/**
 * Applies whatever this database has not run yet, each in its own transaction, and
 * returns the versions applied. Adding a migration means adding a file, never editing
 * one that has shipped.
 */
function applyMigrations(database) {
  database.exec(MIGRATION_TABLE);
  const applied = new Set(database.prepare("SELECT version FROM migration").all().map((row) => row.version));
  const record = database.prepare("INSERT INTO migration (version, executed_at) VALUES (?, ?)");
  const pending = readMigrations().filter((migration) => !applied.has(migration.version));

  for (const migration of pending) {
    database.exec("BEGIN");
    try {
      migration.up(database);
      record.run(migration.version, Math.floor(Date.now() / 1000));
      database.exec("COMMIT");
    } catch (error) {
      database.exec("ROLLBACK");
      throw error;
    }
  }

  return pending.map((migration) => migration.version);
}

module.exports = { applyMigrations };
