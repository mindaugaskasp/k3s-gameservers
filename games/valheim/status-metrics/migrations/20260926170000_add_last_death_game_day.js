"use strict";

/** The in-game day of each player's last death; null for games without a world clock. */
function up(database) {
  database.exec("ALTER TABLE player ADD COLUMN last_death_game_day INTEGER;");
}

module.exports = { up };
