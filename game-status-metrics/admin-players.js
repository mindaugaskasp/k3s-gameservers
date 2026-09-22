"use strict";

const fs = require("fs");
const { ADMIN_LIST_FILE, ONLINE_PLAYERS_DIR } = require("./config");
const { readOnlinePlayers } = require("./online-players");

// Valheim writes crossplay IDs as "Steam_<id>" in some places and bare in others.
function convertToBareSteamId(platformId) {
  return platformId.trim().replace(/^Steam_/, "");
}

function readAdminSteamIds() {
  if (!ADMIN_LIST_FILE) return new Set();
  try {
    return new Set(
      fs.readFileSync(ADMIN_LIST_FILE, "utf8")
        .split("\n")
        .map((line) => line.trim())
        .filter((line) => line && !line.startsWith("//"))
        .map(convertToBareSteamId)
    );
  } catch {
    return new Set();
  }
}

// Each online player's file holds the platform ID from their handshake (player-event.sh).
function readOnlineAdminNames() {
  const adminSteamIds = readAdminSteamIds();
  if (adminSteamIds.size === 0) return [];

  return readOnlinePlayers().filter((name) => {
    try {
      return adminSteamIds.has(convertToBareSteamId(fs.readFileSync(`${ONLINE_PLAYERS_DIR}/${name}`, "utf8")));
    } catch {
      return false;
    }
  });
}

module.exports = { readOnlineAdminNames };
