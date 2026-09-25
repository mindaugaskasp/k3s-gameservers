"use strict";

const fs = require("fs");
const { ONLINE_PLAYERS_DIR } = require("./config");

function readOnlinePlayers() {
  try {
    return fs.readdirSync(ONLINE_PLAYERS_DIR).sort();
  } catch {
    return [];
  }
}

// The file is written when the player joins and never rewritten while they are on,
// so its modification time is when the session started.
function readOnlinePlayerSessions() {
  return readOnlinePlayers().flatMap((name) => {
    try {
      return [{ name, startedAt: Math.floor(fs.statSync(`${ONLINE_PLAYERS_DIR}/${name}`).mtimeMs / 1000) }];
    } catch {
      return [];
    }
  });
}

// Named like the Valheim log hook names them: one file per player, "/" dropped so a
// name stays one file. An existing file is left alone, keeping its session start.
function convertPlayerNameToFilePath(name) {
  return `${ONLINE_PLAYERS_DIR}/${name.replaceAll("/", "")}`;
}

function markPlayerOnline(name) {
  const filePath = convertPlayerNameToFilePath(name);
  try {
    fs.mkdirSync(ONLINE_PLAYERS_DIR, { recursive: true });
    fs.writeFileSync(filePath, "", { flag: "wx" });
  } catch {
    // Already online, or no status dir to write in.
  }
}

function markPlayerOffline(name) {
  try {
    fs.unlinkSync(convertPlayerNameToFilePath(name));
  } catch {
    // Was not listed as online.
  }
}

// The server says nobody is on, so any name still listed missed its disconnect line.
function clearOnlinePlayers() {
  for (const name of readOnlinePlayers()) {
    try {
      fs.unlinkSync(`${ONLINE_PLAYERS_DIR}/${name}`);
    } catch {
      continue;
    }
  }
}

module.exports = { readOnlinePlayers, readOnlinePlayerSessions, markPlayerOnline, markPlayerOffline, clearOnlinePlayers };
