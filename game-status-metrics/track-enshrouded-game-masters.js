"use strict";

const fs = require("fs");
const { GAME_MASTERS_DIR } = require("./config");

// One empty file per online game master, named like the online-player files.
function convertPlayerNameToFilePath(name) {
  return `${GAME_MASTERS_DIR}/${name.replaceAll("/", "")}`;
}

function markGameMaster(name) {
  try {
    fs.mkdirSync(GAME_MASTERS_DIR, { recursive: true });
    fs.writeFileSync(convertPlayerNameToFilePath(name), "");
  } catch {
    // No status dir to write in.
  }
}

function unmarkGameMaster(name) {
  try {
    fs.unlinkSync(convertPlayerNameToFilePath(name));
  } catch {
    // Was not a game master.
  }
}

function filterEnshroudedAdminNames(onlinePlayerNames) {
  return onlinePlayerNames.filter((name) => fs.existsSync(convertPlayerNameToFilePath(name)));
}

module.exports = { markGameMaster, unmarkGameMaster, filterEnshroudedAdminNames };
