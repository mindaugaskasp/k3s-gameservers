"use strict";

const { readQueryGameVersion } = require("../../../game-server/status-metrics/read-query-game-version");
const { readSatisfactoryServerState } = require("./read-satisfactory-server-state");
const { storeSatisfactoryQueryAnswer } = require("./store-satisfactory-query-answer");
const { buildSatisfactoryMetricLines } = require("./metrics/build-satisfactory-metrics");

/** What only Satisfactory records and reports; game-server/status-metrics/load-game-plugin.js lists each member. */
module.exports = {
  // The HTTPS API reports the player count without names, so there is no log to follow.
  recordNewLogEvents: () => {},
  gamedigQueryOptions: {},
  readServerState: readSatisfactoryServerState,
  recordQueryAnswer: storeSatisfactoryQueryAnswer,
  readGameVersion: readQueryGameVersion,
  // The API names no players, so nobody can be matched to the admin list.
  filterAdminNames: () => [],
  readLastDeathLabels: () => ({}),
  buildMetricLines: buildSatisfactoryMetricLines,
  playerStatResetValues: {},
};
