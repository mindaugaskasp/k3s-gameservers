"use strict";

const { readRows, writeRows } = require("../../../game-server/status-metrics/open-sqlite-database");
const { RANKED_PLAYER_LIMIT } = require("../../../game-server/status-metrics/store-player-history");

// A rise in a character's count adds the difference; a drop means the character died
// and a new one started from 0, so its whole count is new.
function recordZombieKills(players) {
  writeRows(
    `INSERT INTO player (name, zombie_kill_count, current_character_zombie_kills) VALUES (?, ?, ?)
       ON CONFLICT(name) DO UPDATE SET
         zombie_kill_count = zombie_kill_count + CASE
           WHEN excluded.current_character_zombie_kills >= current_character_zombie_kills
             THEN excluded.current_character_zombie_kills - current_character_zombie_kills
           ELSE excluded.current_character_zombie_kills
         END,
         current_character_zombie_kills = excluded.current_character_zombie_kills`,
    players.map((player) => [player.name, player.zombieKills, player.zombieKills])
  );
}

/** Run after recordDeaths, which creates the player's row. */
function recordDeathCharacterNames(deaths) {
  writeRows(
    "UPDATE player SET last_death_character_name = ? WHERE name = ?",
    deaths.map((death) => [death.characterName, death.playerName])
  );
}

/** Most zombies killed first, across every character a player has had. */
function readZombieKillCounts() {
  return readRows(
    "SELECT name, zombie_kill_count AS count FROM player WHERE zombie_kill_count > 0 ORDER BY count DESC, name LIMIT ?",
    RANKED_PLAYER_LIMIT
  );
}

module.exports = { recordZombieKills, recordDeathCharacterNames, readZombieKillCounts };
