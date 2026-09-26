"use strict";

const { readRows, writeRows } = require("../../../game-status-metrics/open-sqlite-database");

function recordRaids(raids) {
  writeRows(
    "INSERT INTO raid (name, started_at) VALUES (?, ?)",
    raids.map((raid) => [raid.eventId, raid.startedAt])
  );
}

function readRaidCount() {
  return readRows("SELECT COUNT(*) AS count FROM raid")[0]?.count ?? null;
}

function readLatestRaid() {
  return readRows("SELECT name AS eventId, started_at AS startedAt FROM raid ORDER BY started_at DESC, id DESC LIMIT 1")[0] ?? null;
}

function readRecentRaids(limit) {
  return readRows(
    "SELECT id, name AS eventId, started_at AS startedAt FROM raid ORDER BY started_at DESC, id DESC LIMIT ?",
    limit
  );
}

module.exports = { recordRaids, readRaidCount, readLatestRaid, readRecentRaids };
