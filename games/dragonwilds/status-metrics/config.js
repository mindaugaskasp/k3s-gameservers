"use strict";

const { STATUS_DIR } = require("../../../game-server/status-metrics/config");

// What only Dragonwilds' exporter is told; the settings every game shares are in game-server/status-metrics/config.js.
const DRAGONWILDS_LOG_FILE = process.env.DRAGONWILDS_LOG_FILE || "";
// What the log said about the server this pod runs; in STATUS_DIR, as the log's read position is.
const DRAGONWILDS_SERVER_STATE_FILE = `${STATUS_DIR}/dragonwilds-server.json`;

module.exports = { DRAGONWILDS_LOG_FILE, DRAGONWILDS_SERVER_STATE_FILE };
