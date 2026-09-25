"use strict";

const { readRows, writeRows } = require("./open-sqlite-database");

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

module.exports = { recordRaids, readRaidCount, readLatestRaid };
