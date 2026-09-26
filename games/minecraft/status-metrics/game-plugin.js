"use strict";

const { filterMinecraftOperatorNames } = require("./read-minecraft-operators");
const { buildMinecraftMetricLines } = require("./metrics/build-minecraft-metrics");

/** What only Minecraft records and reports; game-server/status-metrics/load-game-plugin.js lists each member. */
module.exports = {
  // The server list ping names online players itself, so there is no log to follow.
  recordNewLogEvents: () => {},
  gamedigQueryOptions: {},
  recordQueryAnswer: () => {},
  filterAdminNames: filterMinecraftOperatorNames,
  readLastDeathLabels: () => ({}),
  buildMetricLines: buildMinecraftMetricLines,
  playerStatResetValues: {},
};
