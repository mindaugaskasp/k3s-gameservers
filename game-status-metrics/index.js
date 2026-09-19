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
// Set for games using backup-prune.sh (play-time archive windows).
const BACKUP_RECENT_DAYS = Number(process.env.BACKUP_RECENT_DAYS || 0);
const BACKUP_WINDOW_ENDS = (process.env.BACKUP_ARCHIVE_WINDOW_DAYS || "").split(" ").filter(Boolean).map(Number);

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

// Written by mod-guard.sh before the server starts. Absent = mods not in use.
function readModState() {
  try {
    const active = fs.readFileSync(`${STATUS_DIR}/mods-active`, "utf8").trim();
    let status = "";
    try {
      status = fs.readFileSync(`${STATUS_DIR}/mods-status`, "utf8").trim();
    } catch {
      status = "";
    }
    return { active: active === "1" ? 1 : 0, status };
  } catch {
    return null;
  }
}

// One file per online player, named after the character, written by the game's
// log hooks (games whose query protocol doesn't report names, e.g. Valheim).
const ONLINE_DIR = `${STATUS_DIR}/players/online`;

function readOnlinePlayers() {
  try {
    return fs.readdirSync(ONLINE_DIR).sort();
  } catch {
    return [];
  }
}

// The server says nobody is on, so any name still listed missed its disconnect line.
function clearOnlinePlayers() {
  for (const name of readOnlinePlayers()) {
    try {
      fs.unlinkSync(`${ONLINE_DIR}/${name}`);
    } catch {
      continue;
    }
  }
}

// Oldest first, so [0] is the next one the server's retention will delete.
// Per-file guard: retention may delete a backup between readdir and stat.
// Includes archive/, where tiered retention keeps older backups.
function readBackups() {
  const names = [];
  for (const sub of ["", "archive/"]) {
    try {
      names.push(...fs.readdirSync(`${BACKUP_DIR}/${sub}`).map((n) => sub + n));
    } catch {
      continue;
    }
  }
  const out = [];
  for (const name of names) {
    if (name.startsWith(".") || name.includes("/.")) continue; // e.g. .play-clock
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
    if (state.players.length === 0) clearOnlinePlayers();
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

// A raw newline in a label value corrupts the whole exposition, so a server
// name or failure reason containing one would break every metric.
function escapeLabel(s) {
  return String(s).replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\n/g, "\\n");
}

function renderMods(g) {
  const mods = readModState();
  if (!mods) return [];
  return [
    `# HELP game_server_mods_active Whether the server started with mods loaded (0 = fail-safe dropped them).`,
    `# TYPE game_server_mods_active gauge`,
    `game_server_mods_active{game="${g}"} ${mods.active}`,
    `# HELP game_server_mods_info Why mods are or are not loaded; read the reason label.`,
    `# TYPE game_server_mods_info gauge`,
    `game_server_mods_info{game="${g}",reason="${escapeLabel(mods.status)}"} 1`,
  ];
}

function renderOnlinePlayers(g) {
  const names = readOnlinePlayers();
  if (!names.length) return [];
  return [
    `# HELP game_server_player_online A player currently online, by character name, from the server log.`,
    `# TYPE game_server_player_online gauge`,
    ...names.map((n) => `game_server_player_online{game="${g}",name="${escapeLabel(n)}"} 1`),
  ];
}

// Mirrors backup-prune.sh: same index checks, same windows, so the dashboard
// shows what the next prune will do and whether it will run at all.
function readPlayClock(backups) {
  const known = new Map();
  let problem = "";
  try {
    for (const line of fs.readFileSync(`${BACKUP_DIR}/.play-clock`, "utf8").split("\n")) {
      if (!line) continue;
      const m = /^([^ ]+) ([0-9]+)$/.exec(line);
      if (!m) {
        problem = "unreadable line";
        break;
      }
      known.set(m[1], Number(m[2]));
    }
  } catch {
    problem = "missing";
  }
  const base = (b) => b.name.replace(/.*\//, "");
  const archived = backups.filter((b) => b.name.startsWith("archive/"));
  const unindexed = archived.find((b) => !known.has(base(b)));
  if (!problem && unindexed) problem = `no entry for ${base(unindexed)}`;
  if (problem && !archived.length) problem = ""; // prune rebuilds it while nothing is archived
  return { known, problem, base };
}

function windowFor(ageDays) {
  let lo = BACKUP_RECENT_DAYS;
  if (ageDays < lo) return "recent";
  for (const end of BACKUP_WINDOW_ENDS) {
    if (ageDays < end) return `${lo}-${end}`;
    lo = end;
  }
  return "expired";
}

function renderArchive(g, backups) {
  const { known, problem, base } = readPlayClock(backups);
  const newest = backups.length ? known.get(base(backups[backups.length - 1])) : undefined;
  const lines = [
    `# HELP game_server_backup_play_clock_ok 1 if backup-prune.sh's play-time index is usable; 0 means pruning is stopped.`,
    `# TYPE game_server_backup_play_clock_ok gauge`,
    `game_server_backup_play_clock_ok{game="${g}",problem="${escapeLabel(problem)}"} ${problem ? 0 : 1}`,
  ];
  if (newest !== undefined) {
    lines.push(
      `# HELP game_server_backup_play_clock_seconds Play time recorded up to the newest backup (idle gaps count at most a day).`,
      `# TYPE game_server_backup_play_clock_seconds gauge`,
      `game_server_backup_play_clock_seconds{game="${g}"} ${newest}`
    );
  }
  const windows = new Map(BACKUP_WINDOW_ENDS.map((end, i) => [`${i ? BACKUP_WINDOW_ENDS[i - 1] : BACKUP_RECENT_DAYS}-${end}`, 0]));
  const files = [];
  for (const b of backups) {
    const p = known.get(base(b));
    const ageDays = newest !== undefined && p !== undefined ? (newest - p) / 86400 : undefined;
    const win = ageDays === undefined ? "unindexed" : windowFor(ageDays);
    const end = win.includes("-") ? Number(win.split("-")[1]) : win === "recent" ? BACKUP_RECENT_DAYS : undefined;
    const day = /-game-day-([0-9]+)\.zip$/.exec(b.name);
    if (b.name.startsWith("archive/") && windows.has(win)) windows.set(win, windows.get(win) + 1);
    files.push({ b, ageDays, win, end, day: day ? Number(day[1]) : undefined });
  }
  const label = (f) => `game="${g}",file="${escapeLabel(`${BACKUP_DIR}/${f.b.name}`)}"`;
  lines.push(
    `# HELP game_server_backup_archive_window_files Archived backups per play-time window (days).`,
    `# TYPE game_server_backup_archive_window_files gauge`,
    ...[...windows].map(([w, n]) => `game_server_backup_archive_window_files{game="${g}",window="${w}"} ${n}`),
    `# HELP game_server_backup_file_info Where each backup sits: recent/archive, and its play-time window.`,
    `# TYPE game_server_backup_file_info gauge`,
    ...files.map((f) => `game_server_backup_file_info{${label(f)},location="${f.b.name.startsWith("archive/") ? "archive" : "recent"}",window="${f.win}"} 1`),
    `# HELP game_server_backup_file_game_day In-game day of the world in each backup (from its name).`,
    `# TYPE game_server_backup_file_game_day gauge`,
    ...files.filter((f) => f.day !== undefined).map((f) => `game_server_backup_file_game_day{${label(f)}} ${f.day}`),
    `# HELP game_server_backup_file_play_age_seconds Play time between each backup and the newest one.`,
    `# TYPE game_server_backup_file_play_age_seconds gauge`,
    ...files.filter((f) => f.ageDays !== undefined).map((f) => `game_server_backup_file_play_age_seconds{${label(f)}} ${Math.round(f.ageDays * 86400)}`),
    `# HELP game_server_backup_file_window_left_seconds Play time until each backup leaves its window (then archived, moved on or deleted).`,
    `# TYPE game_server_backup_file_window_left_seconds gauge`,
    ...files.filter((f) => f.end !== undefined).map((f) => `game_server_backup_file_window_left_seconds{${label(f)}} ${Math.round((f.end - f.ageDays) * 86400)}`)
  );
  // Touched by player-event.sh / backup-gate.sh on any player activity.
  try {
    const t = Math.floor(fs.statSync(`${STATUS_DIR}/players/last-activity`).mtimeMs / 1000);
    lines.push(
      `# HELP game_server_last_player_activity_timestamp_seconds Last join/leave/online-check that saw a player.`,
      `# TYPE game_server_last_player_activity_timestamp_seconds gauge`,
      `game_server_last_player_activity_timestamp_seconds{game="${g}"} ${t}`
    );
  } catch {
    // no activity since the pod started
  }
  return lines;
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
      ...backups.map((b) => `game_server_backup_file_timestamp_seconds{game="${g}",file="${escapeLabel(`${BACKUP_DIR}/${b.name}`)}"} ${b.mtime}`),
      `# HELP game_server_backup_file_bytes Size of each backup archive.`,
      `# TYPE game_server_backup_file_bytes gauge`,
      ...backups.map((b) => `game_server_backup_file_bytes{game="${g}",file="${escapeLabel(`${BACKUP_DIR}/${b.name}`)}"} ${b.bytes}`)
    );
  }
  if (BACKUP_WINDOW_ENDS.length) lines.push(...renderArchive(g, backups));
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
    ...renderOnlinePlayers(g),
    ...renderMods(g),
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
