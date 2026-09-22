"use strict";

const { ENSHROUDED_LOG_FILE } = require("./config");
const { readNewLines } = require("./log-follower");

// Formats from strings in the server binary (enshrouded_server.exe, build 23178631). The
// load/save lines were seen in a real log; the join and leave lines not yet.
const PLAYER_JOINED = /\] \[server\] (?:Machine '\d+': )?Player '(.+)' logged in/;
const PLAYER_LEFT = /\] \[server\] Remove Player '(.+)'\s*$/;
const ALL_PLAYERS_LEFT = /\] \[online\] Removing all peers/;
const WORLD_BASE_COUNT = /\] \[savexxx\] (?:LOAD|SAVE) ([\d,]+) bases /;

function convertLineToEvent(line) {
  const joined = PLAYER_JOINED.exec(line);
  if (joined) return { type: "joined", name: joined[1] };
  const left = PLAYER_LEFT.exec(line);
  if (left) return { type: "left", name: left[1] };
  if (ALL_PLAYERS_LEFT.test(line)) return { type: "allLeft" };
  const bases = WORLD_BASE_COUNT.exec(line);
  if (bases) return { type: "baseCount", count: Number(bases[1].replaceAll(",", "")) };
  return null;
}

/** What Enshrouded logged since the last call, in log order; empty for every other game. */
function readNewEnshroudedEvents() {
  if (!ENSHROUDED_LOG_FILE) return [];
  return readNewLines(ENSHROUDED_LOG_FILE).map(convertLineToEvent).filter(Boolean);
}

module.exports = { readNewEnshroudedEvents };
