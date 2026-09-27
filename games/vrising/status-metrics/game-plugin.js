"use strict";

const { readVRisingVersion } = require("./read-vrising-version");
const { buildVRisingMetricLines } = require("./metrics/build-vrising-metrics");

/** What only V Rising records and reports; game-server/status-metrics/load-game-plugin.js lists each member. */
module.exports = {
  // The Steam query names online players itself, so there is no log to follow.
  recordNewLogEvents: () => {},
  gamedigQueryOptions: {},
  readServerState: null,
  recordQueryAnswer: () => {},
  readGameVersion: readVRisingVersion,
  // adminlist.txt holds Steam IDs, which the query's player names cannot be matched to.
  filterAdminNames: () => [],
  readLastDeathLabels: () => ({}),
  buildMetricLines: buildVRisingMetricLines,
  playerStatResetValues: {},
};
