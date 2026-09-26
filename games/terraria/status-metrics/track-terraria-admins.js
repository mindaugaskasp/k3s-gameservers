"use strict";

// The groups TShock creates for admins, from newadmin up to superadmin.
const ADMIN_GROUPS = new Set(["newadmin", "admin", "trustedadmin", "owner", "superadmin"]);

// Each query answer names every online player's group, so the latest one is kept in memory.
let onlineAdminNames = new Set();

/** From TShock's /v2/server/status players list, which gamedig keeps as the raw answer. */
function recordOnlineAdmins(statusAnswer) {
  const players = statusAnswer.raw?.players ?? [];
  onlineAdminNames = new Set(players.filter((player) => ADMIN_GROUPS.has(player.group)).map((player) => player.nickname));
}

function filterTerrariaAdminNames(onlinePlayerNames) {
  return onlinePlayerNames.filter((name) => onlineAdminNames.has(name));
}

module.exports = { recordOnlineAdmins, filterTerrariaAdminNames };
