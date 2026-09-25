"use strict";

const fs = require("fs");
const { ZOMBOID_LOG_DIR } = require("./config");
const { readNewLines } = require("./read-new-log-lines");

// Line formats from the game's code: IsoGameCharacter.DoDeath writes the user line,
// and PVPLogTool.logKill writes the pvp line instead when another player did the killing.
const NON_PVP_DEATH = /\] user (.+) died at \(/;
const PVP_DEATH = /\] Kill: ".*?".* killed "([^"]+)"/;

function isDeathLogFile(fileName) {
  return fileName.endsWith("_user.txt") || fileName.endsWith("_pvp.txt");
}

function findDeadPlayerName(line) {
  const match = NON_PVP_DEATH.exec(line) ?? PVP_DEATH.exec(line);
  return match ? match[1] : null;
}

/** One name per death Zomboid logged since the last call; empty for every other game. */
function readNewZomboidDeaths() {
  if (!ZOMBOID_LOG_DIR) return [];

  let fileNames = [];
  try {
    fileNames = fs.readdirSync(ZOMBOID_LOG_DIR);
  } catch {
    return [];
  }

  return fileNames
    .filter(isDeathLogFile)
    .flatMap((fileName) => readNewLines(`${ZOMBOID_LOG_DIR}/${fileName}`))
    .map(findDeadPlayerName)
    .filter(Boolean);
}

module.exports = { readNewZomboidDeaths };
