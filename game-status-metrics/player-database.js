"use strict";

const { PLAYERS_DATABASE_FILE } = require("./config");
const { openDatabase, readRows, runStatementForEachRow, reportDatabaseFailure } = require("./sqlite-database");

const RANKED_PLAYER_LIMIT = 10;
const SEEN_PLAYER_LIMIT = 50;
// A gap longer than this means the exporter was not watching, and nobody knows who
// stayed online across it, so it is credited to no one.
const MAX_CREDITED_GAP_SECONDS = 60;

const nowInSeconds = () => Math.floor(Date.now() / 1000);

/** Stamped every scrape rather than on disconnect: a missed disconnect line then costs nothing. */
function recordPlayersSeen(names) {
  const seenAt = nowInSeconds();
  runStatementForEachRow(
    `INSERT INTO player (name, last_seen_at) VALUES (?, ?)
       ON CONFLICT(name) DO UPDATE SET last_seen_at = excluded.last_seen_at`,
    names.map((name) => [name, seenAt])
  );
}

/** Stamping each credit means every scrape is counted exactly once. */
function recordCreditAndGetElapsedSeconds(openedDatabase) {
  const key = "play_time_credited_at";
  const now = nowInSeconds();
  const lastCreditedAt = openedDatabase.prepare("SELECT value FROM exporter_state WHERE key = ?").get(key)?.value ?? 0;
  openedDatabase
    .prepare("INSERT INTO exporter_state (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value")
    .run(key, now);
  const elapsed = now - lastCreditedAt;

  return lastCreditedAt > 0 && elapsed > 0 && elapsed <= MAX_CREDITED_GAP_SECONDS ? elapsed : 0;
}

/** Counting up while they play rather than on disconnect means a missed disconnect line costs nothing. */
function creditPlayTime(names) {
  const openedDatabase = openDatabase();
  if (!openedDatabase) return;
  let seconds = 0;
  try {
    seconds = recordCreditAndGetElapsedSeconds(openedDatabase);
  } catch (error) {
    reportDatabaseFailure("not writable", error);
    return;
  }
  if (!seconds) return;

  runStatementForEachRow(
    `INSERT INTO player (name, play_time_seconds) VALUES (?, ?)
       ON CONFLICT(name) DO UPDATE SET play_time_seconds = play_time_seconds + excluded.play_time_seconds`,
    names.map((name) => [name, seconds])
  );
}

/** A player listed twice died twice. Stamped when read, within one query interval of the death. */
function recordDeaths(deaths) {
  const diedAt = nowInSeconds();
  runStatementForEachRow(
    `INSERT INTO player (name, death_count, last_died_at, last_death_character_name) VALUES (?, 1, ?, ?)
       ON CONFLICT(name) DO UPDATE SET death_count = death_count + 1, last_died_at = excluded.last_died_at,
         last_death_character_name = excluded.last_death_character_name`,
    deaths.map((death) => [death.playerName, diedAt, death.characterName])
  );
}

// A rise in a character's count adds the difference; a drop means the character died
// and a new one started from 0, so its whole count is new.
function recordZombieKills(players) {
  runStatementForEachRow(
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

// The count each character last reported is kept: zeroing it would re-credit every kill
// the current character already has on the next scrape. Throws, unlike the scrape path.
function resetPlayerStats() {
  const openedDatabase = openDatabase();
  if (!openedDatabase) throw new Error("player database unavailable");
  const takenAt = new Date().toISOString().replace(/[-:]/g, "");
  const backupFile = PLAYERS_DATABASE_FILE.replace(/\.db$/, `.before-reset-${takenAt}.db`);
  openedDatabase.prepare("VACUUM INTO ?").run(backupFile);
  const { changes } = openedDatabase
    .prepare("UPDATE player SET play_time_seconds = 0, death_count = 0, last_died_at = NULL, last_death_character_name = NULL, zombie_kill_count = 0")
    .run();

  return { resetPlayerCount: changes, backupFile };
}

/** Most recently seen first. */
function readPlayersSeen() {
  return readRows(
    "SELECT name, last_seen_at AS at FROM player WHERE last_seen_at IS NOT NULL ORDER BY last_seen_at DESC LIMIT ?",
    SEEN_PLAYER_LIMIT
  );
}

/** Longest played first. */
function readPlayTimeTotals() {
  return readRows(
    "SELECT name, play_time_seconds AS seconds FROM player WHERE play_time_seconds > 0 ORDER BY seconds DESC, name LIMIT ?",
    RANKED_PLAYER_LIMIT
  );
}

/** Most deaths first. */
function readDeathCounts() {
  return readRows(
    "SELECT name, death_count AS count FROM player WHERE death_count > 0 ORDER BY count DESC, name LIMIT ?",
    RANKED_PLAYER_LIMIT
  );
}

function readLastDeath() {
  return readRows(
    `SELECT name, last_died_at AS diedAt, last_death_character_name AS characterName
       FROM player WHERE last_died_at IS NOT NULL ORDER BY last_died_at DESC, name LIMIT 1`
  )[0] ?? null;
}

/** Most zombies killed first, across every character a player has had. */
function readZombieKillCounts() {
  return readRows(
    "SELECT name, zombie_kill_count AS count FROM player WHERE zombie_kill_count > 0 ORDER BY count DESC, name LIMIT ?",
    RANKED_PLAYER_LIMIT
  );
}

module.exports = {
  recordPlayersSeen,
  creditPlayTime,
  recordDeaths,
  recordZombieKills,
  resetPlayerStats,
  readPlayersSeen,
  readPlayTimeTotals,
  readDeathCounts,
  readLastDeath,
  readZombieKillCounts,
};
