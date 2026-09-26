"use strict";

const { GameDig } = require("gamedig");
const { GAME, HOST, PORT } = require("./config");
const { readOnlinePlayers, clearOnlinePlayers } = require("./track-online-players");
const { recordPlayersSeen, creditPlayTime } = require("./store-player-history");

// The real game version rides in the A2S tags as "g=1.0.14"; gamedig's own
// `version` field is the query protocol version, always "1.0.0.0".
function parseGameVersion(state) {
  const versionTag = (state.raw?.tags || []).find((tag) => tag.startsWith("g="));
  return versionTag ? versionTag.slice(2) : state.version || "";
}

/** Queries the game server on demand and keeps the last answer for the next scrape. */
class GameServerQuery {
  constructor(gamePlugin) {
    this.gamePlugin = gamePlugin;
    this.lastStatus = {
      up: 0,
      players: 0,
      maxplayers: 0,
      playerSessions: [], // [{name, seconds}] -- some query protocols report
      queryDurationSeconds: 0, // only the session duration, never the name
      pingSeconds: 0, // protocol-level round-trip time, not queryDurationSeconds
      serverName: "",
      version: "",
      password: false,
      scrapeUnixTime: 0,
    };
  }

  async refreshLastStatus() {
    // What the logs say happened, whether or not the query answers.
    this.gamePlugin.recordNewLogEvents();
    const queryStartedAt = Date.now();
    try {
      const state = await GameDig.query({ type: GAME, host: HOST, port: PORT, maxRetries: 1 });
      if (state.players.length === 0) clearOnlinePlayers();
      // The log hooks and the query protocol each know names the other doesn't.
      const onlinePlayerNames = [
        ...new Set([...readOnlinePlayers(), ...state.players.map((player) => player.name).filter(Boolean)]),
      ];
      recordPlayersSeen(onlinePlayerNames);
      creditPlayTime(onlinePlayerNames);
      this.gamePlugin.recordQueriedPlayers(state.players);
      this.lastStatus = {
        up: 1,
        players: state.players.length,
        maxplayers: state.maxplayers || 0,
        playerSessions: state.players.map((player, index) => ({
          name: player.name || `player${index}`,
          seconds: player.raw?.time ?? 0,
        })),
        queryDurationSeconds: (Date.now() - queryStartedAt) / 1000,
        pingSeconds: (state.ping ?? 0) / 1000,
        serverName: state.name || "",
        version: parseGameVersion(state),
        password: Boolean(state.password),
        scrapeUnixTime: Math.floor(Date.now() / 1000),
      };
    } catch {
      this.lastStatus = {
        up: 0,
        players: 0,
        maxplayers: this.lastStatus.maxplayers,
        playerSessions: [],
        queryDurationSeconds: (Date.now() - queryStartedAt) / 1000,
        pingSeconds: 0,
        serverName: this.lastStatus.serverName,
        version: this.lastStatus.version,
        password: this.lastStatus.password,
        scrapeUnixTime: Math.floor(Date.now() / 1000),
      };
    }
  }
}

module.exports = { GameServerQuery };
