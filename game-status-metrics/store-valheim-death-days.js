"use strict";

const { writeRows } = require("./open-sqlite-database");

/** Run after recordDeaths, which creates the player's row. */
function recordDeathGameDay(playerNames, gameDay) {
  writeRows(
    "UPDATE player SET last_death_game_day = ? WHERE name = ?",
    playerNames.map((name) => [gameDay, name])
  );
}

module.exports = { recordDeathGameDay };
