"use strict";

// What only Palworld's exporter is told; the settings every game shares are in game-server/status-metrics/config.js.
// The REST API's basic auth password (user "admin"); gamedig's palworld protocol queries that API.
const PALWORLD_ADMIN_PASSWORD = process.env.PALWORLD_ADMIN_PASSWORD || "";

module.exports = { PALWORLD_ADMIN_PASSWORD };
