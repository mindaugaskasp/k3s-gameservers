"use strict";

const path = require("path");
const { GAME_DIR } = require("./config");

// Every member a game's plugin must have; the core calls nothing else.
const PLUGIN_MEMBERS = [
  "recordNewLogEvents", // () => void, each query, before the server is asked
  "recordQueriedPlayers", // (gamedig players) => void, after the server answered
  "filterAdminNames", // (online player names) => the game masters among them
  "readLastDeathLabels", // (last death's player row) => extra labels for game_server_last_death_*
  "buildMetricLines", // () => the game's own exposition lines, e.g. valheim_*
  "playerStatResetValues", // { column: value } reset-player-stats clears beyond the shared ones
];

/** games/<game>/status-metrics/game-plugin.js; loaded by the entry points alone, so no core module depends on a game. */
function loadGamePlugin() {
  if (!GAME_DIR) throw new Error("GAME_DIR is required: the image sets it to the game's status-metrics folder");
  const gamePlugin = require(path.join(GAME_DIR, "game-plugin"));
  const missingMembers = PLUGIN_MEMBERS.filter((member) => !(member in gamePlugin));
  if (missingMembers.length) throw new Error(`${GAME_DIR}/game-plugin.js lacks ${missingMembers.join(", ")}`);

  return gamePlugin;
}

module.exports = { loadGamePlugin };
