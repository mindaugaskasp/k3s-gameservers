"use strict";

const { markPlayerOnline, markPlayerOffline, clearOnlinePlayers } = require("../../../game-server/status-metrics/track-online-players");
const { readNewEnshroudedEvents } = require("./read-enshrouded-log");
const { recordEnshroudedBaseCount } = require("./store-enshrouded-base-count");
const { markGameMaster, unmarkGameMaster, filterEnshroudedAdminNames } = require("./track-enshrouded-game-masters");
const { buildEnshroudedMetricLines } = require("./metrics/build-enshrouded-metrics");

// Enshrouded's query protocol reports no names, so its log keeps the online list instead,
// the way Valheim's log hooks do.
function recordNewLogEvents() {
  for (const event of readNewEnshroudedEvents()) {
    if (event.type === "joined") markPlayerOnline(event.name);
    // Every login lists permissions afresh, so a demoted admin loses the badge.
    if (event.type === "permissionsListed") unmarkGameMaster(event.name);
    if (event.type === "gameMaster") markGameMaster(event.name);
    if (event.type === "left") {
      markPlayerOffline(event.name);
      unmarkGameMaster(event.name);
    }
    if (event.type === "allLeft") clearOnlinePlayers();
    if (event.type === "baseCount") recordEnshroudedBaseCount(event.count);
  }
}

/** What only Enshrouded records and reports; game-server/status-metrics/load-game-plugin.js lists each member. */
module.exports = {
  recordNewLogEvents,
  recordQueriedPlayers: () => {}, // Enshrouded's query reports nothing the core doesn't record.
  filterAdminNames: filterEnshroudedAdminNames,
  readLastDeathLabels: () => ({}),
  buildMetricLines: buildEnshroudedMetricLines,
  playerStatResetValues: {},
};
