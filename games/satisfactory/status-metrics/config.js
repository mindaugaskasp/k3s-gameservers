"use strict";

// What only Satisfactory's exporter is told; the settings every game shares are in game-server/status-metrics/config.js.
// A bearer token for the HTTPS API (server console: server.GenerateAPIToken); only needed
// when a client-protection password blocks the exporter's passwordless login.
const SATISFACTORY_API_TOKEN = process.env.SATISFACTORY_API_TOKEN || "";

module.exports = { SATISFACTORY_API_TOKEN };
