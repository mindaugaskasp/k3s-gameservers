"use strict";

/** Zomboid players name a new character after each death; Valheim's names are already the character's. */
function up(database) {
  database.exec("ALTER TABLE player ADD COLUMN last_death_character_name TEXT;");
}

module.exports = { up };
