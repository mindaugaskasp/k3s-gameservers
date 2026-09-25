"use strict";

const { readRows, runStatementForEachRow } = require("./sqlite-database");

function recordRaids(raids) {
  runStatementForEachRow(
    "INSERT INTO raid (name, started_at) VALUES (?, ?)",
    raids.map((raid) => [raid.name, raid.startedAt])
  );
}

function readRaidCount() {
  return readRows("SELECT COUNT(*) AS count FROM raid")[0]?.count ?? null;
}

function readLatestRaid() {
  return readRows("SELECT name, started_at AS startedAt FROM raid ORDER BY started_at DESC, id DESC LIMIT 1")[0] ?? null;
}

module.exports = { recordRaids, readRaidCount, readLatestRaid };
