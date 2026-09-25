"use strict";

const { DatabaseSync } = require("node:sqlite");
const { ZOMBOID_PLAYERS_DATABASE_FILE } = require("./config");

// The game rewrites this row only when it saves, so right after a death it still names
// the character who died; the next character replaces it at a later save.
function readCharacterName(username) {
  if (!ZOMBOID_PLAYERS_DATABASE_FILE) return null;
  let database;
  try {
    database = new DatabaseSync(ZOMBOID_PLAYERS_DATABASE_FILE, { readOnly: true });
    database.exec("PRAGMA busy_timeout = 2000;");

    return database.prepare("SELECT name FROM networkPlayers WHERE username = ? ORDER BY id DESC LIMIT 1").get(username)?.name ?? null;
  } catch {
    return null;
  } finally {
    database?.close();
  }
}

module.exports = { readCharacterName };
