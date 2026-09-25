"use strict";

const { GAME } = require("../config");
const { formatGaugeLines } = require("../format-metric-lines");
const { readModState } = require("../read-status-files");
const { readWorldModifiers } = require("../read-world-modifiers");
const { readRaidCount, readLatestRaid } = require("../store-raids");
const { readDefeatedBosses } = require("../read-defeated-bosses");

// The log marks only a raid's start. The longest lasts 150s, longer while nobody is near:
// https://valheim.weirdgloop.org/w/Events
const RAID_LIKELY_ACTIVE_SECONDS = 150;

function readRaidActiveSamples(game) {
  const raid = readLatestRaid();
  if (!raid) return [];
  const isActive = Math.floor(Date.now() / 1000) - raid.startedAt < RAID_LIKELY_ACTIVE_SECONDS;

  return [{ labels: { game, name: raid.eventId }, value: isActive ? 1 : 0 }];
}

// valheim_* metrics hold what only Valheim reports: mod state from mod-guard.sh, the world
// rules on its command line, raids from its log and bosses from its save. The prefix is written out, never built
// from GAME, so every metric name stays greppable.
function buildValheimMetricLines() {
  const game = GAME;
  const mods = readModState();
  // Other games share the database file, where no raid is ever recorded: 0 would be a lie.
  const raidCount = GAME === "valheim" ? readRaidCount() : null;
  return [
    ...formatGaugeLines(
      "valheim_mods_active",
      "Whether the server started with mods loaded (0 = fail-safe dropped them).",
      mods ? [{ labels: { game }, value: mods.active }] : []
    ),
    ...formatGaugeLines(
      "valheim_mods_info",
      "Why mods are or are not loaded; read the reason label.",
      mods ? [{ labels: { game, reason: mods.status }, value: 1 }] : []
    ),
    ...formatGaugeLines(
      "valheim_world_modifier",
      "A world rule the server runs with; read the name and value labels.",
      readWorldModifiers().map((modifier) => ({
        labels: { game, name: modifier.name, value: modifier.value },
        value: 1,
      }))
    ),
    ...formatGaugeLines(
      "valheim_raids",
      "How many raids have started on this server, counted from the server log.",
      raidCount === null ? [] : [{ labels: { game }, value: raidCount }]
    ),
    ...formatGaugeLines(
      "valheim_raid_active",
      "1 while the latest raid is likely still on, from its start in the log; read the name label.",
      readRaidActiveSamples(game)
    ),
    ...formatGaugeLines(
      "valheim_boss_defeated",
      "1 for each defeated_* key in the latest save: the bosses, plus creatures the game also flags, like writhan.",
      readDefeatedBosses().map((boss) => ({ labels: { game, boss }, value: 1 }))
    ),
  ];
}

module.exports = { buildValheimMetricLines };
