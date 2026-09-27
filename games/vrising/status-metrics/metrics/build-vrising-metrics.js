"use strict";

const { GAME } = require("../../../../game-server/status-metrics/config");
const { formatGaugeLines } = require("../../../../game-server/status-metrics/format-metric-lines");
const { readVRisingWorldSettings } = require("../read-vrising-world-settings");

// vrising_* metrics hold what only V Rising reports. The prefix is written out,
// never built from GAME, so every metric name stays greppable.
function buildVRisingMetricLines() {
  const game = GAME;
  return [
    ...formatGaugeLines(
      "vrising_world_setting",
      "Game mode, difficulty and clan size, then each setting changed from the game's default; read the name and value labels.",
      readVRisingWorldSettings().map((setting) => ({ labels: { game, name: setting.name, value: setting.value }, value: 1 }))
    ),
  ];
}

module.exports = { buildVRisingMetricLines };
