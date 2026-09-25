"use strict";

/** One row per raid the server log announced. */
function up(database) {
  database.exec(`
    CREATE TABLE IF NOT EXISTS raid (
      id INTEGER PRIMARY KEY,
      name TEXT NOT NULL,
      started_at INTEGER NOT NULL
    );
  `);
}

module.exports = { up };
