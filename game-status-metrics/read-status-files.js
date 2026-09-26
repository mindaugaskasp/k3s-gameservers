"use strict";

const fs = require("fs");
const { STATUS_DIR, PERSIST_DIR } = require("./config");

// Written by the gameserver's lifecycle hooks; gamedig has no notion of
// "when did the process last (re)start".
function readStatusTimestamp(name) {
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
function readPastSessionsUptimeSeconds() {
  try {
    return parseInt(fs.readFileSync(`${PERSIST_DIR}/uptime-accumulator.seconds`, "utf8").trim(), 10) || 0;
  } catch {
    return 0;
  }
}

module.exports = {
  readStatusTimestamp,
  readBuildId,
  readPastSessionsUptimeSeconds,
};
