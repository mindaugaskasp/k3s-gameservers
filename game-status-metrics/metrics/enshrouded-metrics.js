"use strict";

const { GAME } = require("../config");
const { gaugeLines } = require("../metric-lines");
const { readEnshroudedBaseCount } = require("../status-files");
const { readEnshroudedWorldSettings } = require("../enshrouded-settings");

// enshrouded_* metrics hold what only Enshrouded reports. The prefix is written out,
// never built from GAME, so every metric name stays greppable.
function enshroudedMetricLines() {
  const game = GAME;
  const baseCount = readEnshroudedBaseCount();
  return [
    ...gaugeLines(
      "enshrouded_world_bases",
      "Player-built bases in the world, as of its latest load or save.",
      baseCount === null ? [] : [{ labels: { game }, value: baseCount }]
    ),
    ...gaugeLines(
      "enshrouded_world_setting",
      "The difficulty preset, and with a Custom one each setting changed from Default; read the name and value labels.",
      readEnshroudedWorldSettings().map((setting) => ({ labels: { game, name: setting.name, value: setting.value }, value: 1 }))
    ),
  ];
}

module.exports = { enshroudedMetricLines };
