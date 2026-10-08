"use strict";

const { GAME } = require("../../../../game-server/status-metrics/config");
const { formatGaugeLines } = require("../../../../game-server/status-metrics/format-metric-lines");
const { readSatisfactoryGameStateAnswer } = require("../store-satisfactory-query-answer");

// satisfactory_* metrics hold what only Satisfactory reports. The prefix is written out,
// never built from GAME, so every metric name stays greppable.
function buildSatisfactoryMetricLines() {
  const game = GAME;
  const gameState = readSatisfactoryGameStateAnswer();
  return [
    ...formatGaugeLines(
      "satisfactory_session",
      "The save the server is playing (value always 1); read the name label.",
      gameState?.activeSessionName ? [{ labels: { game, name: gameState.activeSessionName }, value: 1 }] : []
    ),
    ...formatGaugeLines(
      "satisfactory_tech_tier",
      "The highest tech tier unlocked in this save.",
      typeof gameState?.techTier === "number" ? [{ labels: { game }, value: gameState.techTier }] : []
    ),
    ...formatGaugeLines(
      "satisfactory_game_duration_seconds",
      "How long this save has been played in total.",
      typeof gameState?.totalGameDuration === "number" ? [{ labels: { game }, value: gameState.totalGameDuration }] : []
    ),
    ...formatGaugeLines(
      "satisfactory_average_tick_rate",
      "Ticks per second the server simulates at.",
      typeof gameState?.averageTickRate === "number" ? [{ labels: { game }, value: gameState.averageTickRate }] : []
    ),
    ...formatGaugeLines(
      "satisfactory_game_paused",
      "Whether the session is paused; the server can pause itself while empty.",
      gameState ? [{ labels: { game }, value: gameState.isGamePaused ? 1 : 0 }] : []
    ),
  ];
}

module.exports = { buildSatisfactoryMetricLines };
