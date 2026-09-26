"use strict";

const { STATUS_DIR } = require("../../../game-status-metrics/config");

// What only Valheim's exporter is told; the settings every game shares are in game-status-metrics/config.js.
// The game's admin list, one platform ID per line.
const ADMIN_LIST_FILE = process.env.ADMIN_LIST_FILE || "";
// The folder for this world's save files.
const WORLD_SAVE_DIR = process.env.WORLD_SAVE_DIR || "";
// The server's own command line. World modifiers ride on it as "-modifier <name> <value>".
const SERVER_ARGS = process.env.SERVER_ARGS || "";
// backup-prune.sh's play-time archive windows.
const BACKUP_RECENT_DAYS = Number(process.env.BACKUP_RECENT_DAYS || 0);
const BACKUP_WINDOW_ENDS = (process.env.BACKUP_ARCHIVE_WINDOW_DAYS || "").split(" ").filter(Boolean).map(Number);
// Appended to by the log hooks, one line per death and one per raid, and folded into the database.
const DEATH_LOG_FILE = `${STATUS_DIR}/players/deaths`;
const RAID_LOG_FILE = `${STATUS_DIR}/raids`;

module.exports = {
  ADMIN_LIST_FILE,
  WORLD_SAVE_DIR,
  SERVER_ARGS,
  BACKUP_RECENT_DAYS,
  BACKUP_WINDOW_ENDS,
  DEATH_LOG_FILE,
  RAID_LOG_FILE,
};
