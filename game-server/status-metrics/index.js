"use strict";

const http = require("http");
const { GAME, HOST, PORT, METRICS_PORT } = require("./config");
const { GameServerQuery } = require("./query-game-server");
const { buildMetricsText } = require("./build-metrics-text");
const { loadGamePlugin } = require("./load-game-plugin");

const QUERY_INTERVAL_MILLISECONDS = 15000;

if (!GAME || !PORT) {
  console.error("GAMEDIG_GAME and QUERY_PORT env vars are required");
  process.exit(1);
}

const gamePlugin = loadGamePlugin();
const query = new GameServerQuery(gamePlugin);

const server = http.createServer((req, res) => {
  if (req.url === "/metrics") {
    res.writeHead(200, { "Content-Type": "text/plain; version=0.0.4" });
    res.end(buildMetricsText(query.lastStatus, gamePlugin));
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

query.refreshLastStatus();
setInterval(() => query.refreshLastStatus(), QUERY_INTERVAL_MILLISECONDS);
server.listen(METRICS_PORT, () => {
  console.log(`game-status-metrics listening on :${METRICS_PORT}, querying ${GAME} at ${HOST}:${PORT}`);
});
