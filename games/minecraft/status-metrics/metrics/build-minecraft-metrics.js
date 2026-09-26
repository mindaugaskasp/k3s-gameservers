"use strict";

const { GAME } = require("../../../../game-server/status-metrics/config");
const { formatGaugeLines } = require("../../../../game-server/status-metrics/format-metric-lines");
const { readMinecraftWorldSettings } = require("../read-minecraft-world-settings");

// minecraft_* metrics hold what only Minecraft reports. The prefix is written out,
// never built from GAME, so every metric name stays greppable.
function buildMinecraftMetricLines() {
  const game = GAME;
  return [
    ...formatGaugeLines(
      "minecraft_world_setting",
      "A world rule from server.properties; read the name and value labels.",
      readMinecraftWorldSettings().map((setting) => ({ labels: { game, name: setting.name, value: setting.value }, value: 1 }))
    ),
  ];
}

module.exports = { buildMinecraftMetricLines };
