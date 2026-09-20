"use strict";

const fs = require("fs");
const { DatabaseSync } = require("node:sqlite");
const { DATABASE_DIR, PLAYERS_DATABASE_FILE } = require("./config");
const { runMigrations } = require("./database-migrations");

/** Enough names for a leaderboard; every row is kept either way. */
const RANKED_PLAYER_LIMIT = 10;
const SEEN_PLAYER_LIMIT = 50;
// A gap longer than this means the exporter was not watching, and nobody knows who
// stayed online across it, so it is credited to no one.
const MAX_CREDITED_GAP_SECONDS = 60;

// WAL so the game's log hook can record a death while a scrape is reading:
// https://sqlite.org/wal.html
const CONNECTION_SETTINGS = `
  PRAGMA journal_mode = WAL;
  PRAGMA busy_timeout = 5000;
`;

const nowInSeconds = () => Math.floor(Date.now() / 1000);

let database = null;

/**
 * One connection, opened on first use. This process creates the file so that it owns
 * it: the log hooks write as another user, and a file they created first would be one
 * this user could not write. Mode 0666 so their writes land whoever they run as.
 */
function openDatabase() {
  if (database) return database;
  try {
    fs.mkdirSync(DATABASE_DIR, { recursive: true });
    const opened = new DatabaseSync(PLAYERS_DATABASE_FILE);
    opened.exec(CONNECTION_SETTINGS);
    runMigrations(opened);
    fs.chmodSync(PLAYERS_DATABASE_FILE, 0o666);
    database = opened;
  } catch {
    // Read-only or missing volume: player history is a nicety, never worth failing a scrape over.
    database = null;
  }

  return database;
}

function readRows(sql, ...parameters) {
  const db = openDatabase();
  try {
    return db ? db.prepare(sql).all(...parameters) : [];
  } catch {
    return [];
  }
}

function runForEachPlayer(sql, names, value) {
  const db = openDatabase();
  if (!db || !names.length) return;
  try {
    const statement = db.prepare(sql);
    for (const name of names) statement.run(name, value);
  } catch {
    return;
  }
}

/** Stamped every scrape rather than on disconnect: a missed disconnect line then costs nothing. */
function recordPlayersSeen(names) {
  runForEachPlayer(
    `INSERT INTO player (name, last_seen_at) VALUES (?, ?)
       ON CONFLICT(name) DO UPDATE SET last_seen_at = excluded.last_seen_at`,
    names,
    nowInSeconds()
  );
}

/** Seconds since the last credit, and stamps this one, so every scrape is counted once. */
function secondsSinceLastCredit(database_) {
  const key = "play_time_credited_at";
  const now = nowInSeconds();
  const lastCreditedAt = database_.prepare("SELECT value FROM exporter_state WHERE key = ?").get(key)?.value ?? 0;
  database_
    .prepare("INSERT INTO exporter_state (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value")
    .run(key, now);
  const elapsed = now - lastCreditedAt;

  return lastCreditedAt > 0 && elapsed > 0 && elapsed <= MAX_CREDITED_GAP_SECONDS ? elapsed : 0;
}

/**
 * Adds the time since the previous scrape to every player online now. Counting up as
 * they play rather than on disconnect means a missed disconnect line costs nothing.
 */
function creditPlayTime(names) {
  const db = openDatabase();
  if (!db) return;
  let seconds = 0;
  try {
    seconds = secondsSinceLastCredit(db);
  } catch {
    return;
  }
  if (!seconds) return;

  runForEachPlayer(
    `INSERT INTO player (name, play_time_seconds) VALUES (?, ?)
       ON CONFLICT(name) DO UPDATE SET play_time_seconds = play_time_seconds + excluded.play_time_seconds`,
    names,
    seconds
  );
}

/** Most recently seen first. */
function readPlayersSeen() {
  return readRows(
    "SELECT name, last_seen_at AS at FROM player WHERE last_seen_at IS NOT NULL ORDER BY last_seen_at DESC LIMIT ?",
    SEEN_PLAYER_LIMIT
  );
}

/** Longest played first. */
function readPlayTimeTotals() {
  return readRows(
    "SELECT name, play_time_seconds AS seconds FROM player WHERE play_time_seconds > 0 ORDER BY seconds DESC, name LIMIT ?",
    RANKED_PLAYER_LIMIT
  );
}

/** Most deaths first; the game's log hook counts them. */
function readDeathCounts() {
  return readRows(
    "SELECT name, death_count AS count FROM player WHERE death_count > 0 ORDER BY count DESC, name LIMIT ?",
    RANKED_PLAYER_LIMIT
  );
}

module.exports = { recordPlayersSeen, creditPlayTime, readPlayersSeen, readPlayTimeTotals, readDeathCounts };
