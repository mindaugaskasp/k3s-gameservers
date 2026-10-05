"use strict";

const { GAME } = require("../../../../game-server/status-metrics/config");
const { formatGaugeLines } = require("../../../../game-server/status-metrics/format-metric-lines");
const { readPalworldServerMetricsAnswer } = require("../store-palworld-query-answer");
const { readPalworldWorldSettings } = require("../read-palworld-world-settings");

// palworld_* metrics hold what only Palworld reports. The prefix is written out,
// never built from GAME, so every metric name stays greppable.
function buildPalworldMetricLines() {
  const game = GAME;
  const serverMetrics = readPalworldServerMetricsAnswer();
  return [
    ...formatGaugeLines(
      "palworld_world_setting",
      "Difficulty, death penalty and the other headline rules, then each rate changed from the game's default; read the name and value labels.",
      readPalworldWorldSettings().map((setting) => ({ labels: { game, name: setting.name, value: setting.value }, value: 1 }))
    ),
    ...formatGaugeLines(
      "palworld_game_day",
      "The world's current in-game day.",
      typeof serverMetrics?.days === "number" ? [{ labels: { game }, value: serverMetrics.days }] : []
    ),
    ...formatGaugeLines(
      "palworld_server_fps",
      "Frames per second the server simulates at.",
      typeof serverMetrics?.serverfps === "number" ? [{ labels: { game }, value: serverMetrics.serverfps }] : []
    ),
  ];
}

module.exports = { buildPalworldMetricLines };
