"use strict";

const { markPlayerOnline, markPlayerOffline, clearOnlinePlayers } = require("../../../game-server/status-metrics/track-online-players");
const { readNewDragonwildsEvents } = require("./read-dragonwilds-log");
const { recordServerEvents, readDragonwildsServerState } = require("./track-dragonwilds-server");
const { buildDragonwildsMetricLines } = require("./metrics/build-dragonwilds-metrics");

// Dragonwilds answers no query gamedig knows, so its log says whether it is up and who is on.
function recordNewLogEvents() {
  const events = readNewDragonwildsEvents();
  recordServerEvents(events);
  for (const event of events) {
    if (event.type === "joined") markPlayerOnline(event.name);
    if (event.type === "left") markPlayerOffline(event.name);
    if (event.type === "allLeft") clearOnlinePlayers();
  }
}

/** What only Dragonwilds records and reports; game-server/status-metrics/load-game-plugin.js lists each member. */
module.exports = {
  recordNewLogEvents,
  gamedigQueryOptions: {},
  readServerState: readDragonwildsServerState,
  recordQueryAnswer: () => {},
  readGameVersion: (state) => state.version,
  // Admins are player IDs, which the log's player names cannot be matched to.
  filterAdminNames: () => [],
  readLastDeathLabels: () => ({}),
  buildMetricLines: buildDragonwildsMetricLines,
  playerStatResetValues: {},
};
