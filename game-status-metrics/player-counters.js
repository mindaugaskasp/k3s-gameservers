"use strict";

const fs = require("fs");
const { PLAY_TIME_DIR, PLAY_TIME_CLOCK_FILE, DEATHS_DIR } = require("./config");

// A gap longer than this means the exporter was not watching, and nobody knows who
// stayed online across it, so it is credited to no one.
const MAX_CREDITED_GAP_SECONDS = 60;
/** Enough names for a leaderboard; the files themselves are all kept. */
const RANKED_PLAYER_LIMIT = 10;

function readNumberFile(path) {
  try {
    return parseInt(fs.readFileSync(path, "utf8").trim(), 10) || 0;
  } catch {
    return 0;
  }
}

/** Seconds since the last credit, and stamps this one, so every scrape is counted once. */
function secondsSinceLastCredit(now) {
  const lastCreditedAt = readNumberFile(PLAY_TIME_CLOCK_FILE);
  fs.writeFileSync(PLAY_TIME_CLOCK_FILE, String(now));
  const elapsed = now - lastCreditedAt;

  return lastCreditedAt > 0 && elapsed > 0 && elapsed <= MAX_CREDITED_GAP_SECONDS ? elapsed : 0;
}

/**
 * Adds the time since the previous scrape to every player online now. Counting up as
 * they play rather than on disconnect means a missed disconnect line costs nothing.
 */
function creditPlayTime(names) {
  const now = Math.floor(Date.now() / 1000);
  try {
    fs.mkdirSync(PLAY_TIME_DIR, { recursive: true });
    const seconds = secondsSinceLastCredit(now);
    if (!seconds) return;
    for (const name of names) {
      const path = `${PLAY_TIME_DIR}/${encodeURIComponent(name)}`;
      fs.writeFileSync(path, String(readNumberFile(path) + seconds));
    }
  } catch {
    // Read-only or missing PVC: play time is a nicety, never worth failing a scrape over.
  }
}

/** Highest first, capped so one scrape can't publish an unbounded list. */
function rankHighestFirst(players, field) {
  const ranked = players.filter((player) => player[field] > 0);
  ranked.sort((first, second) => second[field] - first[field] || first.name.localeCompare(second.name));

  return ranked.slice(0, RANKED_PLAYER_LIMIT);
}

/** Longest played first. */
function readPlayTimeTotals() {
  let files = [];
  try {
    files = fs.readdirSync(PLAY_TIME_DIR);
  } catch {
    return [];
  }

  return rankHighestFirst(
    files.map((file) => ({ name: decodeURIComponent(file), seconds: readNumberFile(`${PLAY_TIME_DIR}/${file}`) })),
    "seconds"
  );
}

/** Deaths per player, counted by the game's log hook. Names are its own filenames, unencoded. */
function readDeathCounts() {
  let files = [];
  try {
    files = fs.readdirSync(DEATHS_DIR);
  } catch {
    return [];
  }

  return rankHighestFirst(files.map((name) => ({ name, count: readNumberFile(`${DEATHS_DIR}/${name}`) })), "count");
}

module.exports = { creditPlayTime, readPlayTimeTotals, readDeathCounts };
