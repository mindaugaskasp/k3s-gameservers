"use strict";

const { ENSHROUDED_LOG_FILE } = require("./config");
const { readNewLines } = require("./log-follower");

// Formats from strings in the server binary (enshrouded_server.exe, build 23178631). The
// load/save lines were seen in a real log; the join and leave lines not yet.
const PLAYER_JOINED = /\] \[server\] (?:Machine '\d+': )?Player '(.+)' logged in/;
const PLAYER_LEFT = /\] \[server\] Remove Player '(.+)'\s*$/;
const ALL_PLAYERS_LEFT = /\] \[online\] Removing all peers/;
const WORLD_BASE_COUNT = /\] \[savexxx\] (?:LOAD|SAVE) ([\d,]+) bases /;
// A login is followed by one "\t - <permission>" line each; only the Admins role can kick and ban.
const PERMISSIONS_FOLLOW = /\] \[server\] Player '(.+)' logged in with Permissions:/;
const PERMISSION = /^\s+- (\w+)\s*$/;
const GAME_MASTER_PERMISSION = /^cankickban$/i;

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

function convertPermissionLineToEvent(line, playerName) {
  const permission = PERMISSION.exec(line);
  if (!permission) return null;

  return GAME_MASTER_PERMISSION.test(permission[1]) ? { type: "gameMaster", name: playerName } : { type: "permission" };
}

/** What Enshrouded logged since the last call, in log order; empty for every other game. */
function readNewEnshroudedEvents() {
  if (!ENSHROUDED_LOG_FILE) return [];

  const events = [];
  let playerListingPermissions = null;
  for (const line of readNewLines(ENSHROUDED_LOG_FILE)) {
    const permissionEvent = playerListingPermissions && convertPermissionLineToEvent(line, playerListingPermissions);
    if (permissionEvent) {
      if (permissionEvent.type === "gameMaster") events.push(permissionEvent);
      continue;
    }
    const event = convertLineToEvent(line);
    if (event) events.push(event);
    playerListingPermissions = PERMISSIONS_FOLLOW.exec(line)?.[1] ?? null;
    if (playerListingPermissions) events.push({ type: "permissionsListed", name: playerListingPermissions });
  }

  return events;
}

module.exports = { readNewEnshroudedEvents };
