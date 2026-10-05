"use strict";

const { readQueryGameVersion } = require("../../../game-server/status-metrics/read-query-game-version");
const { PALWORLD_ADMIN_PASSWORD } = require("./config");
const { storePalworldQueryAnswer } = require("./store-palworld-query-answer");
const { buildPalworldMetricLines } = require("./metrics/build-palworld-metrics");

/** What only Palworld records and reports; game-server/status-metrics/load-game-plugin.js lists each member. */
module.exports = {
  // The REST API names online players itself, so there is no log to follow.
  recordNewLogEvents: () => {},
  gamedigQueryOptions: { username: "admin", password: PALWORLD_ADMIN_PASSWORD },
  readServerState: null,
  recordQueryAnswer: storePalworldQueryAnswer,
  readGameVersion: readQueryGameVersion,
  // The REST player list doesn't say who is an admin.
  filterAdminNames: () => [],
  readLastDeathLabels: () => ({}),
  buildMetricLines: buildPalworldMetricLines,
  playerStatResetValues: {},
};
