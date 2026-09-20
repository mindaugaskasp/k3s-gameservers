"use strict";

const { GAME } = require("../config");
const { gaugeLines } = require("../metric-lines");
const {
  readStatusTimestamp,
  readBuildId,
  readPastSessionsUptimeSeconds,
} = require("../status-files");
const { readPlayTimeTotals } = require("../player-play-time");

// Only counts while the server answers: a session that ended is already in the baseline.
function currentSessionSeconds(isServerUp) {
  const startedAt = readStatusTimestamp("last-started.timestamp");
  if (!isServerUp || !startedAt) return 0;
  return Math.max(0, Math.floor(Date.now() / 1000) - startedAt);
}

/** What every game reports, told apart by the `game` label. */
function gameServerMetricLines(status) {
  const game = GAME;
  const sampleForGame = (value) => [{ labels: { game }, value }];
  const sessionSeconds = currentSessionSeconds(status.up);
  return [
    ...gaugeLines("game_server_up", "Whether the last gamedig query against this instance succeeded.", sampleForGame(status.up)),
    ...gaugeLines("game_server_players", "Current player count.", sampleForGame(status.players)),
    ...gaugeLines("game_server_players_max", "Configured max player count.", sampleForGame(status.maxplayers)),
    ...gaugeLines("game_server_query_duration_seconds", "Duration of the last gamedig query.", sampleForGame(status.queryDurationSeconds)),
    ...gaugeLines("game_server_last_scrape_timestamp_seconds", "Unix time of the last scrape attempt.", sampleForGame(status.scrapeUnixTime)),
    ...gaugeLines("game_server_ping_seconds", "Protocol-level round-trip time to the query port.", sampleForGame(status.pingSeconds)),
    ...gaugeLines("game_server_info", "Static server info (value always 1); read the labels.", [
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
    ...gaugeLines(
      "game_server_last_started_timestamp_seconds",
      "Unix time the gameserver process last (re)started, from its lifecycle hook.",
      sampleForGame(readStatusTimestamp("last-started.timestamp"))
    ),
    ...gaugeLines(
      "game_server_last_updated_timestamp_seconds",
      "Unix time the gameserver was last updated to a new version, from its lifecycle hook.",
      sampleForGame(readStatusTimestamp("last-updated.timestamp"))
    ),
    ...gaugeLines(
      "game_server_uptime_current_seconds",
      "How long the current session has been running -- resets to ~0 on every restart.",
      sampleForGame(sessionSeconds)
    ),
    ...gaugeLines(
      "game_server_uptime_total_seconds",
      "Total time the server has been up across its whole lifetime, unaffected by restarts/updates.",
      sampleForGame(readPastSessionsUptimeSeconds() + sessionSeconds)
    ),
    ...gaugeLines(
      "game_server_player_session_seconds",
      "Session duration of a currently-connected player (name is a placeholder if the game's query protocol doesn't report one, e.g. Valheim).",
      status.playerSessions.map((player) => ({ labels: { game, name: player.name }, value: player.seconds }))
    ),
    ...gaugeLines(
      "game_server_player_play_time_seconds",
      "Total time a player has spent online, across every session the exporter has seen.",
      readPlayTimeTotals().map((player) => ({ labels: { game, name: player.name }, value: player.seconds }))
    ),
  ];
}

module.exports = { gameServerMetricLines };
