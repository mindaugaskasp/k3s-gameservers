"use strict";

const { GAME } = require("../config");
const { gaugeLines } = require("../metric-lines");
const { readOnlinePlayers, readOnlinePlayerSessions, readPlayersSeen } = require("../player-files");
const { readModState } = require("../status-files");
const { readWorldModifiers } = require("../world-modifiers");

// valheim_* metrics come from hooks only the Valheim chart installs (player-event.sh,
// mod-guard.sh, backup-rename.sh). The prefix is written out, never built from GAME, so
// every metric name stays greppable.
function valheimMetricLines() {
  const game = GAME;
  const mods = readModState();
  return [
    ...gaugeLines(
      "valheim_player_online",
      "A player currently online, by character name, from the server log.",
      readOnlinePlayers().map((name) => ({ labels: { game, name }, value: 1 }))
    ),
    ...gaugeLines(
      "valheim_player_session_seconds",
      "How long a player currently online has been connected, by character name.",
      readOnlinePlayerSessions().map((player) => ({
        labels: { game, name: player.name },
        value: Math.max(0, Math.floor(Date.now() / 1000) - player.startedAt),
      }))
    ),
    ...gaugeLines(
      "valheim_player_last_seen_timestamp_seconds",
      "Unix time a player was last seen online.",
      readPlayersSeen().map((player) => ({ labels: { game, name: player.name }, value: player.at }))
    ),
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
