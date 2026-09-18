"use strict";

const http = require("http");
const fs = require("fs");
const { GameDig } = require("gamedig");

const GAME = process.env.GAMEDIG_GAME;
const HOST = process.env.QUERY_HOST || "127.0.0.1";
const PORT = Number(process.env.QUERY_PORT);
const EXPORTER_PORT = Number(process.env.EXPORTER_PORT || 9101);
const STATUS_DIR = process.env.STATUS_DIR || "/var/run/valheim-status";
const PERSIST_DIR = process.env.PERSIST_DIR || "/config"; // PVC-backed, survives restarts (unlike STATUS_DIR)

// Written by the gameserver's lifecycle hooks (shared emptyDir volume) --
// gamedig has no notion of "when did the process last (re)start".
function readTimestampFile(name) {
  try {
    return parseInt(fs.readFileSync(`${STATUS_DIR}/${name}`, "utf8").trim(), 10) || 0;
  } catch {
    return 0;
  }
}

// Steam build ID, written by the "started" hook from the app manifest --
// not exposed via gamedig/A2S at all, only readable from inside the
// gameserver container's own install.
function readBuildId() {
  try {
    return fs.readFileSync(`${STATUS_DIR}/build-id`, "utf8").trim();
  } catch {
    return "";
  }
}

// Sum of every past completed session's duration, written by the "down"
// hook -- PERSIST_DIR is PVC-backed so this survives pod restarts, unlike
// STATUS_DIR (an emptyDir). Prometheus's own history can't answer "total
// lifetime uptime" since it only retains 7 days.
function readUptimeBaseline() {
  try {
    return parseInt(fs.readFileSync(`${PERSIST_DIR}/uptime-accumulator.seconds`, "utf8").trim(), 10) || 0;
  } catch {
    return 0;
  }
}

function currentSessionSeconds() {
  const startedAt = readTimestampFile("last-started.timestamp");
  if (!last.up || !startedAt) return 0;
  return Math.max(0, Math.floor(Date.now() / 1000) - startedAt);
}

// Valheim's A2S "keywords"/tags carry the real game version as "g=1.0.14";
// gamedig's own `version` field is just the query protocol version, always "1.0.0.0".
function parseGameVersion(state) {
  const tag = (state.raw?.tags || []).find((t) => t.startsWith("g="));
  return tag ? tag.slice(2) : state.version || "";
}

if (!GAME || !PORT) {
  console.error("GAMEDIG_GAME and QUERY_PORT env vars are required");
  process.exit(1);
}

let last = {
  up: 0,
  players: 0,
  maxplayers: 0,
  playerSessions: [], // [{name, seconds}] -- Valheim's query protocol never
  queryDurationSeconds: 0, // reports player name, only session duration
  pingSeconds: 0, // protocol-level RTT, distinct from queryDurationSeconds
  serverName: "",
  version: "",
  password: false,
  scrapeUnixTime: 0,
};

async function scrape() {
  const start = Date.now();
  try {
    const state = await GameDig.query({ type: GAME, host: HOST, port: PORT, maxRetries: 1 });
    last = {
      up: 1,
      players: state.players.length,
      maxplayers: state.maxplayers || 0,
      playerSessions: state.players.map((p, i) => ({
        name: p.name || `player${i}`,
        seconds: p.raw?.time ?? 0,
      })),
      queryDurationSeconds: (Date.now() - start) / 1000,
      pingSeconds: (state.ping ?? 0) / 1000,
      serverName: state.name || "",
      version: parseGameVersion(state),
      password: Boolean(state.password),
      scrapeUnixTime: Math.floor(Date.now() / 1000),
    };
  } catch (err) {
    last = {
      up: 0,
      players: 0,
      maxplayers: last.maxplayers,
      playerSessions: [],
      queryDurationSeconds: (Date.now() - start) / 1000,
      pingSeconds: 0,
      serverName: last.serverName,
      version: last.version,
      password: last.password,
      scrapeUnixTime: Math.floor(Date.now() / 1000),
    };
  }
}

function escapeLabel(s) {
  return s.replace(/\\/g, "\\\\").replace(/"/g, '\\"');
}

function render() {
  const g = GAME;
  const playerLines = last.playerSessions.length
    ? [
        `# HELP lgsm_game_player_session_seconds Session duration of a currently-connected player (name is a placeholder if the game's query protocol doesn't report one, e.g. Valheim).`,
        `# TYPE lgsm_game_player_session_seconds gauge`,
        ...last.playerSessions.map(
          (p) => `lgsm_game_player_session_seconds{game="${g}",name="${escapeLabel(p.name)}"} ${p.seconds}`
        ),
      ]
    : [];
  return [
    `# HELP lgsm_game_up Whether the last gamedig query against this instance succeeded.`,
    `# TYPE lgsm_game_up gauge`,
    `lgsm_game_up{game="${g}"} ${last.up}`,
    `# HELP lgsm_game_players Current player count.`,
    `# TYPE lgsm_game_players gauge`,
    `lgsm_game_players{game="${g}"} ${last.players}`,
    `# HELP lgsm_game_players_max Configured max player count.`,
    `# TYPE lgsm_game_players_max gauge`,
    `lgsm_game_players_max{game="${g}"} ${last.maxplayers}`,
    `# HELP lgsm_game_query_duration_seconds Duration of the last gamedig query.`,
    `# TYPE lgsm_game_query_duration_seconds gauge`,
    `lgsm_game_query_duration_seconds{game="${g}"} ${last.queryDurationSeconds}`,
    `# HELP lgsm_game_last_scrape_timestamp_seconds Unix time of the last scrape attempt.`,
    `# TYPE lgsm_game_last_scrape_timestamp_seconds gauge`,
    `lgsm_game_last_scrape_timestamp_seconds{game="${g}"} ${last.scrapeUnixTime}`,
    `# HELP lgsm_game_ping_seconds Protocol-level round-trip time to the query port.`,
    `# TYPE lgsm_game_ping_seconds gauge`,
    `lgsm_game_ping_seconds{game="${g}"} ${last.pingSeconds}`,
    `# HELP lgsm_game_info Static server info (value always 1); read the labels.`,
    `# TYPE lgsm_game_info gauge`,
    `lgsm_game_info{game="${g}",name="${escapeLabel(last.serverName)}",version="${escapeLabel(last.version)}",build="${escapeLabel(readBuildId())}",password="${last.password}"} 1`,
    `# HELP lgsm_game_last_started_timestamp_seconds Unix time the gameserver process last (re)started, from its lifecycle hook.`,
    `# TYPE lgsm_game_last_started_timestamp_seconds gauge`,
    `lgsm_game_last_started_timestamp_seconds{game="${g}"} ${readTimestampFile("last-started.timestamp")}`,
    `# HELP lgsm_game_last_updated_timestamp_seconds Unix time the gameserver was last updated to a new version, from its lifecycle hook.`,
    `# TYPE lgsm_game_last_updated_timestamp_seconds gauge`,
    `lgsm_game_last_updated_timestamp_seconds{game="${g}"} ${readTimestampFile("last-updated.timestamp")}`,
    `# HELP lgsm_game_uptime_current_seconds How long the current session has been running -- resets to ~0 on every restart.`,
    `# TYPE lgsm_game_uptime_current_seconds gauge`,
    `lgsm_game_uptime_current_seconds{game="${g}"} ${currentSessionSeconds()}`,
    `# HELP lgsm_game_uptime_total_seconds Total time the server has been up across its whole lifetime, unaffected by restarts/updates.`,
    `# TYPE lgsm_game_uptime_total_seconds gauge`,
    `lgsm_game_uptime_total_seconds{game="${g}"} ${readUptimeBaseline() + currentSessionSeconds()}`,
    ...playerLines,
    "",
  ].join("\n");
}

const server = http.createServer((req, res) => {
  if (req.url === "/metrics") {
    res.writeHead(200, { "Content-Type": "text/plain; version=0.0.4" });
    res.end(render());
    return;
  }
  if (req.url === "/healthz") {
    res.writeHead(200);
    res.end("ok");
    return;
  }
  res.writeHead(404);
  res.end();
});

scrape();
setInterval(scrape, 15000);
server.listen(EXPORTER_PORT, () => {
  console.log(`lgsm-exporter listening on :${EXPORTER_PORT}, querying ${GAME} at ${HOST}:${PORT}`);
});
