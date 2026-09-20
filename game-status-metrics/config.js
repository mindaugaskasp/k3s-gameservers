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
// Lifetime player history -- time online, deaths, last seen. On the PVC, and the one
// path both this exporter and the game's log hooks may write.
const PLAYERS_DIR = `${PERSIST_DIR}/players`;
// Named after the game: one database per server, never a file two could share.
const PLAYERS_DATABASE_FILE = `${PLAYERS_DIR}/${GAME}-players.db`;

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
  PLAYERS_DIR,
  PLAYERS_DATABASE_FILE,
};
