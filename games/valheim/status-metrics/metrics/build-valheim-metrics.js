"use strict";

const { GAME } = require("../../../../game-server/status-metrics/config");
const { formatGaugeLines } = require("../../../../game-server/status-metrics/format-metric-lines");
const { readModState } = require("../read-valheim-status-files");
const { readWorldModifiers } = require("../read-world-modifiers");
const { readRaidCount, readLatestRaid, readRecentRaids } = require("../store-raids");
const { readDefeatedBosses } = require("../read-defeated-bosses");
const { readLastDeath } = require("../../../../game-server/status-metrics/store-player-history");
const { readBackups } = require("../../../../game-server/status-metrics/read-backups");
const { buildBackupArchiveMetricLines } = require("./build-backup-archive-metrics");
const { BACKUP_WINDOW_ENDS } = require("../config");

// The log marks only a raid's start. The longest lasts 150s, longer while nobody is near:
// https://valheim.weirdgloop.org/w/Events
const RAID_LIKELY_ACTIVE_SECONDS = 150;
// Enough history for the website's raid list; each raid is its own series, so it stays short.
const RECENT_RAIDS_REPORTED = 10;

function readRaidActiveSamples(game) {
  const raid = readLatestRaid();
  if (!raid) return [];
  const isActive = Math.floor(Date.now() / 1000) - raid.startedAt < RAID_LIKELY_ACTIVE_SECONDS;

  return [{ labels: { game, name: raid.eventId }, value: isActive ? 1 : 0 }];
}

// raid_id keeps two raids of the same event apart.
function readRecentRaidSamples(game) {
  return readRecentRaids(RECENT_RAIDS_REPORTED).map((raid) => ({
    labels: { game, name: raid.eventId, raid_id: raid.id },
    value: raid.startedAt,
  }));
}

function readLastDeathGameDaySamples(game) {
  const lastDeath = readLastDeath();
  if (lastDeath?.last_death_game_day == null) return [];

  return [{ labels: { game, name: lastDeath.name }, value: lastDeath.last_death_game_day }];
}

// valheim_* metrics hold what only Valheim reports: mod state from mod-guard.sh, world rules, raids,
// bosses, the day of the last death and the backup archive. The prefix is written out, never built
// from GAME, so every metric name stays greppable.
function buildValheimMetricLines() {
  const game = GAME;
  const mods = readModState();
  const raidCount = readRaidCount();
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
      "valheim_raid_started_timestamp_seconds",
      `When each of the latest ${RECENT_RAIDS_REPORTED} raids started, in unix seconds; read the name label.`,
      readRecentRaidSamples(game)
    ),
    ...formatGaugeLines(
      "valheim_last_death_game_day",
      "The in-game day of the most recent death on this server; read name for the player.",
      readLastDeathGameDaySamples(game)
    ),
    ...formatGaugeLines(
      "valheim_boss_defeated",
      "1 for each defeated_* key in the latest save: the bosses, plus creatures the game also flags, like writhan.",
      readDefeatedBosses().map((boss) => ({ labels: { game, boss }, value: 1 }))
    ),
    ...(BACKUP_WINDOW_ENDS.length ? buildBackupArchiveMetricLines(readBackups()) : []),
  ];
}

module.exports = { buildValheimMetricLines };
