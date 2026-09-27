"use strict";

const fs = require("fs");
const { DRAGONWILDS_LOG_FILE, DRAGONWILDS_SERVER_STATE_FILE } = require("./config");
const { readOnlinePlayers } = require("../../../game-server/status-metrics/track-online-players");

// The server logs an Epic Online Services heartbeat every 30 seconds while it is listed.
const LOG_SILENCE_LIMIT_MILLISECONDS = 90 * 1000;

const EMPTY_SERVER_STATE = { isReady: false, worldName: "", maxPlayers: 0, version: "", isPasswordRequired: false, worldSettings: {} };

let loadedServerState = null;

function getServerState() {
  if (loadedServerState) return loadedServerState;
  try {
    loadedServerState = { ...EMPTY_SERVER_STATE, ...JSON.parse(fs.readFileSync(DRAGONWILDS_SERVER_STATE_FILE, "utf8")) };
  } catch {
    loadedServerState = { ...EMPTY_SERVER_STATE };
  }
  return loadedServerState;
}

// Kept on disk because the log is read once: an exporter restart would otherwise forget it.
function saveServerState() {
  try {
    const temporaryFile = `${DRAGONWILDS_SERVER_STATE_FILE}.tmp`;
    fs.writeFileSync(temporaryFile, JSON.stringify(loadedServerState));
    fs.renameSync(temporaryFile, DRAGONWILDS_SERVER_STATE_FILE);
  } catch {
    // A read-only status dir only costs the state after an exporter restart.
  }
}

/** Folds the log's server events into the kept state; player events are left to the caller. */
function recordServerEvents(events) {
  const serverState = getServerState();
  for (const event of events) {
    if (event.type === "readyToJoin") serverState.isReady = event.isReady;
    if (event.type === "worldName") serverState.worldName = event.name;
    if (event.type === "maxPlayers") serverState.maxPlayers = event.count;
    if (event.type === "version") serverState.version = event.version;
    if (event.type === "passwordRequired") serverState.isPasswordRequired = event.isRequired;
    if (event.type === "worldSetting") serverState.worldSettings[event.name] = event.value;
  }
  if (events.length) saveServerState();
}

function isLogRecentlyWritten() {
  try {
    return Date.now() - fs.statSync(DRAGONWILDS_LOG_FILE).mtimeMs < LOG_SILENCE_LIMIT_MILLISECONDS;
  } catch {
    return false;
  }
}

/** The server as gamedig would report it: joinable and still logging, or it throws. */
async function readDragonwildsServerState() {
  const serverState = getServerState();
  if (!serverState.isReady || !isLogRecentlyWritten()) throw new Error("the Dragonwilds server is not joinable");

  return {
    name: serverState.worldName,
    maxplayers: serverState.maxPlayers,
    players: readOnlinePlayers().map((name) => ({ name })),
    password: serverState.isPasswordRequired,
    version: serverState.version,
  };
}

/** [{ name, value }] per world setting the log reported, e.g. Difficulty. */
function readDragonwildsWorldSettings() {
  return Object.entries(getServerState().worldSettings).map(([name, value]) => ({ name, value }));
}

module.exports = { recordServerEvents, readDragonwildsServerState, readDragonwildsWorldSettings };
