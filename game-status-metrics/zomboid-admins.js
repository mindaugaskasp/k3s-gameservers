"use strict";

const { DatabaseSync } = require("node:sqlite");
const { ZOMBOID_ACCOUNTS_DATABASE_FILE } = require("./config");

// The roles that can change the game for others; "observer" can only look.
const GAME_MASTER_ROLES = ["admin", "moderator", "gm"];

function readGameMasterUsernames() {
  if (!ZOMBOID_ACCOUNTS_DATABASE_FILE) return new Set();
  let database;
  try {
    database = new DatabaseSync(ZOMBOID_ACCOUNTS_DATABASE_FILE, { readOnly: true });
    const rows = database
      .prepare(
        `SELECT whitelist.username FROM whitelist JOIN role ON role.id = whitelist.role
          WHERE role.name IN (${GAME_MASTER_ROLES.map(() => "?").join(", ")})`
      )
      .all(...GAME_MASTER_ROLES);

    return new Set(rows.map((row) => row.username));
  } catch {
    return new Set();
  } finally {
    database?.close();
  }
}

function filterZomboidAdminNames(onlinePlayerNames) {
  const gameMasterUsernames = readGameMasterUsernames();

  return onlinePlayerNames.filter((name) => gameMasterUsernames.has(name));
}

module.exports = { filterZomboidAdminNames };
