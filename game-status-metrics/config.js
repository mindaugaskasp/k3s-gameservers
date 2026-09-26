"use strict";

// What every game's exporter is told about the server it sits next to. A game's own
// settings live in its games/<game>/status-metrics/config.js.
const GAME = process.env.GAMEDIG_GAME;
const HOST = process.env.QUERY_HOST || "127.0.0.1";
const PORT = Number(process.env.QUERY_PORT);
const METRICS_PORT = Number(process.env.METRICS_PORT || 9101);
const STATUS_DIR = process.env.STATUS_DIR || "/var/run/game-status";
const PERSIST_DIR = process.env.PERSIST_DIR || "/config"; // PVC-backed, survives restarts (unlike STATUS_DIR)
const BACKUP_DIR = process.env.BACKUP_DIR || "/config/backups";
const BACKUP_MAX_AGE_DAYS = Number(process.env.BACKUP_MAX_AGE_DAYS || 0);
const BACKUP_MAX_COUNT = Number(process.env.BACKUP_MAX_COUNT || 0);
// The game's own folder, games/<game>/status-metrics, set by the image it was built into.
const GAME_DIR = process.env.GAME_DIR || "";
const MIGRATIONS_DIR = `${GAME_DIR}/migrations`;

// One file per online player, written by the game's log hooks or its log reader.
const ONLINE_PLAYERS_DIR = `${STATUS_DIR}/players/online`;
// How far each followed log file has been read. In STATUS_DIR, so it outlives an
// exporter restart but starts over with a new pod, whose logs are new too.
const LOG_READ_POSITIONS_FILE = `${STATUS_DIR}/log-read-positions.json`;
// Mounted from the volume but outside the game's own data tree: the game images run
// as root and reset ownership across their data dir on every start.
const DATABASE_DIR = process.env.DATABASE_DIR || `${PERSIST_DIR}/database/sqlite`;
// Named after the game: one database per server, never a file two could share.
const PLAYERS_DATABASE_FILE = `${DATABASE_DIR}/${GAME}.db`;
// Where it was kept before; open-sqlite-database.js moves a database found there.
const OLD_PLAYERS_DATABASE_FILE = `${DATABASE_DIR}/${GAME}-players.db`;

module.exports = {
  GAME,
  HOST,
  PORT,
  METRICS_PORT,
  STATUS_DIR,
  PERSIST_DIR,
  BACKUP_DIR,
  BACKUP_MAX_AGE_DAYS,
  BACKUP_MAX_COUNT,
  GAME_DIR,
  MIGRATIONS_DIR,
  ONLINE_PLAYERS_DIR,
  LOG_READ_POSITIONS_FILE,
  DATABASE_DIR,
  PLAYERS_DATABASE_FILE,
  OLD_PLAYERS_DATABASE_FILE,
};
