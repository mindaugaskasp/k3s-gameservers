"use strict";

const { GAME } = require("./config");
const { filterValheimAdminNames } = require("./valheim-admins");
const { filterZomboidAdminNames } = require("./zomboid-admins");
const { filterEnshroudedAdminNames } = require("./enshrouded-admins");

// Each game keeps its game masters its own way: Valheim by Steam ID, Zomboid by account
// role, Enshrouded by the permissions it logs at login.
const ADMIN_NAME_FILTERS = {
  valheim: filterValheimAdminNames,
  projectzomboid: filterZomboidAdminNames,
  enshrouded: filterEnshroudedAdminNames,
};

/** The online players who are game masters on this server. */
function readOnlineAdminNames(onlinePlayerNames) {
  const filterAdminNames = ADMIN_NAME_FILTERS[GAME];

  return filterAdminNames ? filterAdminNames(onlinePlayerNames) : [];
}

module.exports = { readOnlineAdminNames };
