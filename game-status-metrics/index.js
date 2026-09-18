"use strict";

const http = require("http");
const fs = require("fs");
const { GameDig } = require("gamedig");

const GAME = process.env.GAMEDIG_GAME;
const HOST = process.env.QUERY_HOST || "127.0.0.1";
const PORT = Number(process.env.QUERY_PORT);
const METRICS_PORT = Number(process.env.METRICS_PORT || 9101);
const STATUS_DIR = process.env.STATUS_DIR || "/var/run/valheim-status";
const PERSIST_DIR = process.env.PERSIST_DIR || "/config"; // PVC-backed, survives restarts (unlike STATUS_DIR)
const BACKUP_DIR = process.env.BACKUP_DIR || "/config/backups";
const BACKUP_MAX_AGE_DAYS = Number(process.env.BACKUP_MAX_AGE_DAYS || 0);
const BACKUP_MAX_COUNT = Number(process.env.BACKUP_MAX_COUNT || 0);

// Written by the gameserver's lifecycle hooks; gamedig has no notion of
// "when did the process last (re)start".
function readTimestampFile(name) {
  try {
    return parseInt(fs.readFileSync(`${STATUS_DIR}/${name}`, "utf8").trim(), 10) || 0;
  } catch {
    return 0;
  }
}

// Written by the "started" hook; not exposed via gamedig/A2S at all.
function readBuildId() {
  try {
    return fs.readFileSync(`${STATUS_DIR}/build-id`, "utf8").trim();
  } catch {
    return "";
  }
}

// Sum of past sessions, written by the "down" hook. Needed because
// Prometheus only retains 7d and so cannot answer lifetime uptime.
function readUptimeBaseline() {
  try {
    return parseInt(fs.readFileSync(`${PERSIST_DIR}/uptime-accumulator.seconds`, "utf8").trim(), 10) || 0;
  } catch {
    return 0;
  }
}

// Oldest first, so [0] is the next one the server's retention will delete.
// Per-file guard: retention may delete a backup between readdir and stat.
function readBackups() {
  let names;
  try {
    names = fs.readdirSync(BACKUP_DIR);
  } catch {
    return [];
  }
  const out = [];
  for (const name of names) {
    try {
      const st = fs.statSync(`${BACKUP_DIR}/${name}`);
      if (st.isFile()) out.push({ name, bytes: st.size, mtime: Math.floor(st.mtimeMs / 1000) });
    } catch {
      continue;
    }
  }
  return out.sort((a, b) => a.mtime - b.mtime);
}

function currentSessionSeconds() {
  const startedAt = readTimestampFile("last-started.timestamp");
  if (!last.up || !startedAt) return 0;
  return Math.max(0, Math.floor(Date.now() / 1000) - startedAt);
}

// The real game version rides in the A2S tags as "g=1.0.14"; gamedig's own
// `version` field is the query protocol version, always "1.0.0.0".
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

function renderBackups(g) {
  const backups = readBackups();
  const totalBytes = backups.reduce((n, b) => n + b.bytes, 0);
  const oldest = backups[0];
  const lines = [
    `# HELP game_server_backup_count Number of backup archives currently on disk.`,
    `# TYPE game_server_backup_count gauge`,
    `game_server_backup_count{game="${g}"} ${backups.length}`,
    `# HELP game_server_backup_bytes Total disk space used by backup archives.`,
    `# TYPE game_server_backup_bytes gauge`,
    `game_server_backup_bytes{game="${g}"} ${totalBytes}`,
    `# HELP game_server_backup_retention_days Configured age at which a backup is deleted (0 = no age limit).`,
    `# TYPE game_server_backup_retention_days gauge`,
    `game_server_backup_retention_days{game="${g}"} ${BACKUP_MAX_AGE_DAYS}`,
    `# HELP game_server_backup_retention_count Configured max number of backups kept (0 = no count limit).`,
    `# TYPE game_server_backup_retention_count gauge`,
    `game_server_backup_retention_count{game="${g}"} ${BACKUP_MAX_COUNT}`,
  ];
  if (oldest) {
    lines.push(
      `# HELP game_server_backup_oldest_timestamp_seconds Modification time of the oldest backup.`,
      `# TYPE game_server_backup_oldest_timestamp_seconds gauge`,
      `game_server_backup_oldest_timestamp_seconds{game="${g}"} ${oldest.mtime}`,
      `# HELP game_server_backup_newest_timestamp_seconds Modification time of the newest backup.`,
      `# TYPE game_server_backup_newest_timestamp_seconds gauge`,
      `game_server_backup_newest_timestamp_seconds{game="${g}"} ${backups[backups.length - 1].mtime}`
    );
    if (BACKUP_MAX_AGE_DAYS > 0) {
      lines.push(
        `# HELP game_server_backup_oldest_expiry_timestamp_seconds When the oldest backup becomes eligible for deletion.`,
        `# TYPE game_server_backup_oldest_expiry_timestamp_seconds gauge`,
        `game_server_backup_oldest_expiry_timestamp_seconds{game="${g}"} ${oldest.mtime + BACKUP_MAX_AGE_DAYS * 86400}`
      );
    }
  }
  if (backups.length) {
    lines.push(
      `# HELP game_server_backup_file_timestamp_seconds Modification time of each backup archive.`,
      `# TYPE game_server_backup_file_timestamp_seconds gauge`,
      ...backups.map((b) => `game_server_backup_file_timestamp_seconds{game="${g}",file="${escapeLabel(b.name)}"} ${b.mtime}`),
      `# HELP game_server_backup_file_bytes Size of each backup archive.`,
      `# TYPE game_server_backup_file_bytes gauge`,
      ...backups.map((b) => `game_server_backup_file_bytes{game="${g}",file="${escapeLabel(b.name)}"} ${b.bytes}`)
    );
  }
  return lines;
}

function render() {
  const g = GAME;
  const playerLines = last.playerSessions.length
    ? [
        `# HELP game_server_player_session_seconds Session duration of a currently-connected player (name is a placeholder if the game's query protocol doesn't report one, e.g. Valheim).`,
        `# TYPE game_server_player_session_seconds gauge`,
        ...last.playerSessions.map(
          (p) => `game_server_player_session_seconds{game="${g}",name="${escapeLabel(p.name)}"} ${p.seconds}`
        ),
      ]
    : [];
  return [
    `# HELP game_server_up Whether the last gamedig query against this instance succeeded.`,
    `# TYPE game_server_up gauge`,
    `game_server_up{game="${g}"} ${last.up}`,
    `# HELP game_server_players Current player count.`,
    `# TYPE game_server_players gauge`,
    `game_server_players{game="${g}"} ${last.players}`,
    `# HELP game_server_players_max Configured max player count.`,
    `# TYPE game_server_players_max gauge`,
    `game_server_players_max{game="${g}"} ${last.maxplayers}`,
    `# HELP game_server_query_duration_seconds Duration of the last gamedig query.`,
    `# TYPE game_server_query_duration_seconds gauge`,
    `game_server_query_duration_seconds{game="${g}"} ${last.queryDurationSeconds}`,
    `# HELP game_server_last_scrape_timestamp_seconds Unix time of the last scrape attempt.`,
    `# TYPE game_server_last_scrape_timestamp_seconds gauge`,
    `game_server_last_scrape_timestamp_seconds{game="${g}"} ${last.scrapeUnixTime}`,
    `# HELP game_server_ping_seconds Protocol-level round-trip time to the query port.`,
    `# TYPE game_server_ping_seconds gauge`,
    `game_server_ping_seconds{game="${g}"} ${last.pingSeconds}`,
    `# HELP game_server_info Static server info (value always 1); read the labels.`,
    `# TYPE game_server_info gauge`,
    `game_server_info{game="${g}",name="${escapeLabel(last.serverName)}",version="${escapeLabel(last.version)}",build="${escapeLabel(readBuildId())}",password="${last.password}"} 1`,
    `# HELP game_server_last_started_timestamp_seconds Unix time the gameserver process last (re)started, from its lifecycle hook.`,
    `# TYPE game_server_last_started_timestamp_seconds gauge`,
    `game_server_last_started_timestamp_seconds{game="${g}"} ${readTimestampFile("last-started.timestamp")}`,
    `# HELP game_server_last_updated_timestamp_seconds Unix time the gameserver was last updated to a new version, from its lifecycle hook.`,
    `# TYPE game_server_last_updated_timestamp_seconds gauge`,
    `game_server_last_updated_timestamp_seconds{game="${g}"} ${readTimestampFile("last-updated.timestamp")}`,
    `# HELP game_server_uptime_current_seconds How long the current session has been running -- resets to ~0 on every restart.`,
    `# TYPE game_server_uptime_current_seconds gauge`,
    `game_server_uptime_current_seconds{game="${g}"} ${currentSessionSeconds()}`,
    `# HELP game_server_uptime_total_seconds Total time the server has been up across its whole lifetime, unaffected by restarts/updates.`,
    `# TYPE game_server_uptime_total_seconds gauge`,
    `game_server_uptime_total_seconds{game="${g}"} ${readUptimeBaseline() + currentSessionSeconds()}`,
    ...playerLines,
    ...renderBackups(g),
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
server.listen(METRICS_PORT, () => {
  console.log(`game-status-metrics listening on :${METRICS_PORT}, querying ${GAME} at ${HOST}:${PORT}`);
});
