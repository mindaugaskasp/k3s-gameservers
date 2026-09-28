"use strict";

const fs = require("fs");
const path = require("path");
// Schema every game shares lives beside this file; a game's own columns live in its games/<game>/status-metrics/migrations.
const { MIGRATIONS_DIR } = require("./config");

const SHARED_MIGRATIONS_DIR = path.join(__dirname, "migrations");

// One row per applied migration, like Doctrine's doctrine_migration_versions:
// https://www.doctrine-project.org/projects/doctrine-migrations/en/current/
const MIGRATION_TABLE = `
  CREATE TABLE IF NOT EXISTS migration (
    version TEXT PRIMARY KEY,
    executed_at INTEGER NOT NULL
  );
`;

function readMigrationsInDirectory(directory) {
  if (!fs.existsSync(directory)) {
    return [];
  }

  return fs
    .readdirSync(directory)
    .filter((file) => file.endsWith(".js"))
    .map((file) => ({ version: path.basename(file, ".js"), up: require(path.join(directory, file)).up }));
}

/** The shared migrations plus this game's own, oldest first: the filename is the version. */
function readMigrations() {
  return [...readMigrationsInDirectory(SHARED_MIGRATIONS_DIR), ...readMigrationsInDirectory(MIGRATIONS_DIR)].sort(
    (first, second) => first.version.localeCompare(second.version),
  );
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
