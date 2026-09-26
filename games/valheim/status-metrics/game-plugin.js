"use strict";

const { recordDeaths } = require("../../../game-server/status-metrics/store-player-history");
const { readNewDeaths } = require("./read-death-log");
const { readCurrentGameDay } = require("./read-valheim-game-day");
const { recordDeathGameDay } = require("./store-valheim-death-days");
const { readNewRaids } = require("./read-raid-log");
const { recordRaids } = require("./store-raids");
const { filterValheimAdminNames } = require("./read-valheim-admins");
const { buildValheimMetricLines } = require("./metrics/build-valheim-metrics");

// Deaths and raids come from the lines the log hooks append (lifecycle-hooks.yaml).
function recordNewLogEvents() {
  const deadPlayerNames = readNewDeaths();
  recordDeaths(deadPlayerNames);
  if (deadPlayerNames.length) recordDeathGameDay(deadPlayerNames, readCurrentGameDay());
  recordRaids(readNewRaids());
}

/** What only Valheim records and reports; game-server/status-metrics/load-game-plugin.js lists each member. */
module.exports = {
  recordNewLogEvents,
  recordQueriedPlayers: () => {}, // Valheim's query reports nothing the core doesn't record.
  filterAdminNames: filterValheimAdminNames,
  readLastDeathLabels: () => ({}),
  buildMetricLines: buildValheimMetricLines,
  playerStatResetValues: { last_death_game_day: null },
};
