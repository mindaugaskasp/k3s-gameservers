"use strict";

const fs = require("fs");
const { STATUS_DIR } = require("../../../game-status-metrics/config");

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

// Touched by player-event.sh / backup-gate.sh on any player activity.
// 0 = no activity since the pod started.
function readLastPlayerActivityTimestamp() {
  try {
    return Math.floor(fs.statSync(`${STATUS_DIR}/players/last-activity`).mtimeMs / 1000);
  } catch {
    return 0;
  }
}

module.exports = { readModState, readLastPlayerActivityTimestamp };
