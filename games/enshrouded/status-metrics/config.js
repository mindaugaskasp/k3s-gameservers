"use strict";

const { STATUS_DIR } = require("../../../game-status-metrics/config");

// What only Enshrouded's exporter is told; the settings every game shares are in game-status-metrics/config.js.
// The server log, which names players as they join and leave.
const ENSHROUDED_LOG_FILE = process.env.ENSHROUDED_LOG_FILE || "";
// The server config, holding the difficulty preset and game settings.
const ENSHROUDED_CONFIG_FILE = process.env.ENSHROUDED_CONFIG_FILE || "";
// The world's base count from the latest load or save line.
const ENSHROUDED_BASE_COUNT_FILE = `${STATUS_DIR}/enshrouded-base-count`;
// One file per online game master, named like the online-player files: the log is the only place that names them.
const GAME_MASTERS_DIR = `${STATUS_DIR}/players/game-masters`;

module.exports = { ENSHROUDED_LOG_FILE, ENSHROUDED_CONFIG_FILE, ENSHROUDED_BASE_COUNT_FILE, GAME_MASTERS_DIR };
