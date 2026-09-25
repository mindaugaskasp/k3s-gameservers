"use strict";

const { GAME } = require("../config");
const { gaugeLines } = require("../metric-lines");
const { readZombieKillCounts } = require("../player-database");
const { readChangedSandboxSettings } = require("../zomboid-sandbox");

// zomboid_* metrics hold what only Project Zomboid reports. The prefix is written out,
// never built from GAME, so every metric name stays greppable.
function zomboidMetricLines() {
  const game = GAME;
  return [
    ...gaugeLines(
      "zomboid_player_zombie_kills",
      "Zombies a player has killed on this server, across every character they have had.",
      readZombieKillCounts().map((player) => ({ labels: { game, name: player.name }, value: player.count }))
    ),
    ...gaugeLines(
      "zomboid_world_setting",
      "A sandbox setting changed from the game's default; read the name and value labels.",
      readChangedSandboxSettings().map((setting) => ({ labels: { game, name: setting.name, value: setting.value }, value: 1 }))
    ),
  ];
}

module.exports = { zomboidMetricLines };
