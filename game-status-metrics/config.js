"use strict";

// Everything the exporter is told about the server it sits next to.
const GAME = process.env.GAMEDIG_GAME;
const HOST = process.env.QUERY_HOST || "127.0.0.1";
const PORT = Number(process.env.QUERY_PORT);
const METRICS_PORT = Number(process.env.METRICS_PORT || 9101);
const STATUS_DIR = process.env.STATUS_DIR || "/var/run/valheim-status";
const PERSIST_DIR = process.env.PERSIST_DIR || "/config"; // PVC-backed, survives restarts (unlike STATUS_DIR)
const BACKUP_DIR = process.env.BACKUP_DIR || "/config/backups";
// The server's own command line. World modifiers ride on it as "-modifier <name> <value>".
const SERVER_ARGS = process.env.SERVER_ARGS || "";
const BACKUP_MAX_AGE_DAYS = Number(process.env.BACKUP_MAX_AGE_DAYS || 0);
const BACKUP_MAX_COUNT = Number(process.env.BACKUP_MAX_COUNT || 0);
// Set for games using backup-prune.sh (play-time archive windows).
const BACKUP_RECENT_DAYS = Number(process.env.BACKUP_RECENT_DAYS || 0);
const BACKUP_WINDOW_ENDS = (process.env.BACKUP_ARCHIVE_WINDOW_DAYS || "").split(" ").filter(Boolean).map(Number);

// One file per online player, named after the character, written by the game's
// log hooks (games whose query protocol doesn't report names, e.g. Valheim).
const ONLINE_PLAYERS_DIR = `${STATUS_DIR}/players/online`;
// Appended to by the log hooks, one line per death, and folded into the database.
const DEATH_LOG_FILE = `${STATUS_DIR}/players/deaths`;
// Mounted from the volume but outside the game's own data tree: the game images run
// as root and reset ownership across their data dir on every start.
const DATABASE_DIR = process.env.DATABASE_DIR || `${PERSIST_DIR}/database/sqlite`;
// Named after the game: one database per server, never a file two could share.
const PLAYERS_DATABASE_FILE = `${DATABASE_DIR}/${GAME}-players.db`;

module.exports = {
  GAME,
  HOST,
  PORT,
  METRICS_PORT,
  STATUS_DIR,
  PERSIST_DIR,
  BACKUP_DIR,
  SERVER_ARGS,
  BACKUP_MAX_AGE_DAYS,
  BACKUP_MAX_COUNT,
  BACKUP_RECENT_DAYS,
  BACKUP_WINDOW_ENDS,
  ONLINE_PLAYERS_DIR,
  DEATH_LOG_FILE,
  DATABASE_DIR,
  PLAYERS_DATABASE_FILE,
};
