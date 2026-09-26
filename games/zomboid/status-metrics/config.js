"use strict";

// What only Zomboid's exporter is told; the settings every game shares are in game-status-metrics/config.js.
// Where the game writes its user and pvp logs.
const ZOMBOID_LOG_DIR = process.env.ZOMBOID_LOG_DIR || "";
// The sandbox settings and the accounts database.
const ZOMBOID_SANDBOX_FILE = process.env.ZOMBOID_SANDBOX_FILE || "";
const ZOMBOID_ACCOUNTS_DATABASE_FILE = process.env.ZOMBOID_ACCOUNTS_DATABASE_FILE || "";
// The world's saved characters, which name each account's current character.
const ZOMBOID_PLAYERS_DATABASE_FILE = process.env.ZOMBOID_PLAYERS_DATABASE_FILE || "";

module.exports = { ZOMBOID_LOG_DIR, ZOMBOID_SANDBOX_FILE, ZOMBOID_ACCOUNTS_DATABASE_FILE, ZOMBOID_PLAYERS_DATABASE_FILE };
