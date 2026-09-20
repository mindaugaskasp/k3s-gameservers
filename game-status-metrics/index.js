"use strict";

const http = require("http");
const { GAME, HOST, PORT, METRICS_PORT } = require("./config");
const { GameServerQuery } = require("./game-server-query");
const { metricsText } = require("./metrics-text");

const QUERY_INTERVAL_MILLISECONDS = 15000;

if (!GAME || !PORT) {
  console.error("GAMEDIG_GAME and QUERY_PORT env vars are required");
  process.exit(1);
}

const query = new GameServerQuery();

const server = http.createServer((req, res) => {
  if (req.url === "/metrics") {
    res.writeHead(200, { "Content-Type": "text/plain; version=0.0.4" });
    res.end(metricsText(query.lastStatus));
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

query.refresh();
setInterval(() => query.refresh(), QUERY_INTERVAL_MILLISECONDS);
server.listen(METRICS_PORT, () => {
  console.log(`game-status-metrics listening on :${METRICS_PORT}, querying ${GAME} at ${HOST}:${PORT}`);
});
