"use strict";

const http = require("http");
const { GameDig } = require("gamedig");

const GAME = process.env.GAMEDIG_GAME;
const HOST = process.env.QUERY_HOST || "127.0.0.1";
const PORT = Number(process.env.QUERY_PORT);
const EXPORTER_PORT = Number(process.env.EXPORTER_PORT || 9101);

if (!GAME || !PORT) {
  console.error("GAMEDIG_GAME and QUERY_PORT env vars are required");
  process.exit(1);
}

let last = {
  up: 0,
  players: 0,
  maxplayers: 0,
  playerNames: [],
  queryDurationSeconds: 0,
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
      playerNames: state.players.map((p) => p.name).filter(Boolean),
      queryDurationSeconds: (Date.now() - start) / 1000,
      scrapeUnixTime: Math.floor(Date.now() / 1000),
    };
  } catch (err) {
    last = {
      up: 0,
      players: 0,
      maxplayers: last.maxplayers,
      playerNames: [],
      queryDurationSeconds: (Date.now() - start) / 1000,
      scrapeUnixTime: Math.floor(Date.now() / 1000),
    };
  }
}

function escapeLabel(s) {
  return s.replace(/\\/g, "\\\\").replace(/"/g, '\\"');
}

function render() {
  const g = GAME;
  const playerLines = last.playerNames.length
    ? [
        `# HELP lgsm_game_player_online A currently-connected player (value always 1).`,
        `# TYPE lgsm_game_player_online gauge`,
        ...last.playerNames.map(
          (name) => `lgsm_game_player_online{game="${g}",name="${escapeLabel(name)}"} 1`
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
