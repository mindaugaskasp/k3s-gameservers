"use strict";

const fs = require("fs");
const { ONLINE_PLAYERS_DIR, SEEN_PLAYERS_DIR } = require("./config");

const SEEN_PLAYER_LIMIT = 50;

function readOnlinePlayers() {
  try {
    return fs.readdirSync(ONLINE_PLAYERS_DIR).sort();
  } catch {
    return [];
  }
}

// The server says nobody is on, so any name still listed missed its disconnect line.
function clearOnlinePlayers() {
  for (const name of readOnlinePlayers()) {
    try {
      fs.unlinkSync(`${ONLINE_PLAYERS_DIR}/${name}`);
    } catch {
      continue;
    }
  }
}

// Stamped every scrape rather than on disconnect: a missed disconnect line then costs
// nothing. Names are free text, so they are percent-encoded to stay valid single filenames.
function recordPlayersSeen(names) {
  if (!names.length) return;
  const now = Math.floor(Date.now() / 1000);
  try {
    fs.mkdirSync(SEEN_PLAYERS_DIR, { recursive: true });
    for (const name of names) {
      fs.writeFileSync(`${SEEN_PLAYERS_DIR}/${encodeURIComponent(name)}`, String(now));
    }
  } catch {
    // Read-only or missing PVC: last-seen is a nicety, never worth failing a scrape over.
  }
}

/** Most recently seen first, capped so a busy server can't grow the directory forever. */
function readPlayersSeen() {
  let files = [];
  try {
    files = fs.readdirSync(SEEN_PLAYERS_DIR);
  } catch {
    return [];
  }

  const seen = [];
  for (const file of files) {
    try {
      const at = parseInt(fs.readFileSync(`${SEEN_PLAYERS_DIR}/${file}`, "utf8").trim(), 10);
      if (at > 0) seen.push({ name: decodeURIComponent(file), at, file });
    } catch {
      continue;
    }
  }
  seen.sort((first, second) => second.at - first.at);

  for (const stale of seen.slice(SEEN_PLAYER_LIMIT)) {
    try {
      fs.unlinkSync(`${SEEN_PLAYERS_DIR}/${stale.file}`);
    } catch {
      continue;
    }
  }

  return seen.slice(0, SEEN_PLAYER_LIMIT);
}

module.exports = { readOnlinePlayers, clearOnlinePlayers, recordPlayersSeen, readPlayersSeen };
