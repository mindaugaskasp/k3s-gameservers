"use strict";

const { readQueryGameVersion } = require("../../../game-server/status-metrics/read-query-game-version");
const { TSHOCK_REST_TOKEN } = require("./config");
const { recordOnlineAdmins, filterTerrariaAdminNames } = require("./track-terraria-admins");

/** What only Terraria records and reports; game-server/status-metrics/load-game-plugin.js lists each member. */
module.exports = {
  // TShock's REST status names online players itself, so there is no log to follow.
  recordNewLogEvents: () => {},
  gamedigQueryOptions: { token: TSHOCK_REST_TOKEN },
  recordQueryAnswer: recordOnlineAdmins,
  readGameVersion: readQueryGameVersion,
  filterAdminNames: filterTerrariaAdminNames,
  readLastDeathLabels: () => ({}),
  buildMetricLines: () => [],
  playerStatResetValues: {},
};
