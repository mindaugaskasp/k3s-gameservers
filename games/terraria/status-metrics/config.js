"use strict";

// What only Terraria's exporter is told; the settings every game shares are in game-server/status-metrics/config.js.
// The token TShock's REST API asks of every query; its /v2/server/status is what gamedig reads.
const TSHOCK_REST_TOKEN = process.env.TSHOCK_REST_TOKEN || "";

module.exports = { TSHOCK_REST_TOKEN };
