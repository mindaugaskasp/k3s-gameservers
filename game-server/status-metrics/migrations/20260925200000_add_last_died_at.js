"use strict";

function up(database) {
  database.exec("ALTER TABLE player ADD COLUMN last_died_at INTEGER;");
}

module.exports = { up };
