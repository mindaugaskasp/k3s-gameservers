"use strict";

const { recordDeaths } = require("../../../game-status-metrics/store-player-history");
const { readNewZomboidDeaths } = require("./read-zomboid-deaths");
const { readCharacterName } = require("./read-zomboid-character-names");
const { recordZombieKills, recordDeathCharacterNames } = require("./store-zomboid-player-history");
const { filterZomboidAdminNames } = require("./read-zomboid-admins");
const { buildZomboidMetricLines } = require("./metrics/build-zomboid-metrics");

function recordNewLogEvents() {
  const deadPlayerNames = readNewZomboidDeaths();
  recordDeaths(deadPlayerNames);
  recordDeathCharacterNames(deadPlayerNames.map((playerName) => ({ playerName, characterName: readCharacterName(playerName) })));
}

// Zomboid reports each player's zombie kills as the query score (SteamGameServer.AddPlayer).
function recordQueriedPlayers(queriedPlayers) {
  recordZombieKills(
    queriedPlayers.filter((player) => player.name).map((player) => ({ name: player.name, zombieKills: player.raw?.score ?? 0 }))
  );
}

// Players name a new character after each death, so the death says who they played.
function readLastDeathLabels(lastDeath) {
  return lastDeath.last_death_character_name ? { character: lastDeath.last_death_character_name } : {};
}

/** What only Zomboid records and reports; game-status-metrics/load-game-plugin.js lists each member. */
module.exports = {
  recordNewLogEvents,
  recordQueriedPlayers,
  filterAdminNames: filterZomboidAdminNames,
  readLastDeathLabels,
  buildMetricLines: buildZomboidMetricLines,
  // A character's last reported kill count is kept: zeroing it would re-credit every
  // kill the current character already has on the next scrape.
  playerStatResetValues: { zombie_kill_count: 0, last_death_character_name: null },
};
