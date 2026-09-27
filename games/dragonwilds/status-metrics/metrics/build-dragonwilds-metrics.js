"use strict";

const { GAME } = require("../../../../game-server/status-metrics/config");
const { formatGaugeLines } = require("../../../../game-server/status-metrics/format-metric-lines");
const { readDragonwildsWorldSettings } = require("../track-dragonwilds-server");

// dragonwilds_* metrics hold what only Dragonwilds reports. The prefix is written out,
// never built from GAME, so every metric name stays greppable.
function buildDragonwildsMetricLines() {
  const game = GAME;
  return [
    ...formatGaugeLines(
      "dragonwilds_world_setting",
      "The world's difficulty and hardcore state, as the server loaded them; read the name and value labels.",
      readDragonwildsWorldSettings().map((setting) => ({ labels: { game, name: setting.name, value: setting.value }, value: 1 }))
    ),
  ];
}

module.exports = { buildDragonwildsMetricLines };
