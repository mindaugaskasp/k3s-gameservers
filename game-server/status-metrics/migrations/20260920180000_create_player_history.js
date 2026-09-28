"use strict";

/** The player history the exporter and the game's log hooks share. */
function up(database) {
  database.exec(`
    CREATE TABLE IF NOT EXISTS player (
      name TEXT PRIMARY KEY,
      play_time_seconds INTEGER NOT NULL DEFAULT 0,
      death_count INTEGER NOT NULL DEFAULT 0,
      last_seen_at INTEGER
    );
    CREATE TABLE IF NOT EXISTS exporter_state (key TEXT PRIMARY KEY, value INTEGER NOT NULL);
  `);
}

module.exports = { up };
