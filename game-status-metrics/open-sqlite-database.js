"use strict";

const fs = require("fs");
const { DatabaseSync } = require("node:sqlite");
const { DATABASE_DIR, PLAYERS_DATABASE_FILE, OLD_PLAYERS_DATABASE_FILE } = require("./config");
const { applyMigrations } = require("./apply-database-migrations");

// WAL lets anyone inspecting the file read it without blocking the exporter's writes:
// https://sqlite.org/wal.html
const CONNECTION_SETTINGS = `
  PRAGMA journal_mode = WAL;
  PRAGMA busy_timeout = 5000;
`;

let database = null;
let reportedDatabaseFailure = false;

// Never worth failing a scrape over, but reported once so a broken database is visible.
function reportDatabaseFailure(problem, error) {
  if (!reportedDatabaseFailure) console.error(`player database ${problem}: ${error.message}`);
  reportedDatabaseFailure = true;
}

// Moved with its WAL files before anything opens it, so no write is left behind in them.
function moveDatabaseFromOldName() {
  if (!fs.existsSync(OLD_PLAYERS_DATABASE_FILE) || fs.existsSync(PLAYERS_DATABASE_FILE)) return;
  for (const suffix of ["-wal", "-shm", ""]) {
    if (fs.existsSync(OLD_PLAYERS_DATABASE_FILE + suffix)) fs.renameSync(OLD_PLAYERS_DATABASE_FILE + suffix, PLAYERS_DATABASE_FILE + suffix);
  }
}

// This process is the database's only writer: a second one running as another user
// would create -wal and -shm files this one cannot write.
function openDatabase() {
  if (database) return database;
  try {
    fs.mkdirSync(DATABASE_DIR, { recursive: true });
    moveDatabaseFromOldName();
    const openedDatabase = new DatabaseSync(PLAYERS_DATABASE_FILE);
    openedDatabase.exec(CONNECTION_SETTINGS);
    applyMigrations(openedDatabase);
    database = openedDatabase;
  } catch (error) {
    reportDatabaseFailure("unavailable", error);
    database = null;
  }

  return database;
}

function readRows(sql, ...parameters) {
  const openedDatabase = openDatabase();
  try {
    return openedDatabase ? openedDatabase.prepare(sql).all(...parameters) : [];
  } catch {
    return [];
  }
}

function writeRows(sql, parameterRows) {
  const openedDatabase = openDatabase();
  if (!openedDatabase || !parameterRows.length) return;
  try {
    const statement = openedDatabase.prepare(sql);
    for (const parameters of parameterRows) statement.run(...parameters);
  } catch (error) {
    reportDatabaseFailure("not writable", error);
  }
}

module.exports = { openDatabase, readRows, writeRows, reportDatabaseFailure };
