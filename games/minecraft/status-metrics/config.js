"use strict";

// What only Minecraft's exporter is told; the settings every game shares are in game-server/status-metrics/config.js.
// The server's operators, which the server writes as it changes them.
const MINECRAFT_OPS_FILE = process.env.MINECRAFT_OPS_FILE || "";
// The world rules the image writes from its env vars on every start.
const MINECRAFT_SERVER_PROPERTIES_FILE = process.env.MINECRAFT_SERVER_PROPERTIES_FILE || "";

module.exports = { MINECRAFT_OPS_FILE, MINECRAFT_SERVER_PROPERTIES_FILE };
