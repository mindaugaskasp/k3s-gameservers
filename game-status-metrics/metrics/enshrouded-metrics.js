"use strict";

const { GAME } = require("../config");
const { gaugeLines } = require("../metric-lines");
const { readEnshroudedBaseCount } = require("../status-files");

// enshrouded_* metrics hold what only Enshrouded reports. The prefix is written out,
// never built from GAME, so every metric name stays greppable.
function enshroudedMetricLines() {
  const game = GAME;
  const baseCount = readEnshroudedBaseCount();
  return gaugeLines(
    "enshrouded_world_bases",
    "Player-built bases in the world, as of its latest load or save.",
    baseCount === null ? [] : [{ labels: { game }, value: baseCount }]
  );
}

module.exports = { enshroudedMetricLines };
