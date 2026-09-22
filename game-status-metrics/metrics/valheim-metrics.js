"use strict";

const { GAME } = require("../config");
const { gaugeLines } = require("../metric-lines");
const { readModState } = require("../status-files");
const { readWorldModifiers } = require("../world-modifiers");

// valheim_* metrics hold what only Valheim reports: mod state from mod-guard.sh and the
// world rules on its command line. The prefix is written out, never built from GAME, so
// every metric name stays greppable.
function valheimMetricLines() {
  const game = GAME;
  const mods = readModState();
  return [
    ...gaugeLines(
      "valheim_mods_active",
      "Whether the server started with mods loaded (0 = fail-safe dropped them).",
      mods ? [{ labels: { game }, value: mods.active }] : []
    ),
    ...gaugeLines(
      "valheim_mods_info",
      "Why mods are or are not loaded; read the reason label.",
      mods ? [{ labels: { game, reason: mods.status }, value: 1 }] : []
    ),
    ...gaugeLines(
      "valheim_world_modifier",
      "A world rule the server runs with; read the name and value labels.",
      readWorldModifiers().map((modifier) => ({
        labels: { game, name: modifier.name, value: modifier.value },
        value: 1,
      }))
    ),
  ];
}

module.exports = { valheimMetricLines };
