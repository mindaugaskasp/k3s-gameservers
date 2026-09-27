"use strict";

const { DRAGONWILDS_LOG_FILE } = require("./config");
const { readNewLines } = require("../../../game-server/status-metrics/read-new-log-lines");

// Seen in a real log (1.0.0.5), except the join and leave lines: those are from strings in the
// server binary, as no player has joined yet.
const LINE_EVENTS = [
  [/\["ReadyToJoin"\] written with key\[\w+\] value\[(\d)\]/, (match) => ({ type: "readyToJoin", isReady: match[1] === "1" })],
  [/LogCore: FUnixPlatformMisc::RequestExit/, () => ({ type: "readyToJoin", isReady: false })],
  [/ configured world \[(.+?)\]/, (match) => ({ type: "worldName", name: match[1] })],
  [/Maximum allowed player number by this build is (\d+)/, (match) => ({ type: "maxPlayers", count: Number(match[1]) })],
  [/Set ProjectVersion to (\d+(?:\.\d+)*)/, (match) => ({ type: "version", version: match[1] })],
  // Only whether one is set is kept; the log prints the password itself.
  [/Session privacy set to .* Password\[(.*?)\]/, (match) => ({ type: "passwordRequired", isRequired: match[1] !== "" })],
  [/Difficulty = ESurvivalDifficulty::(\w+)/, (match) => ({ type: "worldSetting", name: "Difficulty", value: match[1] })],
  [/hardcore state to EWorldHardcoreState::(\w+)/, (match) => ({ type: "worldSetting", name: "Hardcore", value: match[1] })],
  [/LogNet: Join succeeded: (.+?)\s*$/, (match) => ({ type: "joined", name: match[1] })],
  [/HandlePlayerLogout (.+?)\s*$/, (match) => ({ type: "left", name: match[1] })],
  [/Requested pausing as we have no player connected/, () => ({ type: "allLeft" })],
];

function convertLineToEvent(line) {
  for (const [pattern, createEvent] of LINE_EVENTS) {
    const match = pattern.exec(line);
    if (match) return createEvent(match);
  }
  return null;
}

/** What Dragonwilds logged since the last call, in log order; empty without DRAGONWILDS_LOG_FILE. */
function readNewDragonwildsEvents() {
  if (!DRAGONWILDS_LOG_FILE) return [];

  return readNewLines(DRAGONWILDS_LOG_FILE).map(convertLineToEvent).filter(Boolean);
}

module.exports = { readNewDragonwildsEvents };
