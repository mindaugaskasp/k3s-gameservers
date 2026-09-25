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
// One file per online game master, for games that name them only in their log (Enshrouded).
const GAME_MASTERS_DIR = `${STATUS_DIR}/players/game-masters`;
// The game's admin list, one platform ID per line; unset for games without one.
const ADMIN_LIST_FILE = process.env.ADMIN_LIST_FILE || "";
// Appended to by the log hooks, one line per death, and folded into the database.
const DEATH_LOG_FILE = `${STATUS_DIR}/players/deaths`;
// Appended to by Valheim's log hooks, one line per raid, and folded into the database.
const RAID_LOG_FILE = `${STATUS_DIR}/raids`;
// How far each followed log file has been read. In STATUS_DIR, so it outlives an
// exporter restart but starts over with a new pod, whose logs are new too.
const LOG_READ_POSITIONS_FILE = `${STATUS_DIR}/log-read-positions.json`;
// Where Project Zomboid writes its user and pvp logs; unset for every other game.
const ZOMBOID_LOG_DIR = process.env.ZOMBOID_LOG_DIR || "";
// Project Zomboid's sandbox settings and its accounts database; unset for every other game.
const ZOMBOID_SANDBOX_FILE = process.env.ZOMBOID_SANDBOX_FILE || "";
const ZOMBOID_ACCOUNTS_DATABASE_FILE = process.env.ZOMBOID_ACCOUNTS_DATABASE_FILE || "";
// The world's saved characters, which name each account's current character.
const ZOMBOID_PLAYERS_DATABASE_FILE = process.env.ZOMBOID_PLAYERS_DATABASE_FILE || "";
// Enshrouded's server log, which names players as they join and leave; unset elsewhere.
const ENSHROUDED_LOG_FILE = process.env.ENSHROUDED_LOG_FILE || "";
// Enshrouded's server config, holding the difficulty preset and game settings; unset elsewhere.
const ENSHROUDED_CONFIG_FILE = process.env.ENSHROUDED_CONFIG_FILE || "";
// The world's base count from Enshrouded's latest load or save line.
const ENSHROUDED_BASE_COUNT_FILE = `${STATUS_DIR}/enshrouded-base-count`;
// Valheim's folder for this world's save files; unset for every other game.
const WORLD_SAVE_DIR = process.env.WORLD_SAVE_DIR || "";
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
  GAME_MASTERS_DIR,
  ADMIN_LIST_FILE,
  DEATH_LOG_FILE,
  RAID_LOG_FILE,
  LOG_READ_POSITIONS_FILE,
  ZOMBOID_LOG_DIR,
  ZOMBOID_SANDBOX_FILE,
  ZOMBOID_ACCOUNTS_DATABASE_FILE,
  ZOMBOID_PLAYERS_DATABASE_FILE,
  ENSHROUDED_LOG_FILE,
  ENSHROUDED_CONFIG_FILE,
  ENSHROUDED_BASE_COUNT_FILE,
  WORLD_SAVE_DIR,
  DATABASE_DIR,
  PLAYERS_DATABASE_FILE,
};
