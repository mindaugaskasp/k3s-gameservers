"use strict";

// Zomboid reports a character's kills so far, which restart at 0 when it dies, so the
// lifetime total needs the last reported count to tell a rise from a new character.
function up(database) {
  database.exec(`
    ALTER TABLE player ADD COLUMN zombie_kill_count INTEGER NOT NULL DEFAULT 0;
    ALTER TABLE player ADD COLUMN current_character_zombie_kills INTEGER NOT NULL DEFAULT 0;
  `);
}

module.exports = { up };
