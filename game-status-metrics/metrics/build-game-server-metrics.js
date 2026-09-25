"use strict";

const { GAME } = require("../config");
const { formatGaugeLines } = require("../format-metric-lines");
const {
  readStatusTimestamp,
  readBuildId,
  readPastSessionsUptimeSeconds,
} = require("../read-status-files");
const { readPlayTimeTotals, readDeathCounts, readLastDeath, readPlayersSeen } = require("../store-player-history");
const { readOnlinePlayerSessions } = require("../track-online-players");
const { readOnlineAdminNames } = require("../read-online-admins");

// Only counts while the server answers: a session that ended is already in the baseline.
function readCurrentSessionSeconds(isServerUp) {
  const startedAt = readStatusTimestamp("last-started.timestamp");
  if (!isServerUp || !startedAt) return 0;
  return Math.max(0, Math.floor(Date.now() / 1000) - startedAt);
}

// The log's online list names players where the query reports none (Valheim, Enshrouded);
// without one, the query's own sessions stand, placeholder names and all.
function readPlayerSessions(status) {
  const now = Math.floor(Date.now() / 1000);
  const sessionsFromLog = readOnlinePlayerSessions().map((player) => ({
    name: player.name,
    seconds: Math.max(0, now - player.startedAt),
  }));

  return sessionsFromLog.length ? sessionsFromLog : status.playerSessions;
}

function readLastDeathSamples(game) {
  const lastDeath = readLastDeath();

  if (!lastDeath) return [];
  const characterLabel = lastDeath.characterName ? { character: lastDeath.characterName } : {};

  return [{ labels: { game, name: lastDeath.name, ...characterLabel }, value: lastDeath.diedAt }];
}

/** What every game reports, told apart by the `game` label. */
function buildGameServerMetricLines(status) {
  const game = GAME;
  const sampleForGame = (value) => [{ labels: { game }, value }];
  const sessionSeconds = readCurrentSessionSeconds(status.up);
  const playerSessions = readPlayerSessions(status);
  return [
    ...formatGaugeLines("game_server_up", "Whether the last gamedig query against this instance succeeded.", sampleForGame(status.up)),
    ...formatGaugeLines("game_server_players", "Current player count.", sampleForGame(status.players)),
    ...formatGaugeLines("game_server_players_max", "Configured max player count.", sampleForGame(status.maxplayers)),
    ...formatGaugeLines("game_server_query_duration_seconds", "Duration of the last gamedig query.", sampleForGame(status.queryDurationSeconds)),
    ...formatGaugeLines("game_server_last_scrape_timestamp_seconds", "Unix time of the last scrape attempt.", sampleForGame(status.scrapeUnixTime)),
    ...formatGaugeLines("game_server_ping_seconds", "Protocol-level round-trip time to the query port.", sampleForGame(status.pingSeconds)),
    ...formatGaugeLines("game_server_info", "Static server info (value always 1); read the labels.", [
      {
        labels: {
          game,
          name: status.serverName,
          version: status.version,
          build: readBuildId(),
          password: status.password,
        },
        value: 1,
      },
    ]),
    ...formatGaugeLines(
      "game_server_last_started_timestamp_seconds",
      "Unix time the gameserver process last (re)started, from its lifecycle hook.",
      sampleForGame(readStatusTimestamp("last-started.timestamp"))
    ),
    ...formatGaugeLines(
      "game_server_last_updated_timestamp_seconds",
      "Unix time the gameserver was last updated to a new version, from its lifecycle hook.",
      sampleForGame(readStatusTimestamp("last-updated.timestamp"))
    ),
    ...formatGaugeLines(
      "game_server_uptime_current_seconds",
      "How long the current session has been running -- resets to ~0 on every restart.",
      sampleForGame(sessionSeconds)
    ),
    ...formatGaugeLines(
      "game_server_uptime_total_seconds",
      "Total time the server has been up across its whole lifetime, unaffected by restarts/updates.",
      sampleForGame(readPastSessionsUptimeSeconds() + sessionSeconds)
    ),
    ...formatGaugeLines(
      "game_server_player_session_seconds",
      "How long a player online now has been connected; named from the game's log where the query reports no names.",
      playerSessions.map((player) => ({ labels: { game, name: player.name }, value: player.seconds }))
    ),
    ...formatGaugeLines(
      "game_server_player_admin",
      "1 for an online player on the server's admin list, matched by platform ID, not name.",
      readOnlineAdminNames(playerSessions.map((player) => player.name)).map((name) => ({ labels: { game, name }, value: 1 }))
    ),
    ...formatGaugeLines(
      "game_server_player_play_time_seconds",
      "Total time a player has spent online, across every session the exporter has seen.",
      readPlayTimeTotals().map((player) => ({ labels: { game, name: player.name }, value: player.seconds }))
    ),
    ...formatGaugeLines(
      "game_server_player_last_seen_timestamp_seconds",
      "Unix time a player was last seen online.",
      readPlayersSeen().map((player) => ({ labels: { game, name: player.name }, value: player.at }))
    ),
    ...formatGaugeLines(
      "game_server_player_deaths",
      "How many times a player has died on this server, counted from the server log.",
      readDeathCounts().map((player) => ({ labels: { game, name: player.name }, value: player.count }))
    ),
    ...formatGaugeLines(
      "game_server_last_death_timestamp_seconds",
      "Unix time of the most recent death on this server; read name for the player, character for who they played.",
      readLastDeathSamples(game)
    ),
  ];
}

module.exports = { buildGameServerMetricLines };
